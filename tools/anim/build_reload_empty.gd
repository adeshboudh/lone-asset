# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
extends SceneTree
## Retargets the hand-made reload (content/weapons/m4a1_custom/reload_empty_motion.json, written by
## tools/blender/reload_motion_export.py) onto the M4 pack rig and saves it as Reload_Empty.
## Run: godot --headless --path . -s tools/anim/build_reload_empty.gd [-- tactical]
## (no argument: the empty reload; "tactical": reload_tactical_motion.json to reload_tactical.tres)
## The pack's Idle pose is the base: the clip adds the motion of the gun, the magazine, both wrists and the fingers
## to it, so the hands keep the grip the gloves were set up for.

var MOTION := "res://content/weapons/m4a1_custom/reload_empty_motion.json"
var OUT := "res://content/weapons/m4a1_custom/reload_empty.tres"
## The new rifle is about 0.8 times the length of the one the motion was made on.
const GUN_SCALE: float = 0.8
## Blender armature axes (forward -Y, up +Z, right -X) to the view's (forward -Z, up +Y, right +X).
const AXES := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
## How near the left wrist is to the magazine bone (hand-made rig, metres) when it holds it; at the start it is 0.12.
const GRASP_M: float = 0.1
## Centre of the magazine in its bone's own frame: on the hand-made rig (Blender axes, measured from the mesh) and
## on the M4A1 Custom (its Mag1_j bone at Idle).
const MAG_CENTER_U := Vector3(0.0003, 0.0591, -0.0041)
const MAG_CENTER_P := Vector3(-0.0031, 0.0198, 0.0031)
const FINGERS: Array[String] = ["Thumb", "Index", "Middle", "Ring", "Pinky"]

var _skel: Skeleton3D
var _cam: Transform3D  # the view in skeleton space
var _idle_local: Dictionary = {}  # bone name -> [position, rotation] at Idle


func _process(_delta: float) -> bool:
	_build()
	return true


func _build() -> void:
	if "tactical" in OS.get_cmdline_user_args():
		MOTION = MOTION.replace("empty", "tactical")
		OUT = OUT.replace("empty", "tactical")
	var rig: Node = (load("res://content/weapons/m4/source/M4.fbx") as PackedScene).instantiate()
	root.add_child(rig)
	var ap: AnimationPlayer = rig.get_node("AnimationPlayer")
	ap.play(&"Idle")
	ap.seek(0.0, true)
	_skel = rig.get_node("Skeleton3D") as Skeleton3D
	_skel.force_update_all_bone_transforms()
	_cam = _skel.global_transform.affine_inverse() * (_skel.get_node("FPS_Camera/FPS_Camera") as Node3D).global_transform
	for i: int in _skel.get_bone_count():
		_idle_local[_skel.get_bone_name(i)] = [_skel.get_bone_pose_position(i), _skel.get_bone_pose_rotation(i)]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MOTION))
	var frames: Array = data["frames"]
	var fps: float = data["fps"]
	var anim := Animation.new()
	anim.length = (frames.size() - 1) / fps
	anim.step = 1.0 / fps
	var tracks: Dictionary = {}  # bone name -> [positions, rotations] per frame
	for f: int in frames.size():
		var pose: Dictionary = _pose_frame(frames, f)
		for bone_name: String in pose:
			if not tracks.has(bone_name):
				tracks[bone_name] = [[], []]
			tracks[bone_name][0].append(pose[bone_name][0])
			tracks[bone_name][1].append(pose[bone_name][1])
	for bone_name: String in tracks:
		var pt: int = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(pt, NodePath("Skeleton3D:" + bone_name))
		var rt: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(rt, NodePath("Skeleton3D:" + bone_name))
		for f: int in frames.size():
			anim.position_track_insert_key(pt, f / fps, tracks[bone_name][0][f])
			anim.rotation_track_insert_key(rt, f / fps, tracks[bone_name][1][f])
	var err: int = ResourceSaver.save(anim, OUT)
	print("SAVED ", OUT, " err ", err, " tracks ", anim.get_track_count(), " length ", anim.length)
	quit()


