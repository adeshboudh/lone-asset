"""Builds, checks, previews and exports the first-person pistol rig (arms and pistol in one armature).

  blender -b --python tools/blender/pistol_rig.py -- build [--force]
  blender -b --python tools/blender/pistol_rig.py -- check
  blender -b --python tools/blender/pistol_rig.py -- preview OUT.png [--view eye|side|top] [--action NAME] [--frame N]
  blender -b --python tools/blender/pistol_rig.py -- export

build creates content/weapons/pistol/rig/pistol_rig.blend (the source of the animation keys) and refuses to
overwrite it without --force. export writes content/weapons/pistol/pistol_viewmodel.glb from the .blend.
Units are metres, the camera is the origin and looks along -Y. See docs/superpowers/specs/2026-11-17-pistol-arms-rig-design.md.
"""
import json
import math
import os
import struct
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import arms_rig  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
ARMS_GLB = os.path.join(ROOT, "content", "characters", "fps_arms", "fps_arms.glb")
PISTOL_FBX = os.path.join(ROOT, "content", "weapons", "pistol", "source", "9mmPistol.fbx")
BLEND = os.path.join(ROOT, "content", "weapons", "pistol", "rig", "pistol_rig.blend")
GLB = os.path.join(ROOT, "content", "weapons", "pistol", "pistol_viewmodel.glb")

# Shoulders end up 0.25 m below the camera and 0.02 m behind it (arms_rig.CM turns the file centimetres into metres).
ARMS_OFFSET = Vector((0.0, -0.303, -0.48))
# Where the elbow points, from the elbow at rest: outward (mirrored per side), back, down.
POLE_OFFSET = Vector((0.10, 0.25, -0.30))
MODEL_SCALE = 0.08  # the pistol model is 2.4 units long, a 9mm pistol is about 0.19 m
MODEL_YAW = math.pi / 2  # turns the model muzzle (-X) to point along -Y
GUN_REST = Vector((0.015, -0.40, -0.17))  # the grip centre, camera space

# Starting values for the two-handed grip; tuned against the reference image (see the plan, task 2).
GRIP_POSE = {
    "R": {"head": Vector((-0.030, -0.370, -0.200)), "turn": (0.0, 0.0, 0.0)},
    "L": {"head": Vector((0.045, -0.360, -0.220)), "turn": (0.0, 0.0, 0.0)},
}
GRIP_CURL = {"thumb": (10.0, 10.0, 10.0, 0.0), "point": (60.0, 70.0, 50.0, 0.0), "middle": (65.0, 75.0, 55.0, 0.0),
             "ring": (70.0, 80.0, 55.0, 0.0), "pink": (75.0, 85.0, 55.0, 0.0)}

GUN_BONES = ("gun_root", "gun_slide", "gun_mag", "gun_mag_spare", "gun_trigger", "gun_hammer", "gun_muzzle")
CONTROL_BONES = ("ctl_gun", "ctl_hand_L", "ctl_hand_R", "pole_elbow_L", "pole_elbow_R", "ctl_mag_hold")
# Vertices per gun bone in the 9mm Pistol model (the spare magazine is a copy of gun_mag); the check compares them.
EXPECTED_VERTS = {"gun_slide": 804, "gun_hammer": 104, "gun_trigger": 126, "gun_mag": 113}

FPS = 60
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def option(name: str, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


def save_blend() -> None:
    bpy.context.preferences.filepaths.save_version = 0  # no .blend1 backup next to the source file
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)


# ---------------------------------------------------------------- the pistol model

def islands(mesh):
    """Connected pieces of a mesh: a list of (vertex indices, lowest corner, highest corner) in local coordinates."""
    parent = list(range(len(mesh.vertices)))

    def find(i: int) -> int:
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for e in mesh.edges:
        a, b = find(e.vertices[0]), find(e.vertices[1])
        if a != b:
            parent[a] = b
    pieces = {}
    for v in mesh.vertices:
        pieces.setdefault(find(v.index), []).append(v.index)
    out = []
    for indices in pieces.values():
        cos = [mesh.vertices[i].co for i in indices]
        lo = Vector((min(c.x for c in cos), min(c.y for c in cos), min(c.z for c in cos)))
        hi = Vector((max(c.x for c in cos), max(c.y for c in cos), max(c.z for c in cos)))
        out.append((indices, lo, hi))
    return out


def frame_group(n: int, lo: Vector, hi: Vector) -> str:
    return "gun_mag" if n == 81 else "gun_root"  # the magazine body sits inside the frame mesh


