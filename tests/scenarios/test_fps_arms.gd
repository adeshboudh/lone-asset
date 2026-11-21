extends GdUnitTestSuite
## The first-person arms (FpsArms): a dedicated arms model on every weapon's arm rig, following its bones.

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")

const RIFLE_ON_PACK_RIG: PackedScene = preload("res://content/weapons/m4a1_custom/m4a1_custom_viewmodel.tscn")

var _player: Player
var _rifle: WeaponDefinition = load("res://data/weapons/rifle_muzzle.tres")
var _rifle_scene: PackedScene


func after_test() -> void:
	_rifle.viewmodel_scene = _rifle_scene


func before_test() -> void:
	# The rifle files use the developer's own rig, which has its own arms; these tests are about the arms that
	# follow the M4 pack rig (the knife still uses it, the M4A1 Custom is the fallback rifle), so put that
	# rifle model on the rifle for the test and back afterwards.
	_rifle_scene = _rifle.viewmodel_scene
	_rifle.viewmodel_scene = RIFLE_ON_PACK_RIG
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


## A weapon with its own arms rig (the pistol, the rifle) animates its arms directly and gets no FpsArms.
func _has_own_rig(weapon: Weapon) -> bool:
	for node: Node in weapon.viewmodel.find_children("*", "Skeleton3D", true, false):
		if (node as Skeleton3D).find_bone(&"gun_root") >= 0 or (node as Skeleton3D).find_bone(&"Wrist_R") >= 0:
			return true
	return false


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
		if _has_own_rig(weapon):
			continue
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
		if _has_own_rig(weapon):
			continue
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


## The right hand's fingers bend as much as the rig's fingers (it holds the pistol grip as the rig does).
func test_the_right_fingers_curl_like_the_rig_fingers() -> void:
	var arms: FpsArms = _idle_arms()
	var rig: Skeleton3D = _rig(arms)
	var new_tip: Vector3 = _global(arms.skeleton, _new_bone(arms, "R_middle4_"))
	var new_knuckle: Vector3 = _global(arms.skeleton, _new_bone(arms, "R_middle1_"))
	var new_wrist: Vector3 = _global(arms.skeleton, _new_bone(arms, "R_wrist_"))
	var rig_tip: Vector3 = _global(rig, rig.find_bone("RightHandMiddle4"))
	var rig_knuckle: Vector3 = _global(rig, rig.find_bone("RightHandMiddle1"))
	var rig_wrist: Vector3 = _global(rig, rig.find_bone("RightHand"))
	var new_bend: float = (new_tip - new_knuckle).normalized().dot((new_knuckle - new_wrist).normalized())
	var rig_bend: float = (rig_tip - rig_knuckle).normalized().dot((rig_knuckle - rig_wrist).normalized())
	assert_float(new_bend).is_equal_approx(rig_bend, 0.35)


## On the handguard the left fingers curl toward the barrel, not away from it (they once bent backwards).
func test_the_left_fingers_curl_around_the_handguard() -> void:
	var arms: FpsArms = _idle_arms()
	var muzzle: Node3D = _player.weapon.viewmodel.get_node("Muzzle") as Node3D
	var barrel: Vector3 = -_player.weapon.viewmodel.global_basis.z.normalized()
	for finger: String in ["L_point", "L_middle", "L_ring"]:
		var knuckle: Vector3 = _global(arms.skeleton, _new_bone(arms, finger + "1_"))
		var tip: Vector3 = _global(arms.skeleton, _new_bone(arms, finger + "4_"))
		var on_axis: Vector3 = muzzle.global_position + barrel * barrel.dot(knuckle - muzzle.global_position)
		var to_axis: Vector3 = (on_axis - knuckle)
		var curl: Vector3 = tip - knuckle
		assert_float(curl.normalized().dot(to_axis.normalized())).is_greater(0.3)


func _idle_arms() -> FpsArms:
	var anim: AnimationPlayer = _player.weapon.animation_player
	anim.play(_player.weapon.definition.anim_idle)
	anim.seek(0.0, true)
	var arms: FpsArms = _arms(_player.weapon)
	arms.pose_from_rig()
	return arms


func _global(skeleton: Skeleton3D, bone: int) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
