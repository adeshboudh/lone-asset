# Pistol arms rig Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the pistol its own two-handed first-person rig (arms and pistol in one Blender armature, five clips keyed in Blender) and use it in the game in place of the M4-retargeted arms and the code-keyed clips.

**Architecture:** Two Blender Python scripts build the rig repeatably (`arms_rig.py` is the shared arms part, `pistol_rig.py` adds the pistol and has the modes `build`, `clips`, `check`, `preview`, `export`). The `.blend` holds the keys; `export` writes a texture-free GLB with deform bones only (IK baked). Godot instances the GLB under a scene whose script puts the textures on by material name and keeps a `Muzzle` node on the muzzle bone. `Weapon` and `FpsArms` need no change.

**Tech Stack:** Blender 5.2 (Python, headless), glTF 2.0, Godot 4.7.2 (typed GDScript, warnings are errors), gdUnit4, `reuse`.

**Spec:** `docs/superpowers/specs/2026-11-17-pistol-arms-rig-design.md` (committed on this branch). The code in this plan was run end to end before it was written down: the scripts built, checked and exported the rig, and the Godot files passed the full test suite in a scratch checkout.

## Global Constraints

- Branch `feat/pistol-arms-rig` (already created from `dev`); the PR goes into `dev`. Do not merge: the developer plays the build and approves first.
- Do not commit `image.png` (the developer's reference screenshot of another game; pose reference only) or `.skills.json`. Stage files by name, never `git add -A`.
- Desktop only (Windows, Linux). Godot 4.7.2, typed GDScript: a `for` variable needs a type (`for b: String in [...]`), warnings are errors.
- Tunable numbers live in `data/**/*.tres` (here: `viewmodel_hip_position`, `viewmodel_ads_position` of both pistol files). Logic that is testable goes in pure `*_rules.gd`; this feature adds no new game logic.
- Systems talk through `EventBus`; nothing in this plan needs it.
- Any asset licence is allowed but each asset is recorded in `content/LICENSES.md` and `REUSE.toml`; `reuse lint` must pass. Never use another game's name or assets ripped from its files; the reference image is for pose and timing only.
- Before pushing: `tools/ci/run_tests.sh` and `reuse lint`. Update `docs/handoff.md`.
- Commit messages end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; the PR description ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Blender runs headless: `BLENDER="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"` then `"$BLENDER" -b --factory-startup --python tools/blender/pistol_rig.py -- <mode>` from the repo root (Git Bash). Units are metres. The camera is the origin and looks along -Y. In Blender +X is the character's **left** (so something right of the crosshair has a negative x). The exported model faces glTF +Z, so the Godot scene turns it half a turn about Y.
- Bone axes of the rig (arms after `straighten_bones` and the gun bones): Y along the bone (forward for the gun bones), Z up, X = Y x Z (to the left). A rotation about X by a positive angle pitches the muzzle up.
- 60 frames per second in the `.blend`; clip lengths are 3.0 s (Idle, loops), 0.45 s (Draw), 0.10 s (Fire), 1.5 s (Reload), 1.9 s (Reload_Empty), matching `data/weapons/pistol_*.tres` (`reload_time` 1.5, `reload_time_empty` 1.9; `ViewmodelAnimationRules.speed_for` stretches a clip to those).

## File Structure

| File | Responsibility |
|---|---|
| `tools/blender/arms_rig.py` (create) | Shared: import the arms, scale to metres, straighten bones, add IK and control bones, the follow switch, hand and finger posing helpers |
| `tools/blender/pistol_rig.py` (create) | The pistol: import, classify and skin its parts, gun bones, grip pose, clips, `check`, `preview`, `export` |
| `content/weapons/pistol/rig/pistol_rig.blend` (create) | Source of truth for the animation keys |
| `content/weapons/pistol/rig/.gdignore` (create) | Keeps Godot from importing the `.blend` |
| `content/weapons/pistol/pistol_viewmodel.glb` (create) | Export: 47 arm bones, 7 gun bones, five clips, no textures |
| `content/weapons/pistol/pistol_viewmodel.tscn`, `.gd` (replace) | Instances the GLB, textures by material name, `Muzzle` node |
| `tests/scenarios/test_pistol_viewmodel.gd` (create) | The new viewmodel |
| `tests/scenarios/test_fps_arms.gd` (modify) | Two loops over all weapons skip the pistol (it has no `FpsArms`) |
| `data/weapons/pistol_muzzle.tres`, `pistol_suppressed.tres` (modify) | Hip and ADS offsets for the new rig |
| `REUSE.toml`, `content/LICENSES.md`, `content/weapons/README.md`, `docs/handoff.md`, the spec (modify) | Records and docs |

---

### Task 1: The rig build script and its check

**Files:**
- Create: `tools/blender/arms_rig.py`
- Create: `tools/blender/pistol_rig.py`
- Create: `content/weapons/pistol/rig/.gdignore` (empty)
- Output: `content/weapons/pistol/rig/pistol_rig.blend`

**Interfaces:**
- Produces (used by every later task): `pistol_rig.py` modes `build [--force]`, `check`, `preview OUT.png [--view eye|side|top] [--action NAME] [--frame N]`, `export`; module constants `GUN_REST`, `GRIP_POSE`, `GRIP_CURL`, `GUN_BONES`, `CONTROL_BONES`, `EXPECTED_VERTS`, `FPS`; the armature object `PistolRig`; bones named in `GUN_BONES`/`CONTROL_BONES` and the arm bones of `fps_arms.glb` unchanged; armature custom properties `L_follows_gun`, `R_follows_gun`.

- [ ] **Step 1: Create the shared arms script**

Create `tools/blender/arms_rig.py`:

```python
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
```

- [ ] **Step 2: Create the pistol script (without clips; task 3 adds them)**

Create `tools/blender/pistol_rig.py`:

```python
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
```

- [ ] **Step 3: Create the empty `.gdignore`**

Run: `mkdir -p content/weapons/pistol/rig && : > content/weapons/pistol/rig/.gdignore`

- [ ] **Step 4: Build the rig**

Run:
```bash
BLENDER="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$BLENDER" -b --factory-startup --python tools/blender/pistol_rig.py -- build
```
Expected: two `pole angle` lines, then `BUILD OK .../content/weapons/pistol/rig/pistol_rig.blend`, exit 0. The `.blend` is about 0.6 MB.

- [ ] **Step 5: Run the check**

Run: `"$BLENDER" -b --factory-startup --python tools/blender/pistol_rig.py -- check`
Expected: `CHECK OK`. (It verifies the bones, the IK and the follow switch, the arm reach, each hand within 12 cm of the grip, every arm vertex weighted, the pistol part vertex counts `gun_slide` 804, `gun_hammer` 104, `gun_trigger` 126, `gun_mag` 113, the spare magazine copy, and that no images are left in the file.)

- [ ] **Step 6: Check that a rebuild is refused without `--force`**

Run: `"$BLENDER" -b --factory-startup --python tools/blender/pistol_rig.py -- build; echo "exit $?"`
Expected: a message ending `Pass --force to rebuild.` and a non-zero exit.

- [ ] **Step 7: Look at the rig**

Run (writes outside the repo):
```bash
OUT="$(mktemp -d)"
for v in eye side top; do "$BLENDER" -b --factory-startup --python tools/blender/pistol_rig.py -- preview "$OUT/$v.png" --view $v; done
echo "$OUT"
```
Read the three PNGs. Expected: a Glock-like pistol upright with its muzzle forward (to the left in the side view, up in the top view); both arms come from the bottom of the eye view and converge on the grip; no stretched or exploded geometry. (The exact hand pose is tuned in task 2.)

- [ ] **Step 8: Commit**

```bash
git add tools/blender/arms_rig.py tools/blender/pistol_rig.py content/weapons/pistol/rig/.gdignore content/weapons/pistol/rig/pistol_rig.blend
git commit -m "feat: Blender script that builds the pistol arms rig

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Tune the two-handed grip pose against the reference (developer approval gate)

**Files:**
- Modify: `tools/blender/pistol_rig.py` (the constants `GUN_REST`, `GRIP_POSE`, `GRIP_CURL` only)
- Output: rebuilt `content/weapons/pistol/rig/pistol_rig.blend`

**Interfaces:**
- Consumes: task 1's `build`, `check`, `preview`.
- Produces: the rest pose every clip starts and ends on (`GRIP_POSE`, `GRIP_CURL`, `GUN_REST`).

The starting values are a first guess. The reference is `image.png` in the repo root (read it with the Read tool): a two-handed pistol idle in first person.

What the reference shows, in order of importance:
1. Both hands wrap the grip together: the left hand cups the right, the fingers overlap, both thumbs run forward along the frame.
2. The gun sits low and a little right of the centre of the screen, its top (the slide) about 58 % of the way down the frame, the muzzle pointing up and away.
3. Both forearms enter from the bottom of the screen in a V that narrows toward the grip; the elbows are out of view.
4. Nothing passes through the frame or slide.

- [ ] **Step 1: Render the eye view and compare**

Run:
```bash
OUT="$(mktemp -d)"
"$BLENDER" -b --factory-startup --python tools/blender/pistol_rig.py -- preview "$OUT/eye.png" --view eye
```
Read `$OUT/eye.png` next to `image.png` and list what differs against the four points above.

- [ ] **Step 2: Adjust the constants**

What each constant does (Blender axes: +X is the character's left, -Y is forward, +Z is up):
- `GUN_REST` (metres, camera space): where the grip centre sits. A gun right of the crosshair needs a negative x. Raising z raises the gun on the screen; more negative y moves it farther away.
- `GRIP_POSE[side]["head"]`: where that wrist sits, as if the gun were at rest. Keep the right wrist at a negative x (right of the grip) and the left at a positive x. Bringing a wrist closer to the grip centre wraps the hand closer.
- `GRIP_POSE[side]["turn"]`: degrees about the world X, Y, Z axes from the hand's rest orientation (a hand at rest points straight forward). To roll a hand around the grip, turn about Y; to lift the fingers, turn about X by a negative angle.
- `GRIP_CURL[finger]`: degrees for segments 1 to 4 about the bone's local X. If the fingertips bend away from the palm, negate the values.
- Keep each wrist within 0.12 m of `GUN_REST` (the check enforces it) and each arm within reach (the check enforces that too).

Edit `tools/blender/pistol_rig.py`.

- [ ] **Step 3: Rebuild, check, render**

```bash
"$BLENDER" -b --factory-startup --python tools/blender/pistol_rig.py -- build --force && \
"$BLENDER" -b --factory-startup --python tools/blender/pistol_rig.py -- check && \
"$BLENDER" -b --factory-startup --python tools/blender/pistol_rig.py -- preview "$OUT/eye.png" --view eye
```
Also render `--view side` and `--view top` to see the fingers and the overlap. Repeat steps 2 and 3 until the four points match. Stop after about six rounds and show the developer where it stands.

- [ ] **Step 4: Get the developer's approval**

Stop here. Tell the developer the path of the final eye, side and top PNGs and what is still different from the reference. Wait for "approved" before going on. If they ask for changes, go back to step 2.

- [ ] **Step 5: Commit**

```bash
git add tools/blender/pistol_rig.py content/weapons/pistol/rig/pistol_rig.blend
git commit -m "feat: two-handed pistol grip pose, tuned to the reference

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The five clips

**Files:**
- Modify: `tools/blender/pistol_rig.py` (six edits below)
- Output: `content/weapons/pistol/rig/pistol_rig.blend` with five actions

**Interfaces:**
- Consumes: task 2's rest pose (`GRIP_POSE`, `GRIP_CURL`), `arms_rig.place_bone`, `arms_rig.set_finger_curl`.
- Produces: actions `Idle` (loops, 180 frames), `Draw` (27), `Fire` (6), `Reload` (90), `Reload_Empty` (114) at 60 fps; mode `clips [--force]`; `check` now also verifies the clips.

Each key of a clip is complete (a missing entry is the rest pose), the hands are placed with the gun at rest and then the gun moves, so a hand that follows the gun keeps its place on the grip. The old magazine and the spare are hidden by a bone scale of 0.001 (`HIDDEN`), popped over one frame.

- [ ] **Step 1: Add the `clips` line to the usage text**

In the module docstring of `tools/blender/pistol_rig.py`, below the line `  blender -b --python tools/blender/pistol_rig.py -- build [--force]` add:
```
  blender -b --python tools/blender/pistol_rig.py -- clips [--force]
```

- [ ] **Step 2: Add the clip constants**

Directly below the line `FPS = 60` add:
```python
HIDDEN = 0.001  # a bone scale that hides a part (0 would make the skin matrix singular)
OPEN_CURL = {"thumb": (0.0, 0.0, 0.0, 0.0), "point": (15.0, 15.0, 10.0, 0.0), "middle": (15.0, 15.0, 10.0, 0.0),
             "ring": (15.0, 15.0, 10.0, 0.0), "pink": (15.0, 15.0, 10.0, 0.0)}

```

- [ ] **Step 3: Add the clip code**

Insert immediately above the line `# ---------------------------------------------------------------- check, preview, export`:
```python
# ---------------------------------------------------------------- clips

def key(frame: int, **spec):
    """One key of a clip. spec (all optional; a missing entry is the rest pose, so every key is complete):
    gun=(loc, rot_deg)  ctl_gun, bone axes X left, Y forward, Z up; rotation about X pitches the muzzle up
    slide=m             slide travel along Y (negative is back)       hammer=deg  trigger=deg  (about X)
    mag=(x, y, z)       old magazine offset                           mag_scale=1.0 or HIDDEN
    spare=(x, y, z)     spare magazine offset                         spare_scale=1.0 or HIDDEN
    hold=0..1           spare magazine rides the left hand (1) or the gun (0)
    R=(head, turn_deg) / L=(head, turn_deg)   wrist control as if the gun were at rest (camera space, metres)
    follow_R / follow_L  0..1   hand control rides the gun (1) or is free (0)
    curl_R / curl_L      0 open hand .. 1 grip"""
    return frame, spec


def _bone_values(pb, location=None, rotation_deg=None, scale=None) -> None:
    pb.rotation_mode = "XYZ"
    pb.location = location if location is not None else (0.0, 0.0, 0.0)
    pb.rotation_euler = Euler([math.radians(a) for a in (rotation_deg or (0.0, 0.0, 0.0))], "XYZ")
    pb.scale = (scale, scale, scale) if scale is not None else (1.0, 1.0, 1.0)


def pose_key(arm, frame: int, spec: dict) -> None:
    """Poses every animated channel for one key and keyframes it. The hands are placed with the gun at rest, then the
    gun moves, so a hand that follows the gun keeps its place on the grip."""
    bones = arm.pose.bones
    _bone_values(bones["ctl_gun"])
    bpy.context.view_layer.update()
    for side in arms_rig.SIDES:
        head, turn = spec.get(side, (GRIP_POSE[side]["head"], GRIP_POSE[side]["turn"]))
        arms_rig.place_bone(arm, f"ctl_hand_{side}", head, turn)
        t = spec.get(f"curl_{side}", 1.0)
        curls = {f: tuple(o + (g - o) * t for o, g in zip(OPEN_CURL[f], GRIP_CURL[f])) for f in GRIP_CURL}
        arms_rig.set_finger_curl(arm, side, curls)
        arm[f"{side}_follows_gun"] = spec.get(f"follow_{side}", 1.0)
    gun_loc, gun_rot = spec.get("gun", ((0.0, 0.0, 0.0), (0.0, 0.0, 0.0)))
    _bone_values(bones["ctl_gun"], gun_loc, gun_rot)
    _bone_values(bones["gun_slide"], (0.0, spec.get("slide", 0.0), 0.0))
    _bone_values(bones["gun_hammer"], None, (spec.get("hammer", 0.0), 0.0, 0.0))
    _bone_values(bones["gun_trigger"], None, (spec.get("trigger", 0.0), 0.0, 0.0))
    _bone_values(bones["gun_mag"], spec.get("mag"), None, spec.get("mag_scale", 1.0))
    _bone_values(bones["gun_mag_spare"], spec.get("spare"), None, spec.get("spare_scale", HIDDEN))
    hold = bones["gun_mag_spare"].constraints["Held in the left hand"]
    hold.influence = spec.get("hold", 0.0)
    bpy.context.view_layer.update()
    for name in ("ctl_gun", "gun_slide", "gun_hammer", "gun_trigger", "gun_mag", "gun_mag_spare"):
        bones[name].keyframe_insert("location", frame=frame)
        bones[name].keyframe_insert("rotation_euler", frame=frame)
        bones[name].keyframe_insert("scale", frame=frame)
    for side in arms_rig.SIDES:
        bones[f"ctl_hand_{side}"].keyframe_insert("location", frame=frame)
        bones[f"ctl_hand_{side}"].keyframe_insert("rotation_quaternion", frame=frame)
        arm.keyframe_insert(f'["{side}_follows_gun"]', frame=frame)
    for pb in bones:
        m = arms_rig.FINGER.match(pb.name)
        if m:
            pb.keyframe_insert("rotation_euler", frame=frame)
    hold.keyframe_insert("influence", frame=frame)


def make_action(arm, name: str, length: int, keys, loop: bool = False):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data_create().action = act
    for frame, spec in keys:
        pose_key(arm, frame, spec)
    act.use_frame_range = True
    act.frame_start, act.frame_end = 1, length
    act.use_cyclic = loop
    return act


# Lengths follow data/weapons/pistol_*.tres (reload 1.5 s, empty 1.9 s); the game stretches a clip to those times.
# First-pass numbers, tuned in the viewport (plan, task 4). The pouch is where the spare magazine starts, low and left.
# The hand is pitched up 70 degrees so the magazine (6 cm ahead of the wrist, see ctl_mag_hold) sits above the wrist;
# BELOW_WELL puts it 4 cm under the magazine well.
POUCH = (Vector((0.10, -0.22, -0.34)), (-70.0, 0.0, 0.0))
BELOW_WELL = (Vector((0.015, -0.355, -0.266)), (-70.0, 0.0, 0.0))
SLIDE_GRIP = (Vector((0.02, -0.33, -0.13)), (0.0, 0.0, 0.0))


def reload_keys(empty: bool):
    keys = [
        key(1),
        key(8, gun=((0.006, 0.0, 0.0), (0.0, 8.0, 0.0))),
        key(14, gun=((0.006, 0.0, 0.0), (0.0, 8.0, 0.0)), follow_L=0.0),
        key(22, gun=((0.006, 0.0, 0.0), (0.0, 8.0, 0.0)), follow_L=0.0, L=BELOW_WELL, curl_L=0.2),
        key(32, gun=((0.006, 0.0, 0.0), (0.0, 8.0, 0.0)), follow_L=0.0, L=POUCH, curl_L=0.2,
            mag=((0.0, 0.0, -0.20)), mag_scale=1.0),
        key(33, gun=((0.006, 0.0, 0.0), (0.0, 8.0, 0.0)), follow_L=0.0, L=POUCH, curl_L=0.6,
            mag=((0.0, 0.0, -0.20)), mag_scale=HIDDEN, spare_scale=HIDDEN, hold=1.0),
        key(34, gun=((0.006, 0.0, 0.0), (0.0, 8.0, 0.0)), follow_L=0.0, L=POUCH, curl_L=0.6,
            mag_scale=HIDDEN, spare_scale=1.0, hold=1.0),
        key(54, gun=((0.006, 0.0, 0.0), (0.0, 8.0, 0.0)), follow_L=0.0, L=BELOW_WELL, curl_L=0.6,
            mag_scale=HIDDEN, spare_scale=1.0, hold=1.0),
        key(56, gun=((0.006, 0.0, 0.0), (0.0, 8.0, 0.0)), follow_L=0.0, L=BELOW_WELL, curl_L=0.6,
            mag_scale=HIDDEN, spare=((0.0, 0.0, -0.04)), spare_scale=1.0, hold=0.0),
        key(62, gun=((0.006, 0.0, 0.003), (0.0, 6.0, 0.0)), follow_L=0.0, L=BELOW_WELL, curl_L=0.6,
            mag_scale=HIDDEN, spare_scale=1.0, hold=0.0),
        key(63, gun=((0.006, 0.0, 0.003), (0.0, 6.0, 0.0)), follow_L=0.0, L=BELOW_WELL, curl_L=0.6,
            mag_scale=1.0, spare_scale=HIDDEN, hold=0.0),
        key(72, follow_L=1.0, curl_L=1.0),
    ]
    if not empty:
        return keys + [key(90)]
    return keys[:-1] + [
        key(72, follow_L=0.0, L=SLIDE_GRIP, curl_L=0.5),
        key(80, follow_L=0.0, L=(SLIDE_GRIP[0] + Vector((0.0, 0.026, 0.0)), (0.0, 0.0, 0.0)), curl_L=0.5, slide=-0.026),
        key(84, follow_L=0.0, L=(SLIDE_GRIP[0] + Vector((0.0, 0.026, 0.0)), (0.0, 0.0, 0.0)), curl_L=0.5, slide=-0.026),
        key(86, follow_L=0.0, L=SLIDE_GRIP, curl_L=0.4, slide=0.0),
        key(100, follow_L=1.0, curl_L=1.0),
        key(114),
    ]


def make_clips() -> None:
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    arm = bpy.data.objects["PistolRig"]
    if bpy.data.actions and "--force" not in ARGS:
        sys.exit("the file already has clips; clips refuses to overwrite keyed work. Pass --force to regenerate.")
    for act in list(bpy.data.actions):
        bpy.data.actions.remove(act)
    gun = (lambda loc, rot: (loc, rot))
    make_action(arm, "Idle", 180, [key(1), key(90, gun=gun((0.0, 0.0, 0.002), (0.4, 0.0, 0.0))), key(180)], loop=True)
    make_action(arm, "Draw", 27, [key(1, gun=gun((0.0, -0.03, -0.14), (-30.0, 0.0, 0.0))),
                                  key(17, gun=gun((0.0, 0.01, 0.012), (4.0, 0.0, 0.0))), key(27)])
    make_action(arm, "Fire", 6, [
        key(1),
        key(2, gun=gun((0.0, -0.018, 0.004), (5.0, 0.0, 0.0)), slide=-0.022, hammer=-35.0, trigger=14.0),
        key(3, gun=gun((0.0, -0.020, 0.005), (6.0, 0.0, 0.0)), slide=-0.026, hammer=-35.0, trigger=14.0),
        key(4, gun=gun((0.0, -0.010, 0.002), (3.0, 0.0, 0.0)), slide=-0.012, trigger=6.0),
        key(6)])
    make_action(arm, "Reload", 90, reload_keys(False))
    make_action(arm, "Reload_Empty", 114, reload_keys(True))
    arm.animation_data.action = bpy.data.actions["Idle"]
    bpy.context.scene.frame_set(1)
    save_blend()
    print("CLIPS OK", [a.name for a in bpy.data.actions])
```

- [ ] **Step 4: Add the clip check**

Insert immediately above `def preview() -> None:` (two blank lines before and after):
```python
CLIPS = ("Idle", "Draw", "Fire", "Reload", "Reload_Empty")
TRACKED = ("gun_root", "gun_slide", "gun_hammer", "gun_trigger", "gun_mag", "gun_mag_spare", "ctl_hand_L", "ctl_hand_R",
           "L_middle4_014", "R_middle4_037", "L_thumb4_07", "R_thumb4_029")


def snapshot(arm, action, frame: int):
    arm.animation_data_create().action = action
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    return {n: (arm.matrix_world @ arm.pose.bones[n].head, arm.pose.bones[n].scale[0]) for n in TRACKED}


def check_clips(arm) -> None:
    """Every clip exists, ends on the rest pose (and starts on it, except Draw), and the spare magazine does not jump when it leaves the hand."""
    for name in CLIPS:
        if name not in bpy.data.actions:
            fail(f"clip {name} missing")
    rest = snapshot(arm, bpy.data.actions["Idle"], 1)
    for name in CLIPS:
        act = bpy.data.actions[name]
        ends = {"end": snapshot(arm, act, int(act.frame_end))}
        if name != "Draw":  # Draw starts with the gun lowered
            ends["start"] = snapshot(arm, act, 1)
        for where, pose in ends.items():
            for bone in TRACKED:
                gap = (pose[bone][0] - rest[bone][0]).length
                if gap > 0.002 or abs(pose[bone][1] - rest[bone][1]) > 0.01:
                    fail(f"{name}: {bone} is {gap:.4f} m from the rest pose at the {where}")
    for name in ("Reload", "Reload_Empty"):
        act = bpy.data.actions[name]
        before, after = snapshot(arm, act, 54), snapshot(arm, act, 56)
        jump = (before["gun_mag_spare"][0] - after["gun_mag_spare"][0]).length
        if jump > 0.05:
            fail(f"{name}: the spare magazine jumps {jump:.3f} m when it leaves the hand")
```

In `check()`, replace the last line `    print("CHECK OK")` with:
```python
    if bpy.data.actions:
        check_clips(arm)
    print("CHECK OK")
```

- [ ] **Step 5: Add `clips` to the mode table**

At the bottom of the file replace
`{"build": build, "check": check, "preview": preview, "export": export}[ARGS[0]]()`
with
`{"build": build, "clips": make_clips, "check": check, "preview": preview, "export": export}[ARGS[0]]()`

- [ ] **Step 6: Generate the clips and check them**

```bash
"$BLENDER" -b --factory-startup --python tools/blender/pistol_rig.py -- clips
"$BLENDER" -b --factory-startup --python tools/blender/pistol_rig.py -- check
```
Expected: `CLIPS OK ['Draw', 'Fire', 'Idle', 'Reload', 'Reload_Empty']` and `CHECK OK`. The check fails if a clip does not end on the rest pose (or start on it, except Draw), or if the spare magazine jumps more than 5 cm when it leaves the hand. Run `clips` again without `--force`: expected a refusal.

- [ ] **Step 7: Look at the clips**

```bash
OUT="$(mktemp -d)"
p() { "$BLENDER" -b --factory-startup --python tools/blender/pistol_rig.py -- preview "$OUT/$1.png" --view "$2" --action "$3" --frame "$4"; }
p draw_1 eye Draw 1; p fire_3 side Fire 3; p reload_34 side Reload 34; p reload_54 side Reload 54; p empty_84 side Reload_Empty 84
```
Read the PNGs. Expected: Draw 1: gun low and tilted down; Fire 3: slide back, muzzle lifted; Reload 34: the left hand low and to the left holding the (orange) spare magazine, the old magazine gone; Reload 54: the left hand raised with the spare magazine just under the magazine well; Reload_Empty 84: the left hand behind the slide, the slide pulled back. The numbers in the key tables (`POUCH`, `BELOW_WELL`, `SLIDE_GRIP`, gun offsets, slide travel, hammer and trigger angles and their signs) are first-pass values: if a part moves the wrong way (the hammer or trigger rotating the wrong way is likely), flip the sign, if a hand misses the magazine or slide move its target, then run `clips --force`, `check` and the renders again. Keep the `check` passing.

- [ ] **Step 8: Commit**

```bash
git add tools/blender/pistol_rig.py content/weapons/pistol/rig/pistol_rig.blend
git commit -m "feat: pistol clips (Idle, Draw, Fire, Reload, Reload_Empty) keyed on the arms rig

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Export and use the rig in the game

**Files:**
- Output: `content/weapons/pistol/pistol_viewmodel.glb` (and Godot's `.glb.import`)
- Create: `tests/scenarios/test_pistol_viewmodel.gd`
- Modify: `tests/scenarios/test_fps_arms.gd`
- Replace: `content/weapons/pistol/pistol_viewmodel.gd`, `content/weapons/pistol/pistol_viewmodel.tscn`
- Modify: `data/weapons/pistol_muzzle.tres`, `data/weapons/pistol_suppressed.tres`

**Interfaces:**
- Consumes: the five clips and bone names from task 3 (`gun_muzzle`, `gun_mag_spare`, ...); `FpsArms.LAYER` (`1 << 18`); `LimbBuilder.pbr(dir, name)`; `WeaponDefinition.anim_*`, `reload_time`, `reload_time_empty`, `viewmodel_ads_position`.
- Produces: a viewmodel scene whose root has a `Muzzle` direct child and a `Model/.../AnimationPlayer`; the weapon code finds both (`Weapon._build_viewmodel`).

- [ ] **Step 1: Export**

```bash
"$BLENDER" -b --factory-startup --python tools/blender/pistol_rig.py -- export
```
Expected: `EXPORT OK` and `EXPORT VERIFIED 54 joints ['Draw', 'Fire', 'Idle', 'Reload', 'Reload_Empty']`. The GLB is about 0.9 MB.

- [ ] **Step 2: Write the tests first**

Create `tests/scenarios/test_pistol_viewmodel.gd`:
```gdscript
extends GdUnitTestSuite
## The pistol viewmodel: its own two-handed arms rig (pistol_viewmodel.glb), not the M4 pack's arms.

const PISTOL: WeaponDefinition = preload("res://data/weapons/pistol_muzzle.tres")
const GUN_BONES: Array[StringName] = [&"gun_root", &"gun_slide", &"gun_mag", &"gun_mag_spare", &"gun_trigger",
		&"gun_hammer", &"gun_muzzle"]
const ARM_BONES: Array[StringName] = [&"L_arm_01", &"L_wrist_03", &"L_middle4_014", &"R_arm_023", &"R_wrist_025",
		&"R_middle4_037"]

var _viewmodel: Node3D
var _skeleton: Skeleton3D
var _player: AnimationPlayer


func before_test() -> void:
	_viewmodel = auto_free(PISTOL.viewmodel_scene.instantiate())
	add_child(_viewmodel)
	await await_idle_frame()
	_skeleton = _viewmodel.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = _viewmodel.find_child("AnimationPlayer", true, false) as AnimationPlayer


func test_the_skeleton_has_the_arm_and_gun_bones_and_no_control_bones() -> void:
	for bone: StringName in GUN_BONES + ARM_BONES:
		assert_int(_skeleton.find_bone(bone)).is_greater_equal(0)
	for bone: StringName in [&"ctl_gun", &"ctl_hand_L", &"ctl_hand_R", &"pole_elbow_L", &"pole_elbow_R"]:
		assert_int(_skeleton.find_bone(bone)).is_equal(-1)


func test_it_does_not_use_the_m4_arms() -> void:
	assert_object(_viewmodel.find_child("FpsArms", true, false)).is_null()
	assert_int(_skeleton.find_bone(&"RightHand")).is_equal(-1)


func test_the_clips_the_definition_names_exist_and_idle_loops() -> void:
	for animation: StringName in [PISTOL.anim_idle, PISTOL.anim_draw, PISTOL.anim_fire, PISTOL.anim_reload,
			PISTOL.anim_reload_empty]:
		assert_bool(_player.has_animation(animation)).is_true()
	assert_int(_player.get_animation(PISTOL.anim_idle).loop_mode).is_equal(Animation.LOOP_LINEAR)
	assert_float(_player.get_animation(PISTOL.anim_reload).length).is_equal_approx(PISTOL.reload_time, 0.05)
	assert_float(_player.get_animation(PISTOL.anim_reload_empty).length).is_equal_approx(PISTOL.reload_time_empty, 0.05)


func test_the_muzzle_is_ahead_of_the_camera_and_follows_the_muzzle_bone() -> void:
	var muzzle: Node3D = _viewmodel.get_node_or_null(^"Muzzle") as Node3D
	assert_object(muzzle).is_not_null()
	assert_float(_viewmodel.to_local(muzzle.global_position).z).is_less(-0.3)
	_player.play(PISTOL.anim_fire)
	_player.seek(0.03, true)
	_player.pause()
	await await_idle_frame()
	await await_idle_frame()
	var bone: Vector3 = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone(&"gun_muzzle"))).origin
	assert_float(muzzle.global_position.distance_to(bone)).is_less(0.001)