def slide_group(n: int, lo: Vector, hi: Vector) -> str:
    if n == 32 and hi.z < -1.3:
        return "gun_mag"  # the magazine base plate
    if lo.x >= 0.58 and hi.z <= 0.06 and lo.z >= -0.17 and n <= 88:
        return "gun_hammer"
    if hi.x <= 0.0 and hi.z <= -0.24 and lo.z >= -0.62 and n <= 62:
        return "gun_trigger"
    if hi.x < -0.1 and n >= 150:
        return "gun_root"  # the barrel stays while the slide moves
    if hi.z >= 0.0:
        return "gun_slide"
    return "gun_root"


def import_pistol():
    """Imports the pistol, bakes it into rig space (scaled, turned, with its grip at GUN_REST) and returns
    (frame object, slide object, {vertex group: [(object, vertex index)]})."""
    before = set(bpy.data.objects)
    bpy.ops.wm.fbx_import(filepath=PISTOL_FBX)
    frame, slide = bpy.data.objects["Cube.005"], bpy.data.objects["Cube.001"]
    assert {frame, slide} == set(bpy.data.objects) - before, "unexpected objects in the pistol file"
    members = {}
    for obj, rule in ((frame, frame_group), (slide, slide_group)):
        for indices, lo, hi in islands(obj.data):
            for i in indices:
                members.setdefault(rule(len(indices), lo, hi), []).append((obj, i))
    worlds = {o: o.matrix_world.copy() for o in (frame, slide)}
    for o in (frame, slide):
        o.parent = None
        o.matrix_world = Matrix.Identity(4)
        o.data.transform(worlds[o])
    mag = [o.data.vertices[i].co for o, i in members["gun_mag"]]
    grip = sum(mag, Vector()) / len(mag)
    place = (Matrix.Translation(GUN_REST) @ Euler((0.0, 0.0, MODEL_YAW), "XYZ").to_matrix().to_4x4()
             @ Matrix.Scale(MODEL_SCALE, 4) @ Matrix.Translation(-grip))
    for o in (frame, slide):
        o.data.transform(place)
        o.data.update()
    frame.name, frame.data.name = "pistol_frame", "pistol_frame"
    slide.name, slide.data.name = "pistol_slide", "pistol_slide"
    for o, name, rgba in ((frame, "pistol_frame", (0.2, 0.2, 0.22, 1.0)), (slide, "pistol_slide", (0.3, 0.3, 0.33, 1.0))):
        o.data.materials.clear()
        o.data.materials.append(arms_rig.plain_material(name, rgba))
    for img in list(bpy.data.images):
        bpy.data.images.remove(img)
    for mat in list(bpy.data.materials):
        if mat.users == 0:
            bpy.data.materials.remove(mat)
    return frame, slide, members


def centre(members, group: str) -> Vector:
    pts = [o.data.vertices[i].co for o, i in members[group]]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return (lo + hi) * 0.5


def muzzle_point(frame, slide) -> Vector:
    pts = [v.co for o in (frame, slide) for v in o.data.vertices]
    y = min(p.y for p in pts)
    tip = [p for p in pts if p.y < y + 0.002]
    return sum(tip, Vector()) / len(tip)


