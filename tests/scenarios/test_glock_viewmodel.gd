extends GdUnitTestSuite
## The Glock 17 viewmodel: the developer's arms and pistol on one rig, with its Idle and two reload clips.

const SUPPRESSED: WeaponDefinition = preload("res://data/weapons/glock_17_suppressed.tres")
const MUZZLE_BRAKE: WeaponDefinition = preload("res://data/weapons/glock_17.tres")

var _viewmodel: Node3D


func before_test() -> void:
	_viewmodel = auto_free(MUZZLE_BRAKE.viewmodel_scene.instantiate())
	add_child(_viewmodel)


func test_both_glock_files_use_this_viewmodel_and_aim_the_same_way() -> void:
	for definition: WeaponDefinition in [SUPPRESSED, MUZZLE_BRAKE]:
		assert_str(definition.viewmodel_scene.resource_path).contains("glock_17")
	assert_vector(SUPPRESSED.viewmodel_ads_position).is_equal(MUZZLE_BRAKE.viewmodel_ads_position)
	assert_vector(SUPPRESSED.viewmodel_hip_position).is_equal(MUZZLE_BRAKE.viewmodel_hip_position)


func test_the_variants_are_linked_and_the_suppressed_one_is_quieter() -> void:
	assert_object(MUZZLE_BRAKE.alt_variant).is_same(SUPPRESSED)
	assert_bool(SUPPRESSED.suppressed).is_true()
	assert_float(SUPPRESSED.noise_radius_m).is_less(MUZZLE_BRAKE.noise_radius_m)


func test_the_clips_the_glock_names_exist() -> void:
	var player: AnimationPlayer = _viewmodel.get("animation_player") as AnimationPlayer
	for clip: StringName in [MUZZLE_BRAKE.anim_idle, MUZZLE_BRAKE.anim_reload, MUZZLE_BRAKE.anim_reload_empty]:
		assert_bool(player.has_animation(clip)).override_failure_message("missing %s" % clip).is_true()


func test_the_clips_fit_the_reload_times() -> void:
	var player: AnimationPlayer = _viewmodel.get("animation_player") as AnimationPlayer
	assert_float(player.get_animation(MUZZLE_BRAKE.anim_reload).length).is_between(MUZZLE_BRAKE.reload_time - 0.2, MUZZLE_BRAKE.reload_time + 0.1)
	assert_float(player.get_animation(MUZZLE_BRAKE.anim_reload_empty).length).is_between(MUZZLE_BRAKE.reload_time_empty - 0.2, MUZZLE_BRAKE.reload_time_empty + 0.1)


func test_the_muzzle_is_at_the_front_of_the_slide_and_the_arms_are_drawn() -> void:
	var muzzle: Node3D = _viewmodel.get_node_or_null(^"Muzzle") as Node3D
	assert_object(muzzle).is_not_null()
	assert_float(muzzle.position.z).is_between(-0.2, -0.1)
	var arms: Node = _viewmodel.find_child("MS_Arms*", true, false)
	assert_object(arms).is_not_null()
	assert_bool(arms.is_in_group(&"first_person_arms")).is_true()


func test_the_sounds_the_glock_names_are_in_the_bank() -> void:
	var bank: SoundBank = preload("res://data/audio/sound_bank.tres")
	for definition: WeaponDefinition in [SUPPRESSED, MUZZLE_BRAKE]:
		for id: StringName in [definition.fire_sound, definition.reload_sound, definition.reload_empty_sound, definition.dry_fire_sound]:
			assert_bool(bank.sounds.has(id)).override_failure_message("no sound %s" % id).is_true()


func test_the_shots_have_muffled_copies_for_walls() -> void:
	var bank: SoundBank = preload("res://data/audio/sound_bank.tres")
	for definition: WeaponDefinition in [SUPPRESSED, MUZZLE_BRAKE]:
		assert_bool(bank.sounds.has(StringName(String(definition.fire_sound) + "_muffled"))).is_true()
