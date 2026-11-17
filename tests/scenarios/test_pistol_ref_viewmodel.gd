extends GdUnitTestSuite
## The pistol viewmodel built from the reference two-handed rig (test model, low-poly): two skeletons (arms, gun)
## animated together by one AnimationPlayer.

const PISTOL: WeaponDefinition = preload("res://data/weapons/pistol_muzzle.tres")
const SUPPRESSED: WeaponDefinition = preload("res://data/weapons/pistol_suppressed.tres")
const ARM_BONES: Array[StringName] = [&"upper_arm_L", &"lower_arm_L", &"hand_L", &"index_finger_03_L", &"upper_arm_R",
		&"lower_arm_R", &"hand_R", &"index_finger_03_R"]
const GUN_BONES: Array[StringName] = [&"gun_root", &"slide", &"mag"]

var _viewmodel: Node3D
var _arms: Skeleton3D
var _gun: Skeleton3D
var _player: AnimationPlayer


func before_test() -> void:
	_viewmodel = auto_free(PISTOL.viewmodel_scene.instantiate())
	add_child(_viewmodel)
	await await_idle_frame()
	_arms = _viewmodel.get_node("Model/Arms_Rig/Skeleton3D") as Skeleton3D
	_gun = _viewmodel.get_node("Model/Gun_Rig/Skeleton3D") as Skeleton3D
	_player = _viewmodel.find_child("AnimationPlayer", true, false) as AnimationPlayer


func test_both_pistol_variants_use_the_reference_model() -> void:
	assert_str(PISTOL.viewmodel_scene.resource_path).is_equal("res://content/weapons/pistol/ref/pistol_ref_viewmodel.tscn")
	assert_str(SUPPRESSED.viewmodel_scene.resource_path).is_equal(PISTOL.viewmodel_scene.resource_path)


func test_the_skeletons_have_the_arm_and_gun_bones() -> void:
	for bone: StringName in ARM_BONES:
		assert_int(_arms.find_bone(bone)).is_greater_equal(0)
	for bone: StringName in GUN_BONES:
		assert_int(_gun.find_bone(bone)).is_greater_equal(0)


func test_each_clip_the_definition_names_exists_and_animates_arms_and_gun() -> void:
	for animation: StringName in [PISTOL.anim_idle, PISTOL.anim_draw, PISTOL.anim_fire, PISTOL.anim_reload,
			PISTOL.anim_reload_empty]:
		assert_bool(_player.has_animation(animation)).is_true()
		var clip: Animation = _player.get_animation(animation)
		var arm_tracks: int = 0
		var gun_tracks: int = 0
		for track: int in clip.get_track_count():
			var path: String = str(clip.track_get_path(track))
			arm_tracks += 1 if path.begins_with("Arms_Rig/") else 0
			gun_tracks += 1 if path.begins_with("Gun_Rig/") else 0
		assert_int(arm_tracks).is_greater(0)
		assert_int(gun_tracks).is_greater(0)
	assert_int(_player.get_animation(PISTOL.anim_idle).loop_mode).is_equal(Animation.LOOP_LINEAR)


func test_the_muzzle_is_ahead_of_the_camera_and_rides_the_slide() -> void:
	var muzzle: Node3D = _viewmodel.get_node_or_null(^"Muzzle") as Node3D
	assert_object(muzzle).is_not_null()
	assert_float(_viewmodel.to_local(muzzle.global_position).z).is_less(-0.3)
	var before: Vector3 = muzzle.global_position
	_player.play(PISTOL.anim_fire)
	_player.seek(0.08, true)
	_player.pause()
	await await_idle_frame()
	await await_idle_frame()
	var slide: Vector3 = _gun.get_bone_global_pose(_gun.find_bone(&"slide")).origin
	var expected: Vector3 = _gun.global_transform * (slide + Vector3(0.0, 0.009, 0.122))
	assert_float(muzzle.global_position.distance_to(expected)).is_less(0.001)
	assert_float(muzzle.global_position.distance_to(before)).is_greater(0.0005)


func test_every_mesh_is_on_the_viewmodel_layer_and_the_arms_are_in_the_arms_group() -> void:
	var arms_meshes: int = 0
	for node: Node in _viewmodel.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		assert_int(mesh.layers).is_equal(FpsArms.LAYER)
		arms_meshes += 1 if mesh.is_in_group(&"first_person_arms") else 0
	assert_int(arms_meshes).is_equal(1)


func test_it_does_not_use_the_m4_arms() -> void:
	assert_object(_viewmodel.find_child("FpsArms", true, false)).is_null()


func test_aimed_the_muzzle_is_on_the_crosshair_line() -> void:
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	var viewmodel: Node3D = PISTOL.viewmodel_scene.instantiate()
	camera.add_child(viewmodel)
	viewmodel.position = PISTOL.viewmodel_ads_position
	# The weapon starts in Draw, which holds the idle pose; the bind pose has the gun on the centre line.
	var player: AnimationPlayer = viewmodel.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.play(PISTOL.anim_idle)
	player.seek(0.0, true)
	player.pause()
	await await_idle_frame()
	await await_idle_frame()
	var muzzle: Vector3 = (viewmodel.get_node("Muzzle") as Node3D).global_position
	# the front sight stands about 1.2 cm above the barrel
	assert_float(muzzle.x).is_between(-0.005, 0.005)
	assert_float(muzzle.y).is_between(-0.02, -0.005)