func test_every_mesh_is_on_the_viewmodel_layer_with_the_textures_on() -> void:
	for node: Node in _viewmodel.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		assert_int(mesh.layers).is_equal(FpsArms.LAYER)
		assert_object(mesh.get_surface_override_material(0)).is_not_null()


func test_the_spare_magazine_is_hidden_until_the_reload_brings_it() -> void:
	var spare: int = _skeleton.find_bone(&"gun_mag_spare")
	_player.play(PISTOL.anim_idle)
	_player.seek(0.0, true)
	_player.pause()
	assert_float(_skeleton.get_bone_pose_scale(spare).x).is_less(0.01)
	_player.play(PISTOL.anim_reload)
	_player.seek(0.7, true)
	_player.pause()
	assert_float(_skeleton.get_bone_pose_scale(spare).x).is_greater(0.9)
	_player.seek(PISTOL.reload_time, true)
	assert_float(_skeleton.get_bone_pose_scale(spare).x).is_less(0.01)


func test_aimed_the_muzzle_is_on_the_crosshair_line() -> void:
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	var viewmodel: Node3D = PISTOL.viewmodel_scene.instantiate()
	camera.add_child(viewmodel)
	viewmodel.position = PISTOL.viewmodel_ads_position
	await await_idle_frame()
	await await_idle_frame()
	var muzzle: Vector3 = (viewmodel.get_node("Muzzle") as Node3D).global_position
	# the front sight stands about 1.2 cm above the barrel
	assert_float(muzzle.x).is_between(-0.005, 0.005)
	assert_float(muzzle.y).is_between(-0.02, -0.005)
