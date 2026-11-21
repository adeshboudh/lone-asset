# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
"""Builds the rifle viewmodel GLB from the developer's two reload exports (arms, rifle and rig in one armature).

  blender -b --python tools/blender/ms_viewmodel_export.py -- empty.glb tactical.glb out.glb

Takes the model and the Reload_Empty action from the first file, the tactical action from the second, and adds
Idle (the first frame held). Actions are named Reload_Empty, Reload and Idle, the names data/weapons/rifle_*.tres use.
"""
import sys

import bpy


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def fcurves(action):
    return [fc for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]


def main() -> None:
    empty_path, tactical_path, out_path = sys.argv[sys.argv.index("--") + 1:][:3]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    base = import_glb(empty_path)
    arm = next(o for o in base if o.type == "ARMATURE")
    empty_action = arm.animation_data.action
    extra = import_glb(tactical_path)
    tactical_action = next(o for o in extra if o.type == "ARMATURE").animation_data.action
    for obj in extra:
        bpy.data.objects.remove(obj, do_unlink=True)
    for obj in base:
        if obj.type == "MESH" and obj.name.startswith("Icosphere"):
            bpy.data.objects.remove(obj, do_unlink=True)
    empty_action.name = "Reload_Empty"
    tactical_action.name = "Reload"
    idle = empty_action.copy()
    idle.name = "Idle"
    for fc in fcurves(idle):
        value = fc.evaluate(0)
        fc.keyframe_points.clear()
        fc.keyframe_points.insert(0, value)
        fc.keyframe_points.insert(1, value)
    for action in (empty_action, tactical_action, idle):
        action.use_fake_user = True
    arm.animation_data.action = idle
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_animation_mode="ACTIONS", export_apply=False)
    print("WROTE", out_path, [a.name for a in bpy.data.actions])


main()
