class_name NoiseEvent
extends RefCounted
## A sound that AI can hear (design §8.2). Gameplay noise is separate from audio playback.

const FOOTSTEP_WALK: StringName = &"footstep_walk"
const FOOTSTEP_SPRINT: StringName = &"footstep_sprint"
const FOOTSTEP_CROUCH: StringName = &"footstep_crouch"
const LANDING: StringName = &"landing"
const SHOT_SUPPRESSED: StringName = &"shot_suppressed"
const SHOT: StringName = &"shot"
const DOOR: StringName = &"door"
const IMPACT: StringName = &"impact"

var type: StringName = &""
var position: Vector3 = Vector3.ZERO
## Distance in open air at which this noise can still be heard.
var radius_m: float = 0.0
## Who made the noise, or null.
var source: Node
