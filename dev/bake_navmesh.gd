extends SceneTree
## Developer tool: bakes the navigation mesh of the movement course and saves it next to the scene.
## Run after changing the course's geometry (nodes in the "navigation_geometry" group):
##   godot --headless --path . -s res://dev/bake_navmesh.gd
## Excluded from game exports.

const SCENE_PATH: String = "res://game/levels/graybox/movement_course.tscn"
const OUTPUT_PATH: String = "res://game/levels/graybox/movement_course_navmesh.tres"
const GROUP: StringName = &"navigation_geometry"


func _initialize() -> void:
	var scene: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	# CSG shapes build their meshes on the next frames.
	for i: int in 5:
		await process_frame

	var navmesh: NavigationMesh = NavigationMesh.new()
	# Matches design §10: agent radius 0.4 m, height 1.8 m, max climb 0.35 m, max slope 40°.
	navmesh.agent_radius = 0.4
	navmesh.agent_height = 1.8
	navmesh.agent_max_climb = 0.35
	navmesh.agent_max_slope = 40.0
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.25
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navmesh.geometry_source_group_name = GROUP

	var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source, scene)
	if not source.has_data():
		push_error("No geometry found in group '%s'" % GROUP)
		quit(1)
		return
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)

	var error: Error = ResourceSaver.save(navmesh, OUTPUT_PATH)
	print("Baked %d polygons, %d vertices -> %s (%s)" % [navmesh.get_polygon_count(), navmesh.vertices.size(), OUTPUT_PATH, error_string(error)])
	quit(0 if error == OK and navmesh.get_polygon_count() > 0 else 1)
