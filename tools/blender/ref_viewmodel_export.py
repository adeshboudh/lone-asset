"""Exports the reference two-handed pistol rig (a tutorial file, see content/LICENSES.md) as a GLB for testing.

  blender -b REFERENCE.blend --python tools/blender/ref_viewmodel_export.py -- OUT.glb [--blocky-gun]

Keeps the two armatures (Arms_Rig, Gun_Rig) with their low-poly arms, drops the helper cubes, shape meshes and
camera, and replaces the reference's blocky gun with the real 9mm Pistol (content/weapons/pistol/source, split into
parts by tools/blender/pistol_rig.py and skinned to the gun rig's gun_root, slide and mag bones; --blocky-gun keeps the
blocky one). The model is scaled to the blocky gun's length and sits on its bottom, centre line and muzzle end.
It builds one baked clip per game clip (Idle, Draw, Fire, Reload, Reload_Empty) on each armature, so the glTF exporter
merges the arm and gun tracks of a clip into one animation. Units are metres, the camera is the origin and looks
along -Y.
"""
import os
import sys

import bpy

OUT = sys.argv[sys.argv.index("--") + 1]
BLOCKY_GUN = "--blocky-gun" in sys.argv
# game clip: (arms action, gun action)
CLIPS = {
    "Idle": ("FP_idle_pose", "GUN_idle"),
    "Draw": ("FP_idle_pose", "GUN_idle"),
    "Fire": ("FP_fire", "GUN_fire"),
    "Reload": ("FP_reload", "GUN_reload"),
    "Reload_Empty": ("FP_reload", "GUN_reload"),
}
KEEP = {"Arms_Rig", "Gun_Rig", "arms", "gun"}

for obj in list(bpy.data.objects):
    if obj.name not in KEEP:
        bpy.data.objects.remove(obj, do_unlink=True)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Matrix, Quaternion, Vector  # noqa: E402


def replace_the_blocky_gun() -> None:
    """Puts the real pistol on the gun rig: same length, bottom, centre line and muzzle end as the blocky gun."""
    import pistol_rig

    blocky = bpy.data.objects["gun"]
    world = [blocky.matrix_world @ v.co for v in blocky.data.vertices]
    ref_lo = Vector((min(p.x for p in world), min(p.y for p in world), min(p.z for p in world)))
    ref_hi = Vector((max(p.x for p in world), max(p.y for p in world), max(p.z for p in world)))
    frame, slide, members = pistol_rig.import_pistol()
    points = [v.co.copy() for o in (frame, slide) for v in o.data.vertices]
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    scale = (ref_hi.y - ref_lo.y) / (hi.y - lo.y)
    anchor = Vector(((lo.x + hi.x) * 0.5, lo.y, lo.z))
    target = Vector(((ref_lo.x + ref_hi.x) * 0.5, ref_lo.y, ref_lo.z))
    place = Matrix.Translation(target) @ Matrix.Scale(scale, 4) @ Matrix.Translation(-anchor)
    gun_rig = bpy.data.objects["Gun_Rig"]
    bone_of = {"gun_root": "gun_root", "gun_slide": "slide", "gun_mag": "mag", "gun_trigger": "gun_root", "gun_hammer": "gun_root"}
    for obj in (frame, slide):
        obj.data.transform(place)
        obj.data.update()
        obj.parent = gun_rig
        obj.matrix_parent_inverse = gun_rig.matrix_world.inverted()
        obj.modifiers.new("Armature", "ARMATURE").object = gun_rig
    for group, items in members.items():
        for obj in {o for o, _ in items}:
            vg = obj.vertex_groups.get(bone_of[group]) or obj.vertex_groups.new(name=bone_of[group])
            vg.add([i for o, i in items if o is obj], 1.0, "REPLACE")
    bpy.data.objects.remove(blocky, do_unlink=True)
    muzzle = pistol_rig.muzzle_point(frame, slide)
    slide_head = gun_rig.matrix_world @ gun_rig.data.bones["slide"].head_local
    print("MUZZLE_FROM_SLIDE (blender)", tuple(round(v, 4) for v in (muzzle - slide_head)),
          "scale", round(scale, 4), "scale", "length", round(ref_hi.y - ref_lo.y, 4))


