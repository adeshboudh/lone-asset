"""Shared first-person arms rig, used by the per-weapon rig scripts (pistol_rig.py).

Runs inside Blender (headless: blender -b --python ...). Units are metres. The camera is the origin and
looks along -Y (Blender front), +Z is up, +X is toward the viewer's left. The glTF export turns -Y into
glTF +Z, so the Godot viewmodel scene turns the model 180 degrees about Y (see pistol_viewmodel.gd).

Bone axes after straighten_bones(): Y runs along the bone (head to tail), Z is as close to world up as the
bone allows, X = Y x Z. A finger bone curls about its local X.
"""
import math
import re

import bpy
from mathutils import Euler, Matrix, Vector

CM = 0.01
# upper arm, forearm (the bone called "elbow" in the file), wrist, per side
CHAIN = {
    "L": ("L_arm_01", "L_elbow_02", "L_wrist_03"),
    "R": ("R_arm_023", "R_elbow_024", "R_wrist_025"),
}
FINGER = re.compile(r"^([LR])_(thumb|point|middle|ring|pink)([1-4])_")
SIDES = ("L", "R")


def object_mode() -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")


def enter_mode(obj, mode: str) -> None:
    object_mode()
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode=mode)


def import_arms(glb_path: str):
    """Imports the arms model; returns (armature object, mesh object) with the importer's helper objects removed."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    created = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in created if o.type == "ARMATURE")
    mesh = next(o for o in created if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers))
    for pb in arm.pose.bones:
        pb.custom_shape = None
        # The importer leaves each bone in the file default pose (in file units, centimetres); the mesh is bound at rest.
        pb.rotation_mode = "QUATERNION"
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)
    for o in (arm, mesh):
        world = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = world
    mesh.parent = arm
    mesh.matrix_parent_inverse = arm.matrix_world.inverted()
    for o in created:
        if o not in (arm, mesh):
            bpy.data.objects.remove(o, do_unlink=True)
    arm.name, arm.data.name = "PistolRig", "PistolRig"
    mesh.name, mesh.data.name = "arms", "arms"
    return arm, mesh


def plain_material(name: str, rgba) -> bpy.types.Material:
    """A texture-free material; Godot puts the real textures on it by name after the import."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = rgba
    return mat


def strip_textures(mesh, material_name: str) -> None:
    """Replaces the mesh materials with one plain material and drops the imported images."""
    mesh.data.materials.clear()
    mesh.data.materials.append(plain_material(material_name, (0.15, 0.17, 0.19, 1.0)))
    for img in list(bpy.data.images):
        bpy.data.images.remove(img)
    for mat in list(bpy.data.materials):
        if mat.users == 0:
            bpy.data.materials.remove(mat)


def bake_transform(arm, mesh, matrix: Matrix) -> None:
    """Moves the bones and the mesh by matrix (uniform scale and translation only), so the object transforms stay identity."""
    enter_mode(arm, "EDIT")
    for b in arm.data.edit_bones:
        b.head = matrix @ b.head
        b.tail = matrix @ b.tail
    object_mode()
    mesh.data.transform(matrix)
    mesh.data.update()


def straighten_bones(arm) -> None:
    """Points every bone at its child (the importer gives arbitrary tails), so IK sees the real arm segments, and
    aligns the roll so the local Z is up."""
    enter_mode(arm, "EDIT")
    eb = arm.data.edit_bones
    for b in eb:
        b.use_connect = False
    leaves = []
    for b in list(eb):
        kids = list(b.children)
        if b.name == "_rootJoint":
            continue
        if len(kids) == 1:
            b.tail = kids[0].head.copy()
        elif kids:
            b.tail = sum((k.head for k in kids), Vector()) / len(kids)
        else:
            leaves.append(b)
    for b in leaves:
        direction = (b.head - b.parent.head).normalized()
        b.tail = b.head + direction * b.parent.length * 0.5
    for b in eb:
        if b.name != "_rootJoint":
            b.align_roll(Vector((0.0, 0.0, 1.0)))
    object_mode()


def _control_bone(eb, name: str, head: Vector, tail: Vector, roll: float, parent=None):
    bone = eb.new(name)
    bone.head, bone.tail, bone.roll = head, tail, roll
    bone.use_deform = False
    bone.parent = parent
    return bone


