class_name PlayerBodyRules
extends RefCounted
## Rules for the player's visible body (design §4). Pure functions, unit-tested.

## Every mesh of the body except the jacket is hidden from the first-person camera (they still cast shadows): the head, helmet,
## vest, pants and boots would fill the view, and the jacket and arm meshes run from the shoulder, so their upper
## arms would hang in front of the camera. What the camera shows instead is a copy of the jacket cut to the
## forearms and a copy of the arm mesh cut to the hands, by skin weight (`arm_triangles`): the player's own arms
## holding the weapon. Matched against mesh names, lower case.
const VISIBLE_TO_CAMERA: PackedStringArray = ["jaket"]
## Share of a vertex's skin weight on the chosen bones above which it belongs to the cut-out.
const CUT_WEIGHT: float = 0.5
## The hands are drawn a little smaller than the model so they sit well beside the sights.
const HAND_SCALE: float = 0.88
## Finger bend at a full grip: knuckle, middle joint and tip, in degrees, and the thumb's two joints.
const FINGER_CURL_DEG: Array[float] = [70.0, 85.0, 55.0]
const THUMB_CURL_DEG: Array[float] = [30.0, 35.0]


static func hidden_from_camera(mesh_name: String) -> bool:
	var lower: String = mesh_name.to_lower()
	for part: String in VISIBLE_TO_CAMERA:
		if lower.contains(part):
			return false
	return true


## Names "Bone.014" ... for the agent model's bones numbered first to last, both inclusive.
static func bone_names(first: int, last: int) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for number: int in range(first, last + 1):
		names.append("Bone.%03d" % number)
	return names


## The triangles of a skinned surface (mesh arrays) with at least two vertices that carry CUT_WEIGHT or more of
## their skin weight on the bones in binds (skin bind index -> true).
static func arm_triangles(arrays: Array, binds: Dictionary) -> PackedInt32Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var out: PackedInt32Array = PackedInt32Array()
	if vertices.is_empty() or arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
		return out
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per_vertex: int = bones.size() / vertices.size()
	var inside: PackedByteArray = PackedByteArray()
	inside.resize(vertices.size())
	for vertex: int in vertices.size():
		var weight: float = 0.0
		for slot: int in per_vertex:
			if binds.has(bones[vertex * per_vertex + slot]):
				weight += weights[vertex * per_vertex + slot]
		inside[vertex] = 1 if weight >= CUT_WEIGHT else 0
	for tri: int in indices.size() / 3:
		var a: int = indices[tri * 3]
		var b: int = indices[tri * 3 + 1]
		var c: int = indices[tri * 3 + 2]
		if inside[a] + inside[b] + inside[c] >= 2:
			out.append_array(PackedInt32Array([a, b, c]))
	return out


## An orthonormal hand frame from the directions wrist to middle knuckle and index knuckle to little-finger
## knuckle: columns are forward, palm normal and sideways, a proper rotation for either hand.
static func hand_frame(forward: Vector3, sideways: Vector3) -> Basis:
	var f: Vector3 = forward.normalized()
	var l: Vector3 = (sideways - f * f.dot(sideways)).normalized()
	return Basis(f, l.cross(f), l)


## Where a hand frame has turned to when its bone goes from the rest basis to the pose basis (same space).
static func frame_pose(bone_pose: Basis, bone_rest: Basis, frame_rest: Basis) -> Basis:
	return bone_pose * bone_rest.inverse() * frame_rest


## Global basis for a hand bone so that its hand frame (resting as target_frame_rest, with the bone resting as
## target_rest) ends up as wanted_frame. All in the target bone's space.
static func bone_basis_for_frame(wanted_frame: Basis, target_frame_rest: Basis, target_rest: Basis) -> Basis:
	return wanted_frame * target_frame_rest.inverse() * target_rest


## Where a hand goes (body space, metres from the feet): the weapon's hold point, raised toward the
## sights when aiming, lowered and pulled in when sprinting, dropped with the eyes when crouching and
## shifted sideways when leaning.
static func hand_target(hold: Vector3, ads_offset: Vector3, aim_blend: float, sprint_offset: Vector3, sprint_blend: float,
		eye_drop_m: float, lean_shift_m: float) -> Vector3:
	var aimed: Vector3 = hold + ads_offset * aim_blend
	aimed += sprint_offset * sprint_blend * (1.0 - aim_blend)
	return aimed + Vector3(lean_shift_m, -eye_drop_m, 0.0)


## Both hands at the eyes for binoculars (x is the hand's side: -1 left, 1 right).
static func binocular_hand(side: float, eye_height: float) -> Vector3:
	return Vector3(0.06 * side, eye_height - 0.12, -0.3)