```

In `tests/scenarios/test_fps_arms.gd` make three edits. Above `func _arms(weapon: Weapon) -> FpsArms:` add:
```gdscript
## A weapon with its own arms rig (the pistol) animates its arms directly and gets no FpsArms.
func _has_own_rig(weapon: Weapon) -> bool:
	return weapon.viewmodel.find_child("PistolRig", true, false) != null


```
In `test_every_weapon_has_the_arms_on_the_viewmodel_layer_without_shadows` and in `test_one_handed_weapons_fold_the_left_arm_away`, directly under the line `for weapon: Weapon in _player._weapons:` add:
```gdscript
		if _has_own_rig(weapon):
			continue
```

- [ ] **Step 3: Run the new tests to see them fail**

```bash
export GODOT_BIN="$(command -v godot)"
addons/gdUnit4/runtest.sh --headless -a res://tests/scenarios/test_pistol_viewmodel.gd --ignoreHeadlessMode
```
Expected: FAILED (the old viewmodel has none of the gun bones and still has `FpsArms`).

- [ ] **Step 4: Replace the viewmodel scene and script**

Overwrite `content/weapons/pistol/pistol_viewmodel.tscn`:
```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://content/weapons/pistol/pistol_viewmodel.gd" id="1"]
[ext_resource type="PackedScene" path="res://content/weapons/pistol/pistol_viewmodel.glb" id="2_model"]

