extends GdUnitTestSuite
## The pistol viewmodel: its own two-handed arms rig (pistol_viewmodel.glb), not the M4 pack's arms.

const PISTOL: WeaponDefinition = preload("res://data/weapons/pistol_muzzle.tres")
const GUN_BONES: Array[StringName] = [&"gun_root", &"gun_slide", &"gun_mag", &"gun_mag_spare", &"gun_trigger",
		&"gun_hammer", &"gun_muzzle"]
const ARM_BONES: Array[StringName] = [&"L_arm_01", &"L_wrist_03", &"L_middle4_014", &"R_arm_023", &"R_wrist_025",
		&"R_middle4_037"]

var _viewmodel: Node3D
var _skeleton: Skeleton3D
var _player: AnimationPlayer


func before_test() -> void:
	_viewmodel = auto_free(PISTOL.viewmodel_scene.instantiate())
	add_child(_viewmodel)
	await await_idle_frame()
	_skeleton = _viewmodel.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = _viewmodel.find_child("AnimationPlayer", true, false) as AnimationPlayer


func test_the_skeleton_has_the_arm_and_gun_bones_and_no_control_bones() -> void:
	for bone: StringName in GUN_BONES + ARM_BONES:
		assert_int(_skeleton.find_bone(bone)).is_greater_equal(0)
	for bone: StringName in [&"ctl_gun", &"ctl_hand_L", &"ctl_hand_R", &"pole_elbow_L", &"pole_elbow_R"]:
		assert_int(_skeleton.find_bone(bone)).is_equal(-1)


func test_it_does_not_use_the_m4_arms() -> void:
	assert_object(_viewmodel.find_child("FpsArms", true, false)).is_null()
	assert_int(_skeleton.find_bone(&"RightHand")).is_equal(-1)


func test_the_clips_the_definition_names_exist_and_idle_loops() -> void:
	for animation: StringName in [PISTOL.anim_idle, PISTOL.anim_draw, PISTOL.anim_fire, PISTOL.anim_reload,
			PISTOL.anim_reload_empty]:
		assert_bool(_player.has_animation(animation)).is_true()
	assert_int(_player.get_animation(PISTOL.anim_idle).loop_mode).is_equal(Animation.LOOP_LINEAR)
	assert_float(_player.get_animation(PISTOL.anim_reload).length).is_equal_approx(PISTOL.reload_time, 0.05)
	assert_float(_player.get_animation(PISTOL.anim_reload_empty).length).is_equal_approx(PISTOL.reload_time_empty, 0.05)


func test_the_muzzle_is_ahead_of_the_camera_and_follows_the_muzzle_bone() -> void:
	var muzzle: Node3D = _viewmodel.get_node_or_null(^"Muzzle") as Node3D
	assert_object(muzzle).is_not_null()
	assert_float(_viewmodel.to_local(muzzle.global_position).z).is_less(-0.3)
	_player.play(PISTOL.anim_fire)
	_player.seek(0.03, true)
	_player.pause()
	await await_idle_frame()
	await await_idle_frame()
	var bone: Vector3 = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone(&"gun_muzzle"))).origin
	assert_float(muzzle.global_position.distance_to(bone)).is_less(0.001)


func test_every_mesh_is_on_the_viewmodel_layer_with_the_textures_on() -> void:
	for node: Node in _viewmodel.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		assert_int(mesh.layers).is_equal(FpsArms.LAYER)
		assert_object(mesh.get_surface_override_material(0)).is_not_null()


func test_the_spare_magazine_is_hidden_until_the_reload_brings_it() -> void:
	var spare: int = _skeleton.find_bone(&"gun_mag_spare")
	_player.play(PISTOL.anim_idle)
	_player.seek(0.0, true)
	_player.pause()
	assert_float(_skeleton.get_bone_pose_scale(spare).x).is_less(0.01)
	_player.play(PISTOL.anim_reload)
	_player.seek(0.7, true)
	_player.pause()
	assert_float(_skeleton.get_bone_pose_scale(spare).x).is_greater(0.9)
	_player.seek(PISTOL.reload_time, true)
	assert_float(_skeleton.get_bone_pose_scale(spare).x).is_less(0.01)


func test_aimed_the_muzzle_is_on_the_crosshair_line() -> void:
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	var viewmodel: Node3D = PISTOL.viewmodel_scene.instantiate()
	camera.add_child(viewmodel)
	viewmodel.position = PISTOL.viewmodel_ads_position
	await await_idle_frame()
	await await_idle_frame()
	var muzzle: Vector3 = (viewmodel.get_node("Muzzle") as Node3D).global_position
	# the front sight stands about 1.2 cm above the barrel
	assert_float(muzzle.x).is_between(-0.005, 0.005)
	assert_float(muzzle.y).is_between(-0.02, -0.005)
