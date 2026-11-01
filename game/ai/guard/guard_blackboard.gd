class_name GuardBlackboard
extends RefCounted
## What one guard knows (design §7.3). Owned by its GuardBrain. A squad-level copy with the same keys
## arrives in Milestone 2.

var target: Node
var last_known_position: Vector3 = Vector3.ZERO
## Guard time (seconds the guard has been alive and active) when last_known_position was updated.
var last_known_time: float = 0.0
## Guard time of the last time the guard saw the player...
var last_sight_time: float = -INF
## ...and of the last time it saw or was hurt by them. Fights end when this gets old.
var last_contact_time: float = -INF
var investigate_position: Vector3 = Vector3.ZERO
## 0–1: how accurate last_known_position is.
var confidence: float = 0.0
var search_points: Array[Vector3] = []
var patrol_route: PatrolRoute
var patrol_index: int = 0
## &"sight", &"noise", &"damage" or &"body".
var alerted_by: StringName = &""
