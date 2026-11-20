# Run: blender -b igi3_mco/mco_import.blend --python tools/mco/agent_skin.py  (writes igi3_mco/mco_agent.blend)
# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
import bpy, math
from mathutils import Matrix, Vector
OUTB="/mnt/vol1/PycharmProjects/igi3_mco/mco_agent.blend"
THETA=math.radians(46)
mm=bpy.data.objects["MotusMan_v55.001"]; mm_mesh=bpy.data.objects["MotusMan_v55"]
mm.animation_data.action=None
for pb in mm.pose.bones:
    pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.rotation_euler=(0,0,0); pb.scale=(1,1,1)
bpy.context.view_layer.update()
bpy.ops.import_scene.gltf(filepath="/mnt/vol1/PycharmProjects/igi3/content/characters/agent/agent_body.glb")
ag_arm=bpy.data.objects["base soldier1"]
agent=[o for o in bpy.data.objects if o.type=="MESH" and o.parent==ag_arm]
junk=[o for o in bpy.data.objects if o.name.startswith("Icosphere")]
for o in junk: bpy.data.objects.remove(o,do_unlink=True)
def ctx(o):
    bpy.ops.object.select_all(action='DESELECT') if bpy.context.mode=='OBJECT' else None
    o.select_set(True); bpy.context.view_layer.objects.active=o
def rot_arm(arm,bone,theta):
    W=arm.matrix_world; pb=arm.pose.bones[bone]
    p=W@pb.head
    Rw=Matrix.Translation(p)@Matrix.Rotation(theta,4,'Y')@Matrix.Translation(-p)
    pb.matrix=W.inverted()@Rw@W@pb.matrix
    bpy.context.view_layer.update()
def a_pose(arm,sign=1):
    for b,s in (("LeftArm",1),("RightArm",-1)): rot_arm(arm,b,s*THETA*sign)
# 1. MM in A pose, bake deformed copy as weight source
a_pose(mm)
src=mm_mesh.copy(); src.data=mm_mesh.data.copy(); src.name="weight_src"
bpy.context.scene.collection.objects.link(src)
ctx(src)
with bpy.context.temp_override(object=src,active_object=src):
    for m in src.modifiers:
        if m.type=='ARMATURE': bpy.ops.object.modifier_apply(modifier=m.name)
mw_src=mm_mesh.matrix_world.copy(); src.parent=None; src.matrix_world=mw_src
# 2. transfer weights onto agent meshes
names=[g.name for g in mm_mesh.vertex_groups]
for o in agent:
    mw=o.matrix_world.copy()
    o.parent=None; o.matrix_world=mw
    for m in list(o.modifiers): o.modifiers.remove(m)
    o.vertex_groups.clear()
    for n in names: o.vertex_groups.new(name=n)
    dt=o.modifiers.new("DT",'DATA_TRANSFER')
    dt.object=src; dt.use_vert_data=True; dt.data_types_verts={'VGROUP_WEIGHTS'}
    dt.vert_mapping='POLYINTERP_NEAREST'; dt.layers_vgroup_select_src='ALL'; dt.layers_vgroup_select_dst='NAME'
    dt.use_object_transform=True
    with bpy.context.temp_override(object=o,active_object=o):
        bpy.ops.object.modifier_apply(modifier="DT")
# torso and vest must not follow the arm chain: drop arm weights inside the torso width
ARMCHAIN=[n for n in names if ("Arm" in n or "Hand" in n) and "Shoulder" not in n]
for o in agent:
    if "helmet" in o.name: continue
    vest="bproof" in o.name
    mw=o.matrix_world
    arm_idx={o.vertex_groups[n].index for n in ARMCHAIN}
    spine=o.vertex_groups["Spine2"]
    for v in o.data.vertices:
        x=(mw@v.co).x
        if not (vest or (abs(x)<0.19 and "jaket" in o.name)): continue
        w=[(g.group,g.weight) for g in v.groups]
        keep=[(i,wt) for i,wt in w if i not in arm_idx and wt>1e-6]
        drop=sum(wt for i,wt in w if i in arm_idx)
        if drop<=0: continue
        for i,_ in w:
            if i in arm_idx: o.vertex_groups[i].remove([v.index])
        if keep:
            t=sum(wt for _,wt in keep)
            for i,wt in keep: o.vertex_groups[i].add([v.index],wt/t,'REPLACE')
        else: spine.add([v.index],1.0,'REPLACE')
# helmet had no weights: bind rigidly to Head
for o in agent:
    if "helmet" in o.name:
        for v in o.data.vertices: o.vertex_groups["Head"].add([v.index],1.0,'REPLACE')
# 3. A_rig: copy of MM armature with A pose applied as rest
mm.pose  # MM currently in A pose
arig=mm.copy(); arig.data=mm.data.copy(); arig.name="A_rig"
bpy.context.scene.collection.objects.link(arig)
ctx(arig)
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.pose.select_all(action='SELECT')
bpy.ops.pose.armature_apply(selected=False)
bpy.ops.object.mode_set(mode='OBJECT')
for pb in arig.pose.bones:
    pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.rotation_euler=(0,0,0); pb.scale=(1,1,1)
bpy.context.view_layer.update()
# 4. bind agent to A_rig, then pose A_rig back to T pose and bake
for o in agent:
    am=o.modifiers.new("Arm",'ARMATURE'); am.object=arig
a_pose(arig,-1)   # rotate arms back up: A_rig now in T pose
for o in agent:
    with bpy.context.temp_override(object=o,active_object=o):
        bpy.ops.object.modifier_apply(modifier="Arm")
# 5. bind baked T-pose meshes to the original MM armature (rest = T)
for pb in mm.pose.bones:
    pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.rotation_euler=(0,0,0); pb.scale=(1,1,1)
bpy.context.view_layer.update()
for o in agent:
    o.parent=mm; o.matrix_parent_inverse=mm.matrix_world.inverted()
    am=o.modifiers.new("Armature",'ARMATURE'); am.object=mm
# cleanup
for o in (src,arig,ag_arm,mm_mesh): bpy.data.objects.remove(o,do_unlink=True)
for o in agent: o.name="agent_"+o.name.replace(" ","_")
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=OUTB)
tot={}
for o in agent:
    for v in o.data.vertices:
        for g in v.groups: tot[o.vertex_groups[g.group].name]=tot.get(o.vertex_groups[g.group].name,0)+g.weight
print("TOPW",sorted(tot.items(),key=lambda x:-x[1])[:8])
print("SKIN_OK",[o.name for o in agent])