if not BLOCKY_GUN:
    replace_the_blocky_gun()

for name, rgba in (("arms", (0.10, 0.10, 0.11, 1.0)),) + ((("gun", (0.35, 0.36, 0.38, 1.0)),) if BLOCKY_GUN else ()):
    mat = bpy.data.materials.new(f"ref_{name}")
    mat.diffuse_color = rgba
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = rgba
    bpy.data.objects[name].data.materials.clear()
    bpy.data.objects[name].data.materials.append(mat)

from bpy_extras import anim_utils  # noqa: E402



# The hands are children of the gun (and the left hand of the magazine), so the arms' pose depends on what the gun
# is doing. The glTF exporter bakes one rig at a time with the other rig's tracks all active, which makes the hands
# follow the wrong gun clip. So each clip is baked here with both rigs on their own matching actions at once, and
# the exporter only sees plain keys.
RIGS = ("Arms_Rig", "Gun_Rig")
OPTIONS = anim_utils.BakeOptions(
    only_selected=False, do_pose=True, do_object=False, do_visual_keying=True, do_constraint_clear=False,
    do_parents_clear=False, do_clean=False, do_location=True, do_rotation=True, do_scale=True, do_bbone=False,
    do_custom_props=False)


def action_curves(action: bpy.types.Action) -> list:
    return [fc for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]


def shift_curve(fc, delta_of) -> None:
    for point in fc.keyframe_points:
        delta = delta_of(point.co[0])
        point.co[1] += delta
        point.handle_left[1] += delta
        point.handle_right[1] += delta
    fc.update()


IDLE_LOOP = 60  # frames; the idle breath repeats every 60 frames, the action's 75 is just where its tilt curve ends


def make_idle_loop_and_match_the_other_clips() -> None:
    """The reference's idle breath repeats every 60 frames, but its tilt curve is keyed 15 to 75 and the position
    curve 0 to 60, so frame 0 and frame 60 are not the same pose, and the clip rests 1.6 cm away from where the fire and
    reload clips start and end. Every handover (Fire to Idle, Reload to Idle) and every loop of Idle jumped. Each moving
    curve gets keys at frames 0 and 60 holding the same value (what the curve already has at 60), and the gun root is
    moved onto the fire clip's rest pose."""
    idle = bpy.data.actions["GUN_idle"]
    fire = bpy.data.actions["GUN_fire"]
    fire_rest = {(fc.data_path, fc.array_index): fc.evaluate(fire.frame_range[0]) for fc in action_curves(fire)}
    for fc in action_curves(idle):
        values = [point.co[1] for point in fc.keyframe_points]
        if max(values) - min(values) > 1e-6:
            closed = fc.evaluate(IDLE_LOOP)
            for frame in (0, IDLE_LOOP):
                fc.keyframe_points.insert(frame, closed, options={"REPLACE"})
            fc.update()
        key = (fc.data_path, fc.array_index)
        if "gun_root" in fc.data_path and key in fire_rest:
            to_rest = fire_rest[key] - fc.evaluate(0)
            shift_curve(fc, lambda frame, to_rest=to_rest: to_rest)


make_idle_loop_and_match_the_other_clips()

