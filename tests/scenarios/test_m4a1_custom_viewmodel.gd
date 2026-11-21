extends GdUnitTestSuite
## The M4A1 Custom viewmodel: the model's parts hang on the rig's bones, each named for the gun.

const RIFLE: WeaponDefinition = preload("res://data/weapons/rifle_suppressed.tres")
const PARTS: Array[StringName] = [&"m4a1_custom_body", &"m4a1_custom_iron_sights",
		&"m4a1_custom_optic", &"m4a1_custom_optic_lens", &"m4a1_custom_suppressor", &"m4a1_custom_muzzle_brake",
		&"m4a1_custom_magazine"]

var _viewmodel: Node3D


func before_test() -> void:
	_viewmodel = auto_free((load("res://content/weapons/m4a1_custom/m4a1_custom_viewmodel.tscn") as PackedScene).instantiate())
	add_child(_viewmodel)


func test_every_part_is_in_the_viewmodel_and_named_for_the_gun() -> void:
	for part_name: StringName in PARTS:
		assert_object(_viewmodel.find_child(String(part_name), true, false)).override_failure_message("missing %s" % part_name).is_not_null()


func test_the_rifle_definition_uses_it_and_is_named_for_the_gun() -> void:
	assert_str(RIFLE.viewmodel_scene.resource_path).contains("m4a1_custom")
	assert_str(RIFLE.display_name).contains("M4A1 Custom")


func test_old_rifle_parts_are_not_drawn() -> void:
	var skeleton: Skeleton3D = _viewmodel.find_child("Skeleton3D", true, false) as Skeleton3D
	for child: Node in skeleton.get_children():
		if child is BoneAttachment3D and not String(child.name).begins_with("M4A1Custom"):
			assert_bool((child as Node3D).visible).is_false()


func test_suppressor_and_muzzle_brake_swap() -> void:
	var suppressor: Node3D = _viewmodel.find_child("m4a1_custom_suppressor", true, false) as Node3D
	var brake: Node3D = _viewmodel.find_child("m4a1_custom_muzzle_brake", true, false) as Node3D
	assert_bool(suppressor.visible).is_true()
	assert_bool(brake.visible).is_false()
	_viewmodel.call(&"show_suppressor", false)
	assert_bool(suppressor.visible).is_false()
	assert_bool(brake.visible).is_true()


func test_the_muzzle_node_and_animations_exist() -> void:
	assert_object(_viewmodel.get_node_or_null(^"Muzzle")).is_not_null()
	var player: AnimationPlayer = _viewmodel.get("animation_player") as AnimationPlayer
	for animation: StringName in [RIFLE.anim_idle, RIFLE.anim_draw, RIFLE.anim_fire, RIFLE.anim_reload, RIFLE.anim_reload_empty]:
		assert_bool(player.has_animation(animation)).is_true()


func test_the_spare_magazine_follows_its_bone_in_the_reload() -> void:
	await await_idle_frame()
	var magazines: Array[Node] = _viewmodel.find_children("m4a1_custom_magazine*", "MeshInstance3D", true, false)
	assert_int(magazines.size()).is_equal(2)
	var player: AnimationPlayer = _viewmodel.get("animation_player") as AnimationPlayer
	var before: Array[Vector3] = [(magazines[0] as Node3D).global_position, (magazines[1] as Node3D).global_position]
	player.play(RIFLE.anim_reload)
	player.seek(1.2, true)
	player.pause()
	await await_idle_frame()
	await await_idle_frame()
	var moved: float = 0.0
	for index: int in 2:
		moved = maxf(moved, (magazines[index] as Node3D).global_position.distance_to(before[index]))
	assert_float(moved).is_greater(0.05)


func test_the_lens_is_scope_glass() -> void:
	var lens: MeshInstance3D = _viewmodel.find_child("m4a1_custom_optic_lens", true, false) as MeshInstance3D
	assert_object(lens.material_override).is_instanceof(ShaderMaterial)


func test_no_scope_camera_until_aimed_with_a_zoom() -> void:
	_viewmodel.call(&"set_aim", 0.2, 3.0)
	assert_object(_viewmodel.get_node_or_null(^"ScopeViewport")).is_null()
	_viewmodel.call(&"set_aim", 1.0, 1.0)
	assert_object(_viewmodel.get_node_or_null(^"ScopeViewport")).is_null()
	_viewmodel.call(&"set_aim", 1.0, 3.0)
	assert_object(_viewmodel.get_node_or_null(^"ScopeViewport")).is_not_null()


