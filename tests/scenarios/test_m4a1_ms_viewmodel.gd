extends GdUnitTestSuite
## The rifle viewmodel: the developer's arms and rifle on one rig, with its Idle, Reload and Reload_Empty clips.

const RIFLE: WeaponDefinition = preload("res://data/weapons/rifle_suppressed.tres")
const MUZZLE_BRAKE: WeaponDefinition = preload("res://data/weapons/rifle_muzzle.tres")

var _viewmodel: Node3D


func before_test() -> void:
	_viewmodel = auto_free(RIFLE.viewmodel_scene.instantiate())
	add_child(_viewmodel)


func test_both_rifle_files_use_this_viewmodel() -> void:
	for definition: WeaponDefinition in [RIFLE, MUZZLE_BRAKE]:
		assert_str(definition.viewmodel_scene.resource_path).contains("m4a1_ms")


func test_both_rifle_files_aim_the_same_way() -> void:
	assert_vector(MUZZLE_BRAKE.viewmodel_ads_position).is_equal(RIFLE.viewmodel_ads_position)
	assert_vector(MUZZLE_BRAKE.viewmodel_hip_position).is_equal(RIFLE.viewmodel_hip_position)


func test_the_clips_the_rifle_names_exist_and_the_recoil_stays_procedural() -> void:
	var player: AnimationPlayer = _viewmodel.get("animation_player") as AnimationPlayer
	for clip: StringName in [RIFLE.anim_idle, RIFLE.anim_reload, RIFLE.anim_reload_empty]:
		assert_bool(player.has_animation(clip)).override_failure_message("missing %s" % clip).is_true()
	# With a fire clip named the procedural kick is switched off; the rig has none.
	assert_str(String(RIFLE.anim_fire)).is_empty()


func test_the_clips_fit_the_reload_times() -> void:
	var player: AnimationPlayer = _viewmodel.get("animation_player") as AnimationPlayer
	assert_float(player.get_animation(RIFLE.anim_reload).length).is_between(RIFLE.reload_time - 0.2, RIFLE.reload_time + 0.1)
	assert_float(player.get_animation(RIFLE.anim_reload_empty).length).is_between(RIFLE.reload_time_empty - 0.2, RIFLE.reload_time_empty + 0.1)


func test_the_muzzle_is_ahead_of_the_gun_and_its_own_arms_are_drawn() -> void:
	var muzzle: Node3D = _viewmodel.get_node_or_null(^"Muzzle") as Node3D
	assert_object(muzzle).is_not_null()
	assert_float(muzzle.position.z).is_less(-0.4)
	var arms: Node = _viewmodel.find_child("MS_Arms*", true, false)
	assert_object(arms).is_not_null()
	assert_bool(arms.is_in_group(&"first_person_arms")).is_true()
	assert_object(_viewmodel.find_child("FpsArms", true, false)).is_null()


func test_the_magazine_leaves_the_gun_and_comes_back_in_the_empty_reload() -> void:
	var player: AnimationPlayer = _viewmodel.get("animation_player") as AnimationPlayer
	var skeleton: Skeleton3D = _viewmodel.find_child("Skeleton3D", true, false) as Skeleton3D
	var bone: int = skeleton.find_bone("M4A1_Magazine")
	player.play(RIFLE.anim_reload_empty)
	player.seek(0.0, true)
	player.pause()
	await await_idle_frame()
	var start: Vector3 = skeleton.get_bone_global_pose(bone).origin
	player.seek(0.9, true)
	await await_idle_frame()
	assert_float(skeleton.get_bone_global_pose(bone).origin.distance_to(start)).is_greater(0.15)
	player.seek(player.get_animation(RIFLE.anim_reload_empty).length, true)
	await await_idle_frame()
	assert_float(skeleton.get_bone_global_pose(bone).origin.distance_to(start)).is_less(0.03)
