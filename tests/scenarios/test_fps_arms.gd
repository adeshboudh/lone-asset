extends GdUnitTestSuite
## The first-person arms (FpsArms): a dedicated arms model on every weapon's arm rig, following its bones.

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")

var _player: Player


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(StaticBody3D.new())
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor_body)
	_player = auto_free(PLAYER_SCENE.instantiate())
	add_child(_player)
	for i: int in 5:
		await get_tree().physics_frame


func _arms(weapon: Weapon) -> FpsArms:
	return weapon.viewmodel.find_child("FpsArms", true, false) as FpsArms


func _rig(arms: FpsArms) -> Skeleton3D:
	return arms.get_parent() as Skeleton3D


func _new_bone(arms: FpsArms, prefix: String) -> int:
	for bone: int in arms.skeleton.get_bone_count():
		if arms.skeleton.get_bone_name(bone).begins_with(prefix):
			return bone
	return -1


func _wrist_gap(arms: FpsArms, side: String) -> float:
	var new_wrist: int = _new_bone(arms, ("L" if side == "Left" else "R") + "_wrist_")
	var rig: Skeleton3D = _rig(arms)
	var a: Vector3 = arms.skeleton.global_transform * arms.skeleton.get_bone_global_pose(new_wrist).origin
	var b: Vector3 = rig.global_transform * rig.get_bone_global_pose(rig.find_bone(side + "Hand")).origin
	return a.distance_to(b)


func test_every_weapon_has_the_arms_on_the_viewmodel_layer_without_shadows() -> void:
	for weapon: Weapon in _player._weapons:
		var arms: FpsArms = _arms(weapon)
		assert_object(arms).is_not_null()
		for node: Node in arms.find_children("*", "GeometryInstance3D", true, false):
			var mesh: GeometryInstance3D = node as GeometryInstance3D
			assert_int(mesh.layers).is_equal(FpsArms.LAYER)
			assert_int(mesh.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_the_right_wrist_sits_on_the_rig_and_the_left_on_the_rifles_handguard_hold() -> void:
	# At Idle (the weapon starts in its Draw clip, while the hand swings in).
	var anim: AnimationPlayer = _player.weapon.animation_player
	anim.play(_player.weapon.definition.anim_idle)
	anim.seek(0.0, true)
	var arms: FpsArms = _arms(_player.weapon)
	arms.pose_from_rig()
	assert_float(_wrist_gap(arms, "Right")).is_less(0.01)
	assert_object(_player.weapon.viewmodel.find_child("LeftHandHold", true, false)).is_not_null()
	var left: Vector3 = arms.skeleton.global_transform * arms.skeleton.get_bone_global_pose(_new_bone(arms, "L_wrist_")).origin
	assert_float(left.distance_to(_rig(arms).global_transform * arms.hold_in_rig().origin)).is_less(0.01)


func test_one_handed_weapons_fold_the_left_arm_away() -> void:
	for weapon: Weapon in _player._weapons:
		var arms: FpsArms = _arms(weapon)
		var rig: Skeleton3D = _rig(arms)
		var rig_left_folded: bool = rig.get_bone_pose_scale(rig.find_bone("LeftArm")).x < FpsArms.COLLAPSED_SCALE
		arms.pose_from_rig()
		var new_left: float = arms.skeleton.get_bone_pose_scale(_new_bone(arms, "L_arm_")).x
		assert_bool(new_left < FpsArms.COLLAPSED_SCALE).is_equal(rig_left_folded)
	# The rifle holds the handguard; the pistol and the knife are one-handed.
	assert_bool(_arms(_player._weapons[0]).skeleton.get_bone_pose_scale(_new_bone(_arms(_player._weapons[0]), "L_arm_")).x > 0.5).is_true()


func test_the_left_hand_follows_the_rig_through_the_reload() -> void:
	var weapon: Weapon = _player.weapon
	var player: AnimationPlayer = weapon.animation_player
	player.play(weapon.definition.anim_reload)
	var arms: FpsArms = _arms(weapon)
	var length: float = player.current_animation_length
	# Mid-reload the left hand is off the handguard (on the magazine), so it follows the rig, not the hold.
	for fraction: float in [0.35, 0.5]:
		player.seek(length * fraction, true)
		arms.pose_from_rig()
		assert_float(_wrist_gap(arms, "Left")).is_less(0.01)
		assert_float(_wrist_gap(arms, "Right")).is_less(0.01)


## The fingers close toward the palm, on the left hand as on the right: the middle fingertip is nearer the thumb
## side of the palm than the knuckle line when the rig grips.
func test_the_fingers_curl_like_the_rig_fingers() -> void:
	await get_tree().process_frame
	var arms: FpsArms = _arms(_player.weapon)
	var rig: Skeleton3D = _rig(arms)
	for side: String in ["Left", "Right"]:
		var p: String = "L_" if side == "Left" else "R_"
		var new_tip: Vector3 = _global(arms.skeleton, _new_bone(arms, p + "middle4_"))
		var new_knuckle: Vector3 = _global(arms.skeleton, _new_bone(arms, p + "middle1_"))
		var new_wrist: Vector3 = _global(arms.skeleton, _new_bone(arms, p + "wrist_"))
		var rig_tip: Vector3 = _global(rig, rig.find_bone(side + "HandMiddle4"))
		var rig_knuckle: Vector3 = _global(rig, rig.find_bone(side + "HandMiddle1"))
		var rig_wrist: Vector3 = _global(rig, rig.find_bone(side + "Hand"))
		# How far the fingertip bends back toward the wrist, compared with the rig: the same sign and similar size.
		var new_bend: float = (new_tip - new_knuckle).normalized().dot((new_knuckle - new_wrist).normalized())
		var rig_bend: float = (rig_tip - rig_knuckle).normalized().dot((rig_knuckle - rig_wrist).normalized())
		assert_float(new_bend).is_equal_approx(rig_bend, 0.35)


func _global(skeleton: Skeleton3D, bone: int) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
