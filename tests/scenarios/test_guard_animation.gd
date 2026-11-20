extends GdUnitTestSuite
## The guard wears the MCO-rigged agent and plays the clip that fits its state and speed.

const GUARD_SCENE: PackedScene = preload("res://game/ai/guard/guard.tscn")

var _guard: Guard
var _animator: GuardAnimator


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(StaticBody3D.new())
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(50.0, 1.0, 50.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor_body)
	_guard = auto_free(GUARD_SCENE.instantiate()) as Guard
	add_child(_guard)
	_animator = _guard.get_node("GuardAnimator") as GuardAnimator
	await await_idle_frame()


func test_guard_model_is_the_rigged_agent_with_a_rifle_on_the_hand() -> void:
	var skeleton: Skeleton3D = _guard.get_node("Model/Agent/Armature/Skeleton3D")
	assert_int(skeleton.find_bone("hand_r_wep")).is_greater_equal(0)
	var rifle: Node3D = _guard.get_node("Model/RightHandWeapon/Rifle")
	assert_bool(rifle.is_inside_tree()).is_true()


func test_standing_guard_plays_the_relaxed_idle() -> void:
	await await_millis(300)
	assert_str(String(_animator.current_clip())).is_equal(String(_animator.profile.relaxed_idle))


func test_clip_changes_with_speed() -> void:
	var player: AnimationPlayer = _guard.get_node("Model/Agent/AnimationPlayer")
	_animator.set_physics_process(false)
	_guard.velocity = Vector3(1.5, 0.0, 0.0)
	_animator._physics_process(0.016)
	assert_str(String(_animator.current_clip())).is_equal(String(_animator.profile.relaxed_walk))
	assert_str(String(player.assigned_animation)).is_equal(String(_animator.profile.relaxed_walk))
	_guard.velocity = Vector3(4.5, 0.0, 0.0)
	_animator._physics_process(0.016)
	assert_str(String(_animator.current_clip())).is_equal(String(_animator.profile.relaxed_jog))


func test_every_profile_clip_exists_in_the_model() -> void:
	var player: AnimationPlayer = _guard.get_node("Model/Agent/AnimationPlayer")
	var p: GuardAnimationProfile = _animator.profile
	for clip_name: StringName in [p.relaxed_idle, p.relaxed_walk, p.relaxed_jog, p.aim_idle, p.aim_walk, p.aim_jog]:
		assert_bool(player.has_animation(clip_name)).override_failure_message("missing clip %s" % clip_name).is_true()
