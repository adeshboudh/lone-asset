# Builds the first-person suppressed rifle in Blender (run inside Blender).
#
# Body: "M416 / HK416" by natholas, CC0, https://www.blendswap.com/blends/view/17759
# (source/m416_blendswap_cc0.blend). We keep the receiver, stock, handguard, barrel and magazine,
# re-assemble them (the file ships as an exploded layout), and add our own suppressor and a thin
# open red-dot sight. Everything else is original work for Lone Asset, CC BY 4.0.
#
# Output axes: +Y is forward (becomes -Z in Godot), +Z up, X right. Origin sits near the trigger.
# The sight window centre is 0.105 m above the origin so ADS_POSITION in weapon.gd lines up with it.
import bpy
import bmesh
import math
from mathutils import Matrix, Vector

HERE = "/mnt/vol1/PycharmProjects/igi3/content/weapons"
SRC = HERE + "/source/m416_blendswap_cc0.blend"
OUT_GLB = HERE + "/rifle_suppressed.glb"
OUT_BLEND = HERE + "/source/rifle_suppressed.blend"

COLL, TMP = "Rifle", "Rifle_import"
SCALE = 0.085  # model units to metres (rifle body about 0.8 m long)
ORIGIN = Vector((24.8, -28.297, -1.177))  # model-space point that becomes the origin
MAG_POS = Vector((25.9, -28.297, -2.615))  # where the magazine centre sits in the magwell


def fresh_collection(name):
    if name in bpy.data.collections:
        for o in list(bpy.data.collections[name].objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(bpy.data.collections[name])
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


def material(name, color, metallic=0.0, rough=0.5, emit=None, emit_strength=0.0):
    if name in bpy.data.materials:
        bpy.data.materials.remove(bpy.data.materials[name])
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = color
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = emit
        b.inputs["Emission Strength"].default_value = emit_strength
    return m


MAT = {
    "metal": material("m_rifle_metal", (0.085, 0.09, 0.095, 1), 0.75, 0.42),
    "polymer": material("m_rifle_polymer", (0.04, 0.042, 0.045, 1), 0.0, 0.65),
    "supp": material("m_rifle_suppressor", (0.07, 0.073, 0.077, 1), 0.9, 0.3),
    "red": material("m_rifle_marker", (1.0, 0.1, 0.05, 1), 0.0, 0.4, (1.0, 0.1, 0.05, 1), 4.0),
    "dot": material("m_rifle_dot", (1.0, 0.05, 0.03, 1), 0.0, 0.3, (1.0, 0.05, 0.03, 1), 12.0),
}
# material slot names of the source model -> our materials
SLOT_MAP = {"main": "metal", "main.001": "metal", "screw": "metal", "magazine": "polymer", "handle": "polymer", "main.002": "polymer"}

coll = fresh_collection(COLL)
tmp = fresh_collection(TMP)

# ---- import the source parts ----
with bpy.data.libraries.load(SRC, link=False) as (src, dst):
    dst.objects = ["Circle", "Circle.002", "Circle.003"]  # rear body, front body, magazine
for o in dst.objects:
    tmp.objects.link(o)
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()

PARTS = {k: [] for k in MAT}  # material key -> list of bmesh-backed objects


def bake(src_name, label):
    o = bpy.data.objects[src_name]
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    me.transform(o.matrix_world)
    if o.matrix_world.determinant() < 0:  # mirrored parents flip the winding
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
    slots = [SLOT_MAP.get(m.name, "metal") for m in o.data.materials]
    return me, slots


def to_game_space(me, offset=Vector((0, 0, 0))):
    """Model space (+X forward) to game space (+Y forward, metres, origin at ORIGIN)."""
    me.transform(Matrix.Translation(-ORIGIN))
    me.transform(Matrix.Rotation(math.radians(90), 4, "Z"))
    me.transform(Matrix.Scale(SCALE, 4))


def add_mesh(me, name, slots):
    """Split a baked mesh into one object per material key."""
    by_key = {}
    for p in me.polygons:
        by_key.setdefault(slots[p.material_index] if p.material_index < len(slots) else "metal", []).append(p.index)
    for key, idx in by_key.items():
        bm = bmesh.new()
        bm.from_mesh(me)
        keep = set(idx)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        part = bpy.data.meshes.new("%s_%s" % (name, key))
        bm.to_mesh(part)
        bm.free()
        ob = bpy.data.objects.new("%s_%s" % (name, key), part)
        coll.objects.link(ob)
        PARTS[key].append(ob)


for n, label in (("Circle", "rear"), ("Circle.002", "front")):
    me, slots = bake(n, label)
    to_game_space(me)
    add_mesh(me, label, slots)

# magazine: centre it, stand it upright, drop it into the magwell
mag, slots = bake("Circle.003", "mag")
pts = [v.co.copy() for v in mag.vertices]
centre = Vector([(min(p[i] for p in pts) + max(p[i] for p in pts)) / 2 for i in range(3)])
mag.transform(Matrix.Translation(-centre))
mag.transform(Matrix.Rotation(math.radians(90), 4, "X"))
mag.transform(Matrix.Translation(MAG_POS))
to_game_space(mag)
add_mesh(mag, "mag", slots)

# remove the temporary import
for o in list(tmp.objects):
    bpy.data.objects.remove(o, do_unlink=True)
bpy.data.collections.remove(tmp)


# ---- our own parts, built in metres ----
def to_obj(bm, name, key, loc):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new(name, mesh)
    coll.objects.link(o)
    o.location = loc
    PARTS[key].append(o)
    return o


def box(name, key, size, loc, bevel=0.0012):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES")
    return to_obj(bm, name, key, loc)


def cyl(name, key, radius, length, loc, verts=20, bevel=0.0015):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=radius, radius2=radius, depth=length)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"))
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES")
    return to_obj(bm, name, key, loc)