func test_the_scope_renders_only_while_aimed() -> void:
	_viewmodel.call(&"set_aim", 1.0, 3.0)
	var viewport: SubViewport = _viewmodel.get_node(^"ScopeViewport") as SubViewport
	assert_int(viewport.render_target_update_mode).is_equal(SubViewport.UPDATE_ALWAYS)
	_viewmodel.call(&"set_aim", 0.1, 3.0)
	assert_int(viewport.render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)


func test_the_rifle_has_a_scope_zoom() -> void:
	assert_float(RIFLE.scope_zoom).is_greater(1.0)


func test_the_gun_is_on_its_own_layer_so_the_scope_camera_can_skip_it() -> void:
	var body: MeshInstance3D = _viewmodel.find_child("m4a1_custom_body", true, false) as MeshInstance3D
	assert_int(body.layers).is_equal(1 << 18)


func test_aimed_the_lens_centre_is_on_the_crosshair_line() -> void:
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	var viewmodel: Node3D = (load("res://content/weapons/m4a1_custom/m4a1_custom_viewmodel.tscn") as PackedScene).instantiate()
	camera.add_child(viewmodel)
	viewmodel.position = RIFLE.viewmodel_ads_position
	await await_idle_frame()
	await await_idle_frame()
	var lens: MeshInstance3D = viewmodel.find_child("m4a1_custom_optic_lens", true, false) as MeshInstance3D
	var centre: Vector3 = lens.global_transform * lens.get_aabb().get_center()
	assert_float(centre.x).is_between(-0.002, 0.002)
	assert_float(centre.y).is_between(-0.002, 0.002)


func test_the_muzzle_brake_variant_aims_the_same_way() -> void:
	var muzzle: WeaponDefinition = load("res://data/weapons/rifle_muzzle.tres")
	assert_vector(muzzle.viewmodel_ads_position).is_equal(RIFLE.viewmodel_ads_position)


func test_the_vertical_foregrip_is_left_off_and_the_left_hand_has_a_hold_on_the_handguard() -> void:
	assert_object(_viewmodel.find_child("m4a1_custom_foregrip", true, false)).is_null()
	var hold: Node3D = _viewmodel.find_child("LeftHandHold", true, false) as Node3D
	assert_object(hold).is_not_null()
	# It rides the gun (Main bone), so it follows the gun through every animation.
	assert_str(String(hold.get_parent().name)).is_equal("M4A1CustomBody")


func test_reload_empty_is_the_retargeted_clip_and_moves_the_magazine_out_and_back() -> void:
	await await_idle_frame()
	var player: AnimationPlayer = _viewmodel.get("animation_player") as AnimationPlayer
	var clip: Animation = player.get_animation(RIFLE.anim_reload_empty)
	assert_str(clip.resource_path).contains("reload_empty.tres")
	assert_float(clip.length).is_between(RIFLE.reload_time_empty - 0.2, RIFLE.reload_time_empty + 0.1)
	var magazines: Array[Node] = _viewmodel.find_children("m4a1_custom_magazine*", "MeshInstance3D", true, false)
	var mag: Node3D = magazines[0] as Node3D
	player.play(RIFLE.anim_reload_empty)
	player.seek(0.0, true)
	player.pause()
	await await_idle_frame()
	var start: Vector3 = mag.global_position
	player.seek(1.0, true)
	await await_idle_frame()
	assert_float(mag.global_position.distance_to(start)).is_greater(0.15)
	player.seek(clip.length, true)
	await await_idle_frame()
	assert_float(mag.global_position.distance_to(start)).is_less(0.03)


func test_tactical_reload_is_the_retargeted_clip() -> void:
	var player: AnimationPlayer = _viewmodel.get("animation_player") as AnimationPlayer
	var clip: Animation = player.get_animation(RIFLE.anim_reload)
	assert_str(clip.resource_path).contains("reload_tactical.tres")
	assert_float(clip.length).is_between(RIFLE.reload_time - 0.2, RIFLE.reload_time + 0.1)
