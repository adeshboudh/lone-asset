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
