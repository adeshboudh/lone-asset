"""Exports the reference two-handed pistol rig (a tutorial file, see content/LICENSES.md) as a GLB for testing.

  blender -b REFERENCE.blend --python tools/blender/ref_viewmodel_export.py -- OUT.glb

Keeps the two armatures (Arms_Rig, Gun_Rig) with their low-poly arms and gun, drops the helper cubes, shape meshes
and camera, and builds one NLA track per game clip (Idle, Draw, Fire, Reload, Reload_Empty) on each armature, so the
glTF exporter merges the arm action and the gun action of a clip into one animation. Units are metres, the camera is
the origin and looks along -Y.
"""
import sys

import bpy

OUT = sys.argv[sys.argv.index("--") + 1]
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

for name, rgba in (("arms", (0.10, 0.10, 0.11, 1.0)), ("gun", (0.35, 0.36, 0.38, 1.0))):
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
    last = int(max(bpy.data.actions[a].frame_range[1] for a in actions))
    for rig_name in RIGS:
        action = anim_utils.bake_action(bpy.data.objects[rig_name], action=None, frames=range(0, last + 1), bake_options=OPTIONS)
        action.name = f"{clip}_{rig_name}"
        baked[clip][rig_name] = action

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
