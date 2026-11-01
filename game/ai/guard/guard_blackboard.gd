class_name GuardBlackboard
extends RefCounted
## What one guard knows (design §7.3). Owned by its GuardBrain. A squad-level copy with the same keys
## arrives in Milestone 2.

var target: Node
var last_known_position: Vector3 = Vector3.ZERO
## Seconds since level start.
var last_known_time: float = 0.0
var investigate_position: Vector3 = Vector3.ZERO
## 0–1: how accurate last_known_position is.
var confidence: float = 0.0
var search_points: Array[Vector3] = []
var patrol_route: PatrolRoute
var patrol_index: int = 0
## &"sight", &"noise", &"damage" or &"body".
var alerted_by: StringName = &""
