"""Splits the city props and chain-link fence packs into one glb per prop.

Run: blender -b -P tools/blender/export_props.py
Reads the pack glbs from assets_src/props/ and writes content/environment/props/{city,fence}/sm_*.glb.
Each prop is moved so its origin is the centre of its footprint at floor level (y = 0 in Godot).
"""
import bpy
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets_src", "props")
OUT = os.path.join(ROOT, "content", "environment", "props")

CITY = {
	"sm_dumpster": ["Dumpster_Dumpster_shader_0", "LidLeft_DumpsterLid_shader_0", "LidRight_DumpsterLid_shader_0"],
	"sm_trash_can_large": ["TrashCanLarge_TrashCanLarge_shader_0"],
	"sm_trash_can_small": ["TrashCanSmall_TrashCanSmall_shader_0"],
	"sm_trash_can_cap": ["TrashCanCap_TrashCanCap_shader_0"],
	"sm_trash_commercial": ["TrashCommercial_TrashCommercial_shader_0"],
	"sm_fire_hydrant": ["FireHydrant_FireHydrant_shader_0"],
	"sm_park_bench_short": ["ParkBenchShort_ParkBenchShort_shader_0"],
	"sm_concrete_bench": ["ConcreteBench_ConcreteBench_shader_0"],
	"sm_post_barrier": ["PostBarrier_PostBarrier_shader_0"],
	"sm_crate_tarp_1": ["TarpCrate1_Crate1_shader_0"],
	"sm_crate_tarp_2": ["TarpCrate2_Crate2_shader_0"],
	"sm_crate_tarp_3": ["TarpCrate3_Crate3_shader_0"],
	"sm_crate_tarp_4": ["TarpCrate4_Crate4_shader_0"],
	"sm_pallet": ["pallet1_Pallet_shader_0"],
	"sm_street_light": ["Light_Light_shader_0"],
	"sm_post_box": ["PostBox_PostBox_shader_0"],
	"sm_parking_meter": ["ParkingMeter_ParkingMeter_shader_0"],
}


def fence_parts(name):
	return [name + "_Concrete_Metal_shader_0", name + "_Fence_Barbwire_shader_0"]


FENCE = {
	"sm_fence_straight": fence_parts("Fence_Straight"),
	"sm_wall_fence_straight": fence_parts("Wall_Straight"),
	"sm_wall_fence_short": fence_parts("Wall_Straight_Short"),
	"sm_wall_fence_corner": fence_parts("Wall_Corner_CW"),
	"sm_wall_fence_post": ["SinglePost_Wall_Concrete_Metal_shader_0"],
	"sm_fence_gate": fence_parts("Fence_Door_Straight"),
}


def export_pack(glb, specs, folder):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, glb))
	os.makedirs(os.path.join(OUT, folder), exist_ok=True)
	for prop, names in specs.items():
		bpy.ops.object.select_all(action="DESELECT")
		copies = []
		for n in names:
			src = bpy.data.objects[n]
			c = src.copy()
			c.data = src.data.copy()
			c.parent = None
			c.matrix_world = src.matrix_world
			bpy.context.scene.collection.objects.link(c)
			copies.append(c)
		pts = [c.matrix_world @ Vector(v) for c in copies for v in c.bound_box]
		lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
		hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
		shift = Vector((-(lo.x + hi.x) / 2.0, -(lo.y + hi.y) / 2.0, -lo.z))
		for c in copies:
			c.matrix_world = c.matrix_world.copy()
			c.location += shift
			c.select_set(True)
		bpy.context.view_layer.objects.active = copies[0]
		bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, folder, prop + ".glb"), export_format="GLB", use_selection=True, export_yup=True)
		print("PROP|%s|%.2f x %.2f x %.2f m (w, d, h)" % (prop, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z))
		for c in copies:
			bpy.data.objects.remove(c)


export_pack("city_props_collection_volume_1.glb", CITY, "city")
export_pack("chain_link_fence_pack_low_poly_game_ready.glb", FENCE, "fence")
