# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
"""Writes the motion of a hand-made reload clip (gun, magazine, wrists, fingers) as JSON.

Only motion is written, no meshes. Run:
  blender -b assets_src/m4a1_ms/m4a1_reload.blend --python tools/blender/reload_motion_export.py -- out.json
  blender -b --python tools/blender/reload_motion_export.py -- out.json clip.glb   (a glTF export of the same rig)
Every pose bone matrix is in the armature's space (Blender axes: forward -Y, up +Z, right -X, metres), which is
the first-person view. tools/anim/build_reload_empty.gd turns it into a Godot Animation on the M4 pack rig.
"""
import json
import sys

import bpy

GUN = "M4A1_Body"
MAGAZINE = "M4A1_Magazine"
WRISTS = ["Wrist_R", "Wrist_L"]
FINGERS = ["Thumb", "Index", "Middle", "Ring", "Pinky"]
SIDES = ["R", "L"]


def flat(m):
    return [round(v, 6) for row in m for v in row]


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:]
    out_path = args[0]
    if len(args) > 1:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=args[1])
    scene = bpy.context.scene
    arm = bpy.data.objects["Armature"]
    action = arm.animation_data.action
    first, last = int(action.frame_range[0]), int(action.frame_range[1])
    finger_bones = []
    for side in SIDES:
        for finger in FINGERS:
            for joint in (1, 2, 3):
                finger_bones.append("%s_%02d_%s" % (finger, joint, side))
    frames = []
    for frame in range(first, last + 1):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        rec = {"gun": flat(arm.pose.bones[GUN].matrix), "mag": flat(arm.pose.bones[MAGAZINE].matrix)}
        for name in WRISTS:
            rec[name] = flat(arm.pose.bones[name].matrix)
        fingers = {}
        for name in finger_bones:
            pb = arm.pose.bones[name]
            rel = pb.parent.matrix.inverted() @ pb.matrix
            q = rel.to_quaternion()
            fingers[name] = [round(q.w, 6), round(q.x, 6), round(q.y, 6), round(q.z, 6)]
        rec["fingers"] = fingers
        frames.append(rec)
    data = {"fps": scene.render.fps, "first_frame": first, "frames": frames}
    with open(out_path, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    print("WROTE", out_path, len(frames), "frames")


main()
