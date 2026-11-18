class_name IdleSteadyModifier
extends SkeletonModifier3D
## Pulls a skeleton toward one stored pose by `influence` (the engine blends the modifier's output with the
## animation by that weight), so an idle animation's sway can be damped, down to perfectly still at 1.
## The viewmodel stores the idle clip's first frame (capture_first_frame) and raises the influence while aimed.

var _positions: Array[Vector3] = []
var _rotations: Array[Quaternion] = []
var _scales: Array[Vector3] = []


## Stores the skeleton's current pose as the one to hold.
func capture(skeleton: Skeleton3D) -> void:
	_positions.clear()
	_rotations.clear()
	_scales.clear()
	for bone: int in skeleton.get_bone_count():
		_positions.append(skeleton.get_bone_pose_position(bone))
		_rotations.append(skeleton.get_bone_pose_rotation(bone))
		_scales.append(skeleton.get_bone_pose_scale(bone))


## Stores the pose an animation has at its first frame: the skeleton's own pose for every bone the animation does
## not move, the keyed value at time 0 for the ones it does. skeleton_path is the skeleton's path as the
## animation's tracks write it (from the animation player's root node, e.g. "Arms_Rig/Skeleton3D").
func capture_first_frame(skeleton: Skeleton3D, animation: Animation, skeleton_path: String) -> void:
	capture(skeleton)
	for track: int in animation.get_track_count():
		var path: NodePath = animation.track_get_path(track)
		if str(path.get_concatenated_names()) != skeleton_path:
			continue
		var bone: int = skeleton.find_bone(path.get_concatenated_subnames())
		if bone < 0:
			continue
		match animation.track_get_type(track):
			Animation.TYPE_POSITION_3D:
				_positions[bone] = animation.position_track_interpolate(track, 0.0)
			Animation.TYPE_ROTATION_3D:
				_rotations[bone] = animation.rotation_track_interpolate(track, 0.0)
			Animation.TYPE_SCALE_3D:
				_scales[bone] = animation.scale_track_interpolate(track, 0.0)


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	for bone: int in mini(_positions.size(), skeleton.get_bone_count()):
		skeleton.set_bone_pose_position(bone, _positions[bone])
		skeleton.set_bone_pose_rotation(bone, _rotations[bone])
		skeleton.set_bone_pose_scale(bone, _scales[bone])