func _to_view(m: Array) -> Transform3D:
	var r := Basis(Vector3(m[0], m[4], m[8]), Vector3(m[1], m[5], m[9]), Vector3(m[2], m[6], m[10]))
	return Transform3D(AXES * r * AXES.transposed(), AXES * Vector3(m[3], m[7], m[11]))


## Pose of every animated bone at one frame: bone name -> [local position, local rotation].
func _pose_frame(frames: Array, f: int) -> Dictionary:
	var out: Dictionary = {}
	var rec: Dictionary = frames[f]
	var rec0: Dictionary = frames[0]
	# gun motion about the Body bone's own origin, in view axes
	var gun_u0: Transform3D = _to_view(rec0["gun"])
	var gun_u: Transform3D = _to_view(rec["gun"])
	var pivot_u := Transform3D(Basis.IDENTITY, gun_u0.origin)
	var delta: Transform3D = pivot_u.affine_inverse() * gun_u * gun_u0.affine_inverse() * pivot_u
	var main: int = _skel.find_bone("Main_j")
	var main_idle: Transform3D = _view_pose(main)
	var pivot_p := Transform3D(Basis.IDENTITY, main_idle.origin)
	var move: Transform3D = pivot_p * delta * pivot_p.affine_inverse()
	var main_new: Transform3D = move * main_idle
	out["Main_j"] = _local(main, _cam * main_new)
	# the rest follow the gun: offset in the gun-moved frame, scaled to the new rifle
	var moved_u: Transform3D = pivot_u * delta * pivot_u.affine_inverse()
	var parts: Dictionary = {"mag": "Mag1_j", "Wrist_R": "RightHand", "Wrist_L": "LeftHand"}
	var targets: Dictionary = {}
	for key: String in parts:
		var p_u: Transform3D = moved_u.affine_inverse() * _to_view(rec[key])
		var p_u0: Transform3D = _to_view(rec0[key])
		var idle: Transform3D = _view_pose(_skel.find_bone(parts[key]))
		var basis: Basis = (p_u.basis * p_u0.basis.inverse()) * idle.basis
		var pos: Vector3 = idle.origin + GUN_SCALE * (p_u.origin - p_u0.origin)
		targets[key] = move * Transform3D(basis, pos)
	# While the left hand holds the magazine (it is near it on the hand-made rig) it keeps the same place on it,
	# because the pack's hand rests on the handguard, not under the magazine well.
	var mag_u: Transform3D = _to_view(rec["mag"])
	var mag_u0: Transform3D = _to_view(rec0["mag"])
	var hand_u: Transform3D = _to_view(rec["Wrist_L"])
	var hand_u0: Transform3D = _to_view(rec0["Wrist_L"])
	var center_u: Vector3 = mag_u * (AXES * MAG_CENTER_U)
	var near0: float = (hand_u0.origin - mag_u0.origin).length()
	var hold: float = clampf((near0 - (hand_u.origin - mag_u.origin).length()) / (near0 - GRASP_M), 0.0, 1.0)
	hold = hold * hold * (3.0 - 2.0 * hold)
	var mag_turn: Basis = mag_u.basis * mag_u0.basis.inverse()
	var center_p: Vector3 = (targets["mag"] as Transform3D) * MAG_CENTER_P
	var on_mag: Vector3 = center_p + (move.basis * mag_turn) * (GUN_SCALE * (mag_turn.inverse() * (hand_u.origin - center_u)))
	var left: Transform3D = targets["Wrist_L"]
	left.origin = left.origin.lerp(on_mag, hold)
	targets["Wrist_L"] = left
	out["Mag1_j"] = _local(_skel.find_bone("Mag1_j"), _cam * (targets["mag"] as Transform3D))
	_solve_arm(out, "Right", _cam * (targets["Wrist_R"] as Transform3D))
	_solve_arm(out, "Left", _cam * (targets["Wrist_L"] as Transform3D))
	_fingers(out, rec["fingers"], frames[0]["fingers"])
	return out


## Pose of a bone in the view at Idle.
func _view_pose(bone: int) -> Transform3D:
	return _cam.affine_inverse() * _skel.get_bone_global_pose(bone)