BARREL_Z = 0.009  # barrel axis height above the origin
cyl("suppressor", "supp", 0.0235, 0.17, (0, 0.515, BARREL_Z), 20, 0.002)
cyl("suppressor_collar", "metal", 0.0255, 0.016, (0, 0.437, BARREL_Z), 20, 0.0015)
cyl("suppressor_cap", "metal", 0.0225, 0.010, (0, 0.605, BARREL_Z), 20, 0.0012)

# thin open red-dot sight: two slim uprights on a low stem, a floating dot between them.
# The window is wider than tall (landscape): 0.062 m across, 0.045 m high, centred 0.105 m up.
CZ, GAP, T = 0.105, 0.062, 0.004  # window centre height, gap between uprights, upright thickness
SY = 0.055  # sight position along the rifle
POST_BOTTOM, POST_TOP = 0.0775, 0.1225
box("sight_stem", "metal", (0.016, 0.030, 0.026), (0, SY, 0.0645), 0.001)
box("sight_base", "metal", (GAP + 2 * T + 0.004, 0.030, 0.005), (0, SY, POST_BOTTOM - 0.0015), 0.0008)
for side in (-1, 1):
    x = side * (GAP / 2 + T / 2)
    box("sight_post_%d" % side, "polymer", (T, 0.012, POST_TOP - POST_BOTTOM), (x, SY, (POST_TOP + POST_BOTTOM) / 2), 0.0008)
    box("sight_marker_%d" % side, "red", (0.0015, 0.007, 0.014), (side * (GAP / 2 - 0.0005), SY - 0.001, POST_TOP - 0.010), 0.0004)
cyl("sight_dot", "dot", 0.0018, 0.001, (0, SY, CZ), 8, 0)

# ---- join per material and parent under a root ----
root = bpy.data.objects.new("Rifle", None)
coll.objects.link(root)
for key, objs in PARTS.items():
    if not objs:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    # bake each object's location into its mesh so the origin stays at the rifle origin
    joined.data.transform(joined.matrix_world)
    joined.matrix_world = Matrix.Identity(4)
    joined.name = "rifle_" + key
    joined.data.name = "rifle_" + key
    joined.data.materials.clear()
    joined.data.materials.append(MAT[key])
    joined.parent = root

muzzle = bpy.data.objects.new("Muzzle", None)
muzzle.empty_display_type = "ARROWS"
muzzle.empty_display_size = 0.02
muzzle.location = (0, 0.615, BARREL_Z)
coll.objects.link(muzzle)
muzzle.parent = root
polys = sum(len(o.data.polygons) for o in coll.objects if o.type == "MESH")
print("built", sorted(o.name for o in coll.objects), polys, "polys")

# ---- export ----
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
for ch in root.children_recursive:
    ch.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_materials="EXPORT", export_cameras=False, export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, copy=True)
print("exported", OUT_GLB)