def make_spare_mag(frame, slide, members):
    """A copy of the magazine pieces as their own object, skinned to gun_mag_spare."""
    out = bmesh.new()
    for slot, obj in enumerate((frame, slide)):
        wanted = {i for o, i in members["gun_mag"] if o is obj}
        src = bmesh.new()
        src.from_mesh(obj.data)
        src.verts.ensure_lookup_table()
        vmap = {i: out.verts.new(src.verts[i].co) for i in sorted(wanted)}
        for f in src.faces:
            if all(v.index in wanted for v in f.verts):
                face = out.faces.new([vmap[v.index] for v in f.verts])
                face.material_index = slot
        src.free()
    mesh = bpy.data.meshes.new("pistol_mag_spare")
    out.to_mesh(mesh)
    out.free()
    for mat in frame.data.materials[:1] + slide.data.materials[:1]:
        mesh.materials.append(mat)
    obj = bpy.data.objects.new("pistol_mag_spare", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# ---------------------------------------------------------------- the rig

def add_gun_bones(arm, frame, slide, members) -> None:
    arms_rig.enter_mode(arm, "EDIT")
    eb = arm.data.edit_bones

    def bone(name, head, parent=None, deform=True, length=0.03):
        b = eb.new(name)
        b.head, b.tail = head, head + Vector((0.0, -length, 0.0))
        b.align_roll(Vector((0.0, 0.0, 1.0)))
        b.use_deform = deform
        b.parent = parent
        return b

    bone("ctl_gun", GUN_REST, None, False, 0.06)
    root = bone("gun_root", GUN_REST, None, True, 0.05)
    bone("gun_slide", centre(members, "gun_slide"), root)
    bone("gun_mag", centre(members, "gun_mag"), root)
    bone("gun_mag_spare", centre(members, "gun_mag"), root)
    bone("gun_trigger", centre(members, "gun_trigger"), root)
    bone("gun_hammer", centre(members, "gun_hammer"), root)
    bone("gun_muzzle", muzzle_point(frame, slide), root, True, 0.01)
    wrist = eb["L_wrist_03"].head
    bone("ctl_mag_hold", wrist + Vector((0.0, -0.06, -0.02)), eb["ctl_hand_L"], False)
    arms_rig.object_mode()
    arms_rig.enter_mode(arm, "POSE")
    follow = arm.pose.bones["gun_root"].constraints.new("COPY_TRANSFORMS")
    follow.name = "Follow control"
    follow.target, follow.subtarget = arm, "ctl_gun"
    hold = arm.pose.bones["gun_mag_spare"].constraints.new("COPY_TRANSFORMS")
    hold.name = "Held in the left hand"
    hold.target, hold.subtarget = arm, "ctl_mag_hold"
    hold.influence = 0.0
    arms_rig.object_mode()


def skin_pistol(arm, objects, members) -> None:
    for obj in objects:
        obj.parent = arm
        obj.matrix_parent_inverse = arm.matrix_world.inverted()
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    for group, items in members.items():
        for obj in {o for o, _ in items}:
            vg = obj.vertex_groups.new(name=group)
            vg.add([i for o, i in items if o is obj], 1.0, "REPLACE")
    spare = objects[-1]
    spare.vertex_groups.new(name="gun_mag_spare").add(list(range(len(spare.data.vertices))), 1.0, "REPLACE")


def pose_grip(arm) -> None:
    for side in arms_rig.SIDES:
        arms_rig.place_bone(arm, f"ctl_hand_{side}", GRIP_POSE[side]["head"], GRIP_POSE[side]["turn"])
        arms_rig.set_finger_curl(arm, side, GRIP_CURL)
        print("pole angle", side, arms_rig.choose_pole_angle(arm, side))


def build() -> None:
    if os.path.exists(BLEND) and "--force" not in ARGS:
        sys.exit(f"{BLEND} exists; build refuses to overwrite keyed clips. Pass --force to rebuild.")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arm, arms_mesh = arms_rig.import_arms(ARMS_GLB)
    arms_rig.strip_textures(arms_mesh, "arms")
    arms_rig.bake_transform(arm, arms_mesh, Matrix.Translation(ARMS_OFFSET) @ Matrix.Scale(arms_rig.CM, 4))
    arms_rig.straighten_bones(arm)
    arms_rig.add_arm_controls(arm, POLE_OFFSET)
    frame, slide, members = import_pistol()
    spare = make_spare_mag(frame, slide, members)
    add_gun_bones(arm, frame, slide, members)
    skin_pistol(arm, (frame, slide, spare), members)
    for side in arms_rig.SIDES:
        arms_rig.add_follow_switch(arm, side, "gun_root")
    for name in ("ctl_gun", "gun_slide", "gun_mag", "gun_mag_spare", "gun_trigger", "gun_hammer"):
        arm.pose.bones[name].rotation_mode = "XYZ"
    bpy.context.scene.render.fps = FPS
    pose_grip(arm)
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    save_blend()
    print("BUILD OK", BLEND)


# ---------------------------------------------------------------- check, preview, export

def fail(message: str) -> None:
    print("CHECK FAILED:", message)
    sys.exit(1)


def check() -> None:
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    bpy.context.view_layer.update()
    arm = bpy.data.objects["PistolRig"]
    bones = arm.data.bones
    for name in GUN_BONES:
        if name not in bones or not bones[name].use_deform:
            fail(f"deform bone {name} missing")
    for name in CONTROL_BONES:
        if name not in bones or bones[name].use_deform:
            fail(f"control bone {name} missing or deforming")
    deform = [b.name for b in bones if b.use_deform]
    if len(deform) != 47 + len(GUN_BONES):
        fail(f"{len(deform)} deform bones, expected {47 + len(GUN_BONES)}")
    for side in arms_rig.SIDES:
        upper, forearm, wrist = arms_rig.CHAIN[side]
        ik = arm.pose.bones[forearm].constraints.get("IK")
        if ik is None or ik.subtarget != f"ctl_hand_{side}" or ik.chain_count != 2:
            fail(f"IK on {forearm}")
        if arm.pose.bones[wrist].constraints.get("Hand rotation") is None:
            fail(f"hand rotation on {wrist}")
        follow = arm.pose.bones[f"ctl_hand_{side}"].constraints.get("Follow gun")
        if follow is None or arm.animation_data is None or not arm.animation_data.drivers:
            fail(f"follow switch for {side}")
        if f"{side}_follows_gun" not in arm:
            fail(f"{side}_follows_gun property")
        reach = (arm.pose.bones[wrist].head - arm.pose.bones[upper].head).length
        if not 0.30 < reach < 0.52:
            fail(f"{side} arm reach {reach:.3f} m is outside what the two bones can span")
        hand = arm.matrix_world @ arm.pose.bones[wrist].head
        if (hand - GUN_REST).length > 0.12:
            fail(f"{side} wrist is {(hand - GUN_REST).length:.3f} m from the grip")
    arms_mesh = bpy.data.objects["arms"]
    if any(len(v.groups) == 0 for v in arms_mesh.data.vertices):
        fail("arms vertices without weights")
    for group, wanted in EXPECTED_VERTS.items():
        total = sum(1 for o in bpy.data.objects if o.type == "MESH" and group in o.vertex_groups
                    and o.name != "pistol_mag_spare"
                    for v in o.data.vertices if any(o.vertex_groups[g.group].name == group for g in v.groups))
        if total != wanted:
            fail(f"{group} has {total} vertices, expected {wanted}")
    spare = bpy.data.objects["pistol_mag_spare"]
    if len(spare.data.vertices) != EXPECTED_VERTS["gun_mag"]:
        fail("spare magazine is not a copy of gun_mag")
    if bpy.data.images:
        fail("images left in the file (textures are applied in Godot)")
    if any(o.type == "MESH" and o.dimensions.length > 2.0 for o in bpy.data.objects):
        fail("a mesh is larger than 2 m (units not converted)")
    print("CHECK OK")


def preview() -> None:
    out = os.path.abspath(ARGS[ARGS.index("preview") + 1])
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    scene = bpy.context.scene
    arm = bpy.data.objects["PistolRig"]
    action = option("--action")
    if action:
        arm.animation_data_create().action = bpy.data.actions[action]
    scene.frame_set(int(option("--frame", scene.frame_current)))
    view = option("--view", "eye")
    cam = bpy.data.objects.new("preview_cam", bpy.data.cameras.new("preview_cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.sensor_fit = "VERTICAL"
    if view == "eye":
        cam.location, cam.rotation_euler = (0.0, 0.0, 0.0), (math.pi / 2, 0.0, math.pi)
        cam.data.angle = math.radians(75.0)
    elif view == "side":
        cam.location, cam.rotation_euler = (1.0, -0.35, -0.12), (math.pi / 2, 0.0, math.pi / 2)
        cam.data.angle = math.radians(35.0)
    else:
        cam.location, cam.rotation_euler = (0.0, -0.35, 0.9), (0.0, 0.0, math.pi)
        cam.data.angle = math.radians(35.0)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "OBJECT"
    for name, colour in (("arms", (0.16, 0.20, 0.17, 1)), ("pistol_frame", (0.55, 0.55, 0.6, 1)),
                         ("pistol_slide", (0.75, 0.75, 0.8, 1)), ("pistol_mag_spare", (0.9, 0.5, 0.2, 1))):
        bpy.data.objects[name].color = colour
    world = bpy.data.worlds.new("preview")
    world.color = (0.12, 0.12, 0.13)
    scene.world = world
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("PREVIEW OK", out)


def export() -> None:
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    arm = bpy.data.objects["PistolRig"]
    for act in bpy.data.actions:
        act.use_fake_user = True
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    kwargs = {"filepath": GLB, "export_format": "GLB", "export_yup": True, "export_def_bones": True,
              "export_image_format": "NONE", "export_apply": False, "use_selection": False}
    for name in ("export_force_sampling", "export_bake_animation"):
        if name in props:
            kwargs[name] = True
    missing = [k for k in kwargs if k not in props]
    if missing:
        sys.exit(f"this Blender has no glTF export option(s): {missing}")
    bpy.ops.export_scene.gltf(**kwargs)
    print("EXPORT OK", GLB)
    verify_glb()


def verify_glb() -> None:
    """Reads the exported GLB back: only deform bones, no control bones, no images, every clip present."""
    with open(GLB, "rb") as f:
        data = f.read()
    gltf = json.loads(data[20:20 + struct.unpack("<I", data[12:16])[0]])
    names = [gltf["nodes"][i]["name"] for i in gltf["skins"][0]["joints"]]
    if any(n.startswith(("ctl_", "pole_")) for n in names):
        fail("control bones in the GLB")
    for name in GUN_BONES:
        if name not in names:
            fail(f"{name} missing from the GLB")
    if len(names) != 47 + len(GUN_BONES):
        fail(f"{len(names)} joints in the GLB")
    if gltf.get("images"):
        fail("images in the GLB")
    exported = sorted(a["name"] for a in gltf.get("animations", []))
    if exported != sorted(a.name for a in bpy.data.actions):
        fail(f"GLB clips {exported} differ from the file clips")
    print("EXPORT VERIFIED", len(names), "joints", exported)


{"build": build, "check": check, "preview": preview, "export": export}[ARGS[0]]()