[node name="PistolViewmodel" type="Node3D"]
script = ExtResource("1")

[node name="Model" parent="." instance=ExtResource("2_model")]
transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 0)
```

Overwrite `content/weapons/pistol/pistol_viewmodel.gd`:
```gdscript
extends Node3D
## First-person 9mm pistol with its own two-handed arms. One rig (content/weapons/pistol/rig/pistol_rig.blend, built by
## tools/blender/pistol_rig.py) holds the arms ("fps arms" by DJMaesen, CC-BY) and the pistol ("9mm Pistol" by TORI106,
## CC-BY, see content/LICENSES.md), and its clips move both, so the M4 pack's arms are not used here.
## The model faces glTF's front (+Z); Model is turned half a turn so the muzzle points along -Z like the other
## viewmodels. The origin of this node is the camera. Exposes the Muzzle node the Weapon node looks for.
const ARMS_MODEL := "res://content/characters/fps_arms/fps_arms.glb"
const TEXTURES := "res://content/weapons/pistol/textures/"

var _skeleton: Skeleton3D
var _muzzle: Node3D
var _muzzle_bone: int = -1


func _ready() -> void:
	var model: Node = $Model
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
	_apply_materials(model)
	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	add_child(_muzzle)
	_muzzle_bone = _skeleton.find_bone(&"gun_muzzle")
	_skeleton.skeleton_updated.connect(_follow_muzzle)
	_follow_muzzle()


