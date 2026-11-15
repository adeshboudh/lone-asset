extends GdUnitTestSuite
## The first-person arms wear the agent's camouflage sleeves, with skin and gloves kept on the hands.


func test_viewmodel_arms_have_a_sleeve_surface_with_triangles() -> void:
	var viewmodel: Node3D = auto_free((load("res://content/weapons/m4/m4_viewmodel.tscn") as PackedScene).instantiate())
	add_child(viewmodel)
	var hands: MeshInstance3D = viewmodel.find_child("Hand_Mesh", true, false) as MeshInstance3D
	var mesh: ArrayMesh = hands.mesh as ArrayMesh
	assert_int(mesh.get_surface_count()).is_equal(3)
	for surface: int in 3:
		var indices: PackedInt32Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
		assert_int(indices.size()).is_greater(0)
	assert_object(mesh.surface_get_material(2)).is_not_null()
	assert_bool((mesh.surface_get_material(2) as StandardMaterial3D).uv1_triplanar).is_true()


func test_sleeve_and_skin_split_covers_every_triangle_once() -> void:
	var viewmodel: Node3D = auto_free((load("res://content/weapons/m4/m4_viewmodel.tscn") as PackedScene).instantiate())
	add_child(viewmodel)
	var hands: MeshInstance3D = viewmodel.find_child("Hand_Mesh", true, false) as MeshInstance3D
	var source: Node = auto_free((load("res://content/weapons/m4/source/M4.fbx") as PackedScene).instantiate())
	var original: ArrayMesh = (source.find_child("Hand_Mesh", true, false) as MeshInstance3D).mesh as ArrayMesh
	var skin_and_sleeve: int = 0
	for surface: int in [0, 2]:
		skin_and_sleeve += (hands.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
	assert_int(skin_and_sleeve).is_equal((original.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size())