baked: dict[str, dict[str, bpy.types.Action]] = {clip: {} for clip in CLIPS}
# A bake leaves its keyed values on the bones that no source action animates (the fingers), and the next clip's
# constraints would stack on them; every clip starts from the file's own pose.
ORIGINAL = {(rig, pb.name): pb.matrix_basis.copy() for rig in RIGS for pb in bpy.data.objects[rig].pose.bones}
for clip, actions in CLIPS.items():
    for (rig, name), basis in ORIGINAL.items():
        bpy.data.objects[rig].pose.bones[name].matrix_basis = basis
    bpy.context.view_layer.update()
    for rig_name, action_name in zip(RIGS, actions):
        data = bpy.data.objects[rig_name].animation_data_create()
        for old in list(data.nla_tracks):
            data.nla_tracks.remove(old)  # the tutorial file stashes its actions in NLA tracks
        data.action = bpy.data.actions[action_name]
    last = IDLE_LOOP if clip in ("Idle", "Draw") else int(max(bpy.data.actions[a].frame_range[1] for a in actions))
    for rig_name in RIGS:
        # Idle loops, so it stops one frame short: its last frame would otherwise repeat its first.
        frames = range(0, last) if clip == "Idle" else range(0, last + 1)
        action = anim_utils.bake_action(bpy.data.objects[rig_name], action=None, frames=frames, bake_options=OPTIONS)
        action.name = f"{clip}_{rig_name}"
        baked[clip][rig_name] = action

# A pistol is the most controlled gun, but the reference's fire clip throws the gun and both hands about 6 cm. Every
# bone's motion in Fire is scaled toward its first-frame pose, except the slide (it still cycles), the magazine and
# the fingers (the trigger press).
FIRE_MOTION = 0.3
FULL_MOTION = ("slide", "mag", "finger", "thumb")


def scale_motion(action: bpy.types.Action, factor: float) -> None:
    bones: dict[str, dict[tuple[str, int], "bpy.types.FCurve"]] = {}
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    if fc.data_path.startswith("pose.bones["):
                        name = fc.data_path.split('"')[1]
                        bones.setdefault(name, {})[(fc.data_path.rsplit(".", 1)[1], fc.array_index)] = fc

    def put(fc, k: int, value: float) -> None:
        point = fc.keyframe_points[k]
        shift = value - point.co[1]
        point.co[1] += shift
        point.handle_left[1] += shift
        point.handle_right[1] += shift

    for name, channels in bones.items():
        if any(part in name for part in FULL_MOTION):
            continue
        for (kind, index), fc in channels.items():
            if kind in ("location", "scale"):
                first = fc.keyframe_points[0].co[1]
                for k in range(len(fc.keyframe_points)):
                    put(fc, k, first + factor * (fc.keyframe_points[k].co[1] - first))
        if all(("rotation_quaternion", i) in channels for i in range(4)):
            comps = [channels[("rotation_quaternion", i)] for i in range(4)]
            first = Quaternion([c.keyframe_points[0].co[1] for c in comps])
            for k in range(len(comps[0].keyframe_points)):
                quat = Quaternion([c.keyframe_points[k].co[1] for c in comps])
                if first.dot(quat) < 0.0:
                    quat.negate()
                slerped = first.slerp(quat, factor)
                for i, c in enumerate(comps):
                    put(c, k, slerped[i])
        for fc in channels.values():
            fc.update()


for rig_name in RIGS:
    scale_motion(baked["Fire"][rig_name], FIRE_MOTION)

for rig_name in RIGS:
    rig = bpy.data.objects[rig_name]
    rig.animation_data.action = None
    for pose_bone in rig.pose.bones:
        for constraint in list(pose_bone.constraints):
            pose_bone.constraints.remove(constraint)  # the baked keys already hold their result
    for clip in CLIPS:
        track = rig.animation_data.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 0, baked[clip][rig_name])

print("TRACKS", {o.name: [t.name for t in o.animation_data.nla_tracks] for o in (bpy.data.objects["Arms_Rig"], bpy.data.objects["Gun_Rig"])})
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", use_selection=False, export_apply=False,
    export_animations=True, export_animation_mode="NLA_TRACKS", export_def_bones=True,
    export_force_sampling=True, export_optimize_animation_size=False, export_yup=True, export_cameras=False, export_lights=False,
)
print("EXPORT OK", OUT)