## The Muzzle node (a direct child, where Weapon looks for it) rides the muzzle bone, so the flash and the shot start
## where the barrel is after the recoil.
func _follow_muzzle() -> void:
	_muzzle.global_position = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_muzzle_bone)).origin


## The GLB carries plain materials named for what they cover; the textures go on here.
func _apply_materials(model: Node) -> void:
	var by_name: Dictionary = {
		&"arms": _arms_material(),
		&"pistol_frame": LimbBuilder.pbr(TEXTURES, "pistol_9m1"),
		&"pistol_slide": LimbBuilder.pbr(TEXTURES, "pistol_9m2"),
	}
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		mesh.layers = FpsArms.LAYER
		for surface: int in mesh.mesh.get_surface_count():
			var wanted: Material = by_name.get(StringName(mesh.mesh.surface_get_material(surface).resource_name)) as Material
			if wanted != null:
				mesh.set_surface_override_material(surface, wanted)


## The arms' own material, as the fps arms model imports it.
func _arms_material() -> Material:
	var scene: Node = (load(ARMS_MODEL) as PackedScene).instantiate()
	var source: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var material: Material = source.mesh.surface_get_material(0)
	scene.free()
	return material
```

- [ ] **Step 5: Import and run the new tests**

```bash
godot --headless --path . --import
addons/gdUnit4/runtest.sh --headless -a res://tests/scenarios/test_pistol_viewmodel.gd --ignoreHeadlessMode
```
Expected: six tests PASS; `test_aimed_the_muzzle_is_on_the_crosshair_line` FAILS (the hip and ADS offsets still belong to the old model).

- [ ] **Step 6: Set the hip and ADS offsets**

The rig already places the gun where the previews show it, so the hip offset becomes zero. For the ADS offset, measure where the muzzle sits in the viewmodel's own space. Create `measure.gd` in the repo root (delete it after):
```gdscript
extends SceneTree

