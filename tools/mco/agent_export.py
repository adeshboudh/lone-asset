# Run: blender -b igi3_mco/mco_agent.blend --python tools/mco/agent_export.py  (writes content/characters/agent_mco/agent_mco.glb)
# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
import bpy
mm=bpy.data.objects["MotusMan_v55.001"]
mm.name="Armature"
for pb in mm.pose.bones:
    pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.rotation_euler=(0,0,0); pb.scale=(1,1,1)
mm.animation_data.action=None
for a in bpy.data.actions:
    a.use_fake_user=True
sel=[mm]+[o for o in bpy.data.objects if o.name.startswith("agent_")]
bpy.ops.object.select_all(action='DESELECT')
for o in sel: o.select_set(True)
bpy.context.view_layer.objects.active=mm
OUT="/mnt/vol1/PycharmProjects/igi3/content/characters/agent_mco/agent_mco.glb"
bpy.ops.export_scene.gltf(filepath=OUT,export_format='GLB',use_selection=True,export_animation_mode='ACTIONS',export_animations=True,export_force_sampling=True,export_apply=False,export_skins=True,export_image_format='JPEG',export_yup=True)
print("EXPORTED")