## Local pose of a bone whose parent is unmoved (Main_j, Mag1_j): the parent's Idle pose.
func _local(bone: int, global: Transform3D) -> Array:
	var parent: Transform3D = _skel.get_bone_global_pose(_skel.get_bone_parent(bone))
	var local: Transform3D = parent.affine_inverse() * global
	return [local.origin, local.basis.get_rotation_quaternion()]


## Two-bone solve of shoulder, elbow and wrist onto a wrist target (skeleton space), the elbow staying on the
## side it has at Idle. Adds the three bones' poses to out.
func _solve_arm(out: Dictionary, side: String, wrist: Transform3D) -> void:
	var b_up: int = _skel.find_bone(side + "Arm")
	var b_fore: int = _skel.find_bone(side + "ForeArm")
	var b_hand: int = _skel.find_bone(side + "Hand")
	var up0: Transform3D = _skel.get_bone_global_pose(b_up)
	var fore0: Transform3D = _skel.get_bone_global_pose(b_fore)
	var hand0: Transform3D = _skel.get_bone_global_pose(b_hand)
	var s: Vector3 = up0.origin
	var l1: float = (fore0.origin - s).length()
	var l2: float = (hand0.origin - fore0.origin).length()
	var to_target: Vector3 = wrist.origin - s
	var d: float = clampf(to_target.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	if to_target.length() > l1 + l2:
		print("OUT OF REACH ", side, " ", snappedf(to_target.length(), 0.001), " arm ", snappedf(l1 + l2, 0.001))
	var u: Vector3 = to_target.normalized()
	var u0: Vector3 = (hand0.origin - s).normalized()
	var pole: Vector3 = (fore0.origin - s) - u0 * (fore0.origin - s).dot(u0)
	pole = (pole - u * pole.dot(u)).normalized()
	var a: float = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h: float = sqrt(maxf(l1 * l1 - a * a, 0.0))
	var elbow: Vector3 = s + u * a + pole * h
	var reach: Vector3 = s + u * d
	var up_basis: Basis = Basis(Quaternion((fore0.origin - s).normalized(), (elbow - s).normalized())) * up0.basis
	var fore_basis: Basis = Basis(Quaternion((hand0.origin - fore0.origin).normalized(), (reach - elbow).normalized())) * fore0.basis
	var hand_basis: Basis = wrist.basis.orthonormalized()
	var parent: Transform3D = _skel.get_bone_global_pose(_skel.get_bone_parent(b_up))
	out[side + "Arm"] = [_idle_local[side + "Arm"][0], (parent.basis.inverse() * up_basis).get_rotation_quaternion()]
	out[side + "ForeArm"] = [_idle_local[side + "ForeArm"][0], (up_basis.inverse() * fore_basis).get_rotation_quaternion()]
	out[side + "Hand"] = [_idle_local[side + "Hand"][0], (fore_basis.inverse() * hand_basis).get_rotation_quaternion()]


## How far a finger joint bends, from the angle its Y axis makes with its parent's.
func _bend(q: Array) -> float:
	var quat := Quaternion(q[1], q[2], q[3], q[0]).normalized()
	return (quat * Vector3.UP).angle_to(Vector3.UP)


## Finger joints: the Idle grip plus the change in bend of the matching joint on the hand-made rig, about the
## axis the pack's finger bends on (rest pose to Idle).
func _fingers(out: Dictionary, now: Dictionary, first: Dictionary) -> void:
	for side: String in ["Right", "Left"]:
		var suffix: String = "R" if side == "Right" else "L"
		for finger: String in FINGERS:
			for joint: int in [1, 2, 3]:
				var user_name: String = "%s_%02d_%s" % [finger, joint, suffix]
				var bone_name: String = "%sHand%s%d" % [side, finger, joint]
				var bone: int = _skel.find_bone(bone_name)
				if bone < 0 or not now.has(user_name):
					continue
				var rest: Quaternion = _skel.get_bone_rest(bone).basis.get_rotation_quaternion()
				var idle: Quaternion = _idle_local[bone_name][1]
				var flex: Quaternion = rest.inverse() * idle
				var axis: Vector3 = flex.get_axis() if flex.get_angle() > 0.02 else Vector3.RIGHT
				var angle: float = _bend(now[user_name]) - _bend(first[user_name])
				out[bone_name] = [_idle_local[bone_name][0], (idle * Quaternion(axis, angle)).normalized()]