func _initialize() -> void:
	var vm: Node3D = (load("res://content/weapons/pistol/pistol_viewmodel.tscn") as PackedScene).instantiate()
	root.add_child(vm)
	await process_frame
	await process_frame
	print("MUZZLE ", vm.to_local((vm.get_node("Muzzle") as Node3D).global_position))
	quit()
```
Run: `godot --headless --path . -s measure.gd 2>&1 | grep MUZZLE; rm measure.gd`

With the muzzle at `m` (for the first-pass grip it was `(-0.015, -0.1253, -0.548)`), set in **both** `data/weapons/pistol_muzzle.tres` and `data/weapons/pistol_suppressed.tres`:
```
viewmodel_hip_position = Vector3(0, 0, 0)
viewmodel_ads_position = Vector3(-m.x, -(m.y + 0.012), -0.02)
```
(The front sight stands about 1.2 cm above the barrel, so the muzzle ends up 1.2 cm below the crosshair. For the first-pass numbers that is `Vector3(0.015, 0.1133, -0.02)`; use your own `m` after task 2.)

- [ ] **Step 7: Run the whole suite**

Run: `tools/ci/run_tests.sh`
Expected: exit 0, no FAILED. (`test_weapon_switching` and `test_fps_arms` must still pass.)

- [ ] **Step 8: Commit**

```bash
git add content/weapons/pistol/pistol_viewmodel.glb content/weapons/pistol/pistol_viewmodel.glb.import content/weapons/pistol/pistol_viewmodel.gd content/weapons/pistol/pistol_viewmodel.tscn tests/scenarios/test_pistol_viewmodel.gd tests/scenarios/test_pistol_viewmodel.gd.uid tests/scenarios/test_fps_arms.gd data/weapons/pistol_muzzle.tres data/weapons/pistol_suppressed.tres
git status --short
git commit -m "feat: the pistol uses its own two-handed arms rig

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```
(`git status --short` should show only `image.png` and `.skills.json` as untracked; add any other new `.uid` or `.import` file that Godot generated for the files above.)

---

### Task 5: Records, docs and the pull request

**Files:**
- Modify: `REUSE.toml`, `content/LICENSES.md`, `content/weapons/README.md`, `docs/handoff.md`, `docs/superpowers/specs/2026-11-17-pistol-arms-rig-design.md`

**Interfaces:**
- Consumes: everything above.
- Produces: a PR into `dev`; `reuse lint` and the test suite pass.

- [ ] **Step 1: Licence annotation**

Append to the end of `REUSE.toml` (later annotations win, so it goes last):
```toml