def add_arm_controls(arm, pole_offset: Vector) -> None:
    """Per side: ctl_hand_<s> (IK target and wrist orientation), pole_elbow_<s> (where the elbow points), a two-bone
    IK on the forearm and a Copy Rotation on the wrist. The control starts exactly on the wrist."""
    enter_mode(arm, "EDIT")
    eb = arm.data.edit_bones
    for s in SIDES:
        _, forearm, wrist = CHAIN[s]
        w = eb[wrist]
        _control_bone(eb, f"ctl_hand_{s}", w.head.copy(), w.tail.copy(), w.roll)
        elbow = eb[forearm].head.copy()
        sign = 1.0 if s == "L" else -1.0
        pole = elbow + Vector((sign * pole_offset.x, pole_offset.y, pole_offset.z))
        _control_bone(eb, f"pole_elbow_{s}", pole, pole + Vector((0.0, 0.0, 0.04)), 0.0)
    enter_mode(arm, "POSE")
    for s in SIDES:
        _, forearm, wrist = CHAIN[s]
        ik = arm.pose.bones[forearm].constraints.new("IK")
        ik.name = "IK"
        ik.target, ik.subtarget = arm, f"ctl_hand_{s}"
        ik.pole_target, ik.pole_subtarget = arm, f"pole_elbow_{s}"
        ik.chain_count = 2
        ik.use_tail = True
        ik.use_stretch = False
        rot = arm.pose.bones[wrist].constraints.new("COPY_ROTATION")
        rot.name = "Hand rotation"
        rot.target, rot.subtarget = arm, f"ctl_hand_{s}"
    object_mode()


def add_follow_switch(arm, side: str, target_bone: str, default: float = 1.0) -> str:
    """Makes ctl_hand_<side> ride on target_bone, by an amount from 0 to 1 that is the armature's custom property
    <side>_follows_gun (key it in a clip). Returns the property name."""
    prop = f"{side}_follows_gun"
    arm[prop] = default
    arm.id_properties_ui(prop).update(min=0.0, max=1.0)
    bpy.context.view_layer.update()
    enter_mode(arm, "POSE")
    pb = arm.pose.bones[f"ctl_hand_{side}"]
    con = pb.constraints.new("CHILD_OF")
    con.name = "Follow gun"
    con.target, con.subtarget = arm, target_bone
    con.inverse_matrix = (arm.matrix_world @ arm.pose.bones[target_bone].matrix).inverted()
    driver = con.driver_add("influence").driver
    driver.type = "AVERAGE"
    var = driver.variables.new()
    var.name = "follow"
    var.type = "SINGLE_PROP"
    var.targets[0].id = arm
    var.targets[0].data_path = '["' + prop + '"]'
    object_mode()
    return prop


def place_bone(arm, name: str, head: Vector, turn_deg=(0.0, 0.0, 0.0)) -> None:
    """Poses a bone so its head is at `head` (armature space) and it is turned by `turn_deg` (XYZ Euler about the
    world axes) from its rest orientation."""
    bone = arm.data.bones[name]
    basis = bone.matrix_local.to_3x3()
    turn = Euler([math.radians(a) for a in turn_deg], "XYZ").to_matrix()
    arm.pose.bones[name].matrix = Matrix.Translation(head) @ (turn @ basis).to_4x4()
    bpy.context.view_layer.update()


def set_finger_curl(arm, side: str, curls) -> None:
    """curls: {finger: (deg for segment 1, 2, 3, 4)}. Rotation about the bone local X."""
    for pb in arm.pose.bones:
        m = FINGER.match(pb.name)
        if m is None or m.group(1) != side:
            continue
        degrees = curls[m.group(2)][int(m.group(3)) - 1]
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = Euler((math.radians(degrees), 0.0, 0.0), "XYZ")
    bpy.context.view_layer.update()


def choose_pole_angle(arm, side: str) -> float:
    """With the hand already placed, picks the IK pole angle that puts the elbow lowest. Returns degrees."""
    ik = arm.pose.bones[CHAIN[side][1]].constraints["IK"]
    best, best_z = 0.0, 1e9
    for degrees in (-180.0, -90.0, 0.0, 90.0):
        ik.pole_angle = math.radians(degrees)
        bpy.context.view_layer.update()
        elbow = arm.matrix_world @ arm.pose.bones[CHAIN[side][1]].head
        if elbow.z < best_z:
            best, best_z = degrees, elbow.z
    ik.pole_angle = math.radians(best)
    bpy.context.view_layer.update()
    return best
