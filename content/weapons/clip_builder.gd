class_name ClipBuilder
extends RefCounted
## Builds an AnimationPlayer of hand-keyed clips that move one node (the pivot holding the arm and the
## weapon) for static first-person models. Keys are [time, offset from the rest position (m), euler
## degrees (x pitch up, y yaw left, z roll)]; offsets and angles are about the pivot.


## clips: {name: {"length": float, "loop": bool (optional), "keys": Array of [t, Vector3, Vector3]}}.
static func add_player(parent: Node3D, target: NodePath, rest: Vector3, clips: Dictionary) -> AnimationPlayer:
	var player: AnimationPlayer = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	var library: AnimationLibrary = AnimationLibrary.new()
	for clip_name: StringName in clips:
		var spec: Dictionary = clips[clip_name]
		var animation: Animation = Animation.new()
		animation.length = float(spec["length"])
		animation.loop_mode = Animation.LOOP_LINEAR if spec.get("loop", false) else Animation.LOOP_NONE
		var position_track: int = animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(position_track, target)
		var rotation_track: int = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(rotation_track, target)
		for key: Array in spec["keys"]:
			var degrees: Vector3 = key[2]
			animation.position_track_insert_key(position_track, float(key[0]), rest + (key[1] as Vector3))
			animation.rotation_track_insert_key(rotation_track, float(key[0]),
				Quaternion.from_euler(Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))))
		animation.track_set_interpolation_type(position_track, Animation.INTERPOLATION_CUBIC)
		animation.track_set_interpolation_type(rotation_track, Animation.INTERPOLATION_CUBIC)
		library.add_animation(clip_name, animation)
	player.add_animation_library(&"", library)
	parent.add_child(player)
	return player