[[annotations]]
path = ["content/weapons/pistol/rig/**", "content/weapons/pistol/pistol_viewmodel.glb", "content/weapons/pistol/pistol_viewmodel.glb.import"]
precedence = "override"
SPDX-FileCopyrightText = ["DJMaesen (Sketchfab)", "TORI106 (Sketchfab)"]
SPDX-License-Identifier = "CC-BY-4.0"
```

- [ ] **Step 2: `content/LICENSES.md`**

In the row for `content/weapons/pistol/source/9mmPistol.fbx` replace the last cell's ending `rotated, scaled and held in the M4 pack's right hand by `content/weapons/pistol/pistol_viewmodel.gd`` with `model unchanged here; rotated, scaled and rigged to the fps arms in `tools/blender/pistol_rig.py` (see the next row)`. In the row for `content/characters/fps_arms/fps_arms.glb` append to the last cell: `; the pistol uses its own copy, see the pistol rig row`. Add a new row after the fps arms row:

```
| `content/weapons/pistol/rig/pistol_rig.blend`, `content/weapons/pistol/pistol_viewmodel.glb` | DJMaesen (arms), TORI106 (pistol) | https://skfb.ly/6R6yX ("fps arms"), https://skfb.ly/owxRE ("9mm Pistol") | CC-BY-4.0 | 2026-11-17 | The arms and the pistol rigged together by `tools/blender/pistol_rig.py` (IK and control bones, the pistol split into slide, magazine, trigger and hammer, five clips keyed by hand and by script); the export has no textures, `content/weapons/pistol/pistol_viewmodel.gd` puts the two original texture sets on by material name |
```

- [ ] **Step 3: `content/weapons/README.md`**

Replace the section `## `pistol/` and `knife/` (slots 2 and 3)` and its paragraph (it is one heading and one paragraph) with:

```
## `pistol/` (slot 2)

"9mm Pistol" by TORI106 (CC BY 4.0, https://skfb.ly/owxRE) rigged together with the first-person arms ("fps arms" by DJMaesen, CC BY 4.0) in one armature, `rig/pistol_rig.blend`, built by `tools/blender/pistol_rig.py` (modes `build`, `clips`, `check`, `preview`, `export`; run `blender -b --python tools/blender/pistol_rig.py -- <mode>` with Blender 5.2). It has two hands: IK arms with control bones (`ctl_hand_L/R`, `pole_elbow_L/R`, `ctl_gun`, `ctl_mag_hold`) and the gun bones `gun_root`, `gun_slide`, `gun_mag`, `gun_mag_spare` (the fresh magazine the left hand brings in), `gun_trigger`, `gun_hammer`, `gun_muzzle`. The left hand follows the gun by the armature property `L_follows_gun` (0 to 1, keyed in the clips). The clips (Idle, Draw, Fire, Reload, Reload_Empty) live in the `.blend`; `clips --force` regenerates them from the key tables in the script and discards hand edits. `export` writes `pistol_viewmodel.glb` (deform bones only, IK baked, no textures); `pistol_viewmodel.gd` puts the textures on by material name and keeps a `Muzzle` node on the muzzle bone. `rig/` has a `.gdignore` so Godot does not import the `.blend`. The pistol does not use `FpsArms` or the M4 pack.

## `knife/` (slot 3)

"M9 Bayonet knife" by Michael Karel (CC BY 4.0, https://skfb.ly/6BY6P) is a static model without hands, so `knife_viewmodel.gd` orients and textures it and puts it in the right fist of the M4 pack's arms (`hands_rig.gd`: the rifle is hidden, the left arm shrunk away, the arm shrunk and swung down so it stays out of the sight picture). Its animations are hand-keyed clips built in code (`clip_builder.gd`, keys in the viewmodel script) that turn the arm and the knife about the grip: Draw, Idle, Fire (quick slash, fire button) and Fire_Alt (heavy thrust, aim button). The numbers are the `melee_*` fields in `data/weapons/knife.tres`.
```
(In the `m4/` section the sentence "The pistol and knife use the same rig through `hands_rig.gd`." becomes "The knife uses the same rig through `hands_rig.gd`.")

