class_name FpsArmsRules
extends RefCounted
## Maths for the first-person arms, which copy the pose of a weapon's arm rig (the M4 pack's) bone by bone.
## Pure functions, unit-tested. See docs/superpowers/specs/2026-11-15-fps-arms-design.md.
##
## The two rigs have different rest poses and bone axes, so a rotation is not copied as is. Each bone gets a frame
## that means the same thing on both rigs: x along the bone (toward its first child), z toward the little finger
## side of its hand. Matching frames match the pose, and because "toward the little finger" is anatomical, a
## mirrored left hand comes out right too.

## Joint names of the new arms (the part between "L_"/"R_" and the bone number) to the pack's names after
## "Left"/"Right". Tip bones ("*4") and the root are not driven.
const JOINTS: Dictionary = {
	"arm": "Arm", "elbow": "ForeArm", "wrist": "Hand",
	"thumb1": "HandThumb1", "thumb2": "HandThumb2", "thumb3": "HandThumb3",
	"point1": "HandIndex1", "point2": "HandIndex2", "point3": "HandIndex3",
	"middle1": "HandMiddle1", "middle2": "HandMiddle2", "middle3": "HandMiddle3",
	"ring1": "HandRing1", "ring2": "HandRing2", "ring3": "HandRing3",
	"pink1": "HandPinky1", "pink2": "HandPinky2", "pink3": "HandPinky3",
}


## Orthonormal frame: x along direction, z the sideways axis made perpendicular to it, y = z cross x.
static func bone_frame(direction: Vector3, sideways: Vector3) -> Basis:
	var x: Vector3 = direction.normalized()
	var z: Vector3 = (sideways - x * x.dot(sideways)).normalized()
	return Basis(x, z.cross(x), z)


## Global basis for a target bone so that its frame (target_frame_rest when the bone rests at target_rest) turns
## into the source's posed frame.
static func retarget(source_frame_pose: Basis, target_frame_rest: Basis, target_rest: Basis) -> Basis:
	return source_frame_pose * target_frame_rest.inverse() * target_rest


## The pack bone that drives a bone of the new arms ("L_point2_09" -> "LeftHandIndex2"), "" when none does.
static func pack_bone(arms_bone: String) -> String:
	var parts: PackedStringArray = arms_bone.split("_")
	if parts.size() < 3 or not (parts[0] == "L" or parts[0] == "R"):
		return ""
	var joint: String = parts[1]
	if not JOINTS.has(joint):
		return ""
	return ("Left" if parts[0] == "L" else "Right") + String(JOINTS[joint])


## How much a weapon's own hand hold overrides the rig's hand: fully while the rig's hand is within near_m of
## where it rests on the gun, nothing beyond far_m (a reload takes the hand away), smooth in between.
static func hold_weight(distance_m: float, near_m: float, far_m: float) -> float:
	return 1.0 - smoothstep(near_m, far_m, distance_m)


## The part of a rotation that turns about an axis (swing-twist split), so a forearm can take the roll of its hand
## instead of the wrist skin twisting.
static func twist(rotation: Quaternion, axis: Vector3) -> Quaternion:
	var a: Vector3 = axis.normalized()
	var along: Vector3 = a * Vector3(rotation.x, rotation.y, rotation.z).dot(a)
	var q: Quaternion = Quaternion(along.x, along.y, along.z, rotation.w)
	if q.length_squared() < 0.000001:
		return Quaternion.IDENTITY
	return q.normalized()
