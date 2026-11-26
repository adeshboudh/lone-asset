extends SceneTree
## Builds one StaticBody3D scene per prop glb in content/environment/props/{city,fence}:
## the model, a collision shape from its bounds (convex hull for round props) and the impact surface.
## Run: godot --headless --path . -s tools/props/build_prop_scenes.gd

const ROOT: String = "res://content/environment/props/"
const CONVEX: Array[String] = ["sm_trash_can_large", "sm_trash_can_small", "sm_trash_can_cap", "sm_trash_commercial", "sm_fire_hydrant"]
const SURFACES: Dictionary = {
	"sm_crate_tarp_1": &"wood", "sm_crate_tarp_2": &"wood", "sm_crate_tarp_3": &"wood", "sm_crate_tarp_4": &"wood",
	"sm_pallet": &"wood", "sm_park_bench_short": &"wood",
	"sm_concrete_bench": &"concrete", "sm_post_barrier": &"concrete",
}


func _init() -> void:
	for folder: String in ["city", "fence"]:
		var dir: DirAccess = DirAccess.open(ROOT + folder)
		for file: String in dir.get_files():
			if file.ends_with(".glb"):
				_build(folder, file.get_basename())
	quit()


func _build(folder: String, prop: String) -> void:
	var model: Node3D = (load("%s%s/%s.glb" % [ROOT, folder, prop]) as PackedScene).instantiate()
	model.name = "Model"
	var body: StaticBody3D = StaticBody3D.new()
	body.name = prop.trim_prefix("sm_").to_pascal_case()
	body.set_meta("surface", SURFACES.get(prop, &"metal"))
	body.add_child(model)
	var meshes: Array[MeshInstance3D] = []
	_collect(model, meshes)
	var box: AABB
	var first: bool = true
	for m: MeshInstance3D in meshes:
		var b: AABB = _relative(m, model) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "Shape"
	if CONVEX.has(prop):
		var points: PackedVector3Array = PackedVector3Array()
		for m: MeshInstance3D in meshes:
			points.append_array(_relative(m, model) * m.mesh.create_convex_shape(true, true).points)
		var hull: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		hull.points = points
		shape.shape = hull
	else:
		var s: BoxShape3D = BoxShape3D.new()
		s.size = box.size
		shape.shape = s
		shape.position = box.get_center()
	body.add_child(shape)
	model.owner = body
	shape.owner = body
	var packed: PackedScene = PackedScene.new()
	packed.pack(body)
	ResourceSaver.save(packed, "%s%s/%s.tscn" % [ROOT, folder, prop])
	print("built ", prop)


func _collect(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c: Node in n.get_children():
		_collect(c, out)


## The transform of a node inside the model, without needing the model to be in the tree.
func _relative(n: Node3D, model: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != model and cur is Node3D:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