- [ ] **Step 4: `docs/handoff.md`**

Make these edits:
1. `Last updated: 2026-11-15.` becomes `Last updated: 2026-11-17.`
2. In the status table add after the last `(weapons)` row: `| (weapons) | Pistol with its own two-handed arms rig built in Blender (arms and pistol in one armature, five clips) | PR open |`
3. In the `Weapons:` paragraph replace the sentence beginning `Pistol and knife are static models held in the M4 pack's right arm` through `(the keys are in each viewmodel script).` with: `The knife is a static model held in the M4 pack's right arm (`content/weapons/hands_rig.gd`) with hand-keyed clips built in code (`content/weapons/clip_builder.gd`; the keys are in its viewmodel script). The pistol has its own rig: arms and pistol in one armature built in Blender (`tools/blender/pistol_rig.py`, source `content/weapons/pistol/rig/pistol_rig.blend`, export `content/weapons/pistol/pistol_viewmodel.glb`), two hands, five clips keyed in Blender; design in `docs/superpowers/specs/2026-11-17-pistol-arms-rig-design.md`, how to edit it in `content/weapons/README.md`.`
4. In the `First-person arms:` paragraph replace `(pistol and knife hide the left arm)` with `(the knife hides the left arm; the pistol has its own two-handed rig and gets no `FpsArms`, because `FpsArms.attach` finds no `RightHand` bone on it)`.
5. In the bullet starting `- Weapons are checked by rendered screenshots and tests` replace `the pistol and knife clip timing, and how sway looks on the pistol and knife` with `the knife clip timing, the pistol rig's grip pose and clips (tuned against a reference image, not yet played), and how sway looks on the pistol and knife`.

`docs/acceptance/m1-acceptance.md` needs no change: none of its criteria mention the pistol (`grep -n -i pistol docs/acceptance/m1-acceptance.md` finds nothing).

- [ ] **Step 5: Record what changed from the spec**

Append to the end of `docs/superpowers/specs/2026-11-17-pistol-arms-rig-design.md`:

```
## Changes made while planning (2026-11-17)

- The `.blend` lives in `content/weapons/pistol/rig/` (with a `.gdignore`), not in `source/`, so its licence entry can credit both authors and Godot does not try to import it. The `.blend` is 0.6 MB and the GLB 0.9 MB, so storage is not a concern. The GLB has no textures; Godot puts them on by material name.
- Extra control bone `ctl_mag_hold` (child of `ctl_hand_L`): the spare magazine copies it while the left hand holds the magazine. Both hands have a follow switch (`L_follows_gun`, `R_follows_gun`).
- `pistol_rig.py` also has the modes `clips` (writes the five actions from key tables; refuses to overwrite without `--force`) and `check` (structure, vertex counts, and that each clip ends on the rest pose, starts on it except Draw, and that the spare magazine does not jump when it leaves the hand). `export` reads the GLB back and verifies it.
- The scene turns the model half a turn about Y (glTF faces +Z). `Muzzle` is a plain `Node3D`, a direct child of the viewmodel root where `Weapon` looks for it, that follows the `gun_muzzle` bone; a `BoneAttachment3D` cannot sit there.
- Idle loops through `Animation.loop_mode` set in the script (the importer does not loop it); clips run at 60 fps in the `.blend`; Draw starts with the gun lowered, so only its end is the rest pose.
- Hip offset becomes zero; the ADS offset comes from the muzzle position. `test_fps_arms.gd` skips weapons that have their own rig.
```

- [ ] **Step 6: Verify**

```bash
reuse lint
tools/ci/run_tests.sh
git status --short
```
Expected: `reuse lint` ends with `Congratulations! Your project is compliant`; the test suite exits 0 with no FAILED; `git status` shows only the edited docs, `REUSE.toml`, and the untracked `image.png` and `.skills.json`.

- [ ] **Step 7: Commit and push**

```bash
git add REUSE.toml content/LICENSES.md content/weapons/README.md docs/handoff.md docs/superpowers/specs/2026-11-17-pistol-arms-rig-design.md
git commit -m "docs: licences, README, handoff and spec notes for the pistol arms rig

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
git push -u origin feat/pistol-arms-rig
```

- [ ] **Step 8: Open the pull request into `dev`**

```bash
gh pr create --base dev --title "feat: pistol with its own two-handed arms rig (Blender)" --body "$(cat <<'EOF'
## What

The pistol gets its own rig: the first-person arms and the pistol in one Blender armature, with IK arms, a follow switch for the left hand, a spare magazine for the reload and five clips (Idle, Draw, Fire, Reload, Reload_Empty) keyed in Blender. The game plays the GLB export directly; the pistol no longer uses `FpsArms`, the M4 pack's arms or the code-keyed clips. The rifle and knife are unchanged.

- `tools/blender/arms_rig.py`, `tools/blender/pistol_rig.py`: build, clips, check, preview and export, run headless (Blender 5.2).
- `content/weapons/pistol/rig/pistol_rig.blend` (source of the keys) and `pistol_viewmodel.glb` (export).
- `pistol_viewmodel.tscn/.gd` rewritten; new `test_pistol_viewmodel.gd`; `test_fps_arms.gd` skips weapons that have their own rig.
- Hip and ADS offsets of both pistol files re-derived for the new rig.
- Design: `docs/superpowers/specs/2026-11-17-pistol-arms-rig-design.md`; plan: `docs/superpowers/plans/2026-11-17-pistol-arms-rig.md`.

## Checks

- `tools/ci/run_tests.sh` and `reuse lint` pass.
- `pistol_rig.py check` passes (structure, vertex counts, clips start and end on the rest pose, no magazine jump).
- Needs the developer to play it: grip pose and clip feel were tuned against a reference image and rendered stills only. Do not merge before that.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
Then tell the developer the PR link and that it waits for them to play the build.
