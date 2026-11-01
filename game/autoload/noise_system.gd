extends Node
## Delivers gameplay noise to listeners in range (design §8.2). Each wall between source and listener
## halves the distance the noise carries.

## Walls are tested at ear height, so low cover does not muffle sound.
const RAY_HEIGHT: float = 1.2
## Physics layer 1 = world geometry. Characters and targets do not block sound.
const WORLD_MASK: int = 1

var profiles: NoiseProfiles = preload("res://data/noise/noise_profiles.tres")


## Emits a noise and returns the event. Listeners within the (wall-attenuated) radius hear it.
func emit_noise(type: StringName, position: Vector3, radius_m: float, source: Node = null) -> NoiseEvent:
	var event: NoiseEvent = NoiseEvent.new()
	event.type = type
	event.position = position
	event.radius_m = radius_m
	event.source = source
	EventBus.noise_emitted.emit(event)
	if radius_m <= 0.0:
		return event

	var space: PhysicsDirectSpaceState3D = get_tree().root.world_3d.direct_space_state
	var exclude: Array[RID] = []
	var body: CollisionObject3D = source as CollisionObject3D
	if body != null:
		exclude.append(body.get_rid())
	for node: Node in get_tree().get_nodes_in_group(NoiseListener.GROUP):
		var listener: NoiseListener = node as NoiseListener
		var distance: float = position.distance_to(listener.listener_position)
		if distance > radius_m:
			continue
		var walls: int = _count_walls(space, position, listener.listener_position, exclude)
		if NoiseRules.is_heard(distance, NoiseRules.effective_radius(radius_m, walls)):
			listener.hear(event, distance, walls)
	return event


func _count_walls(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> int:
	var skipped: Array[RID] = exclude.duplicate()
	var lift: Vector3 = Vector3.UP * RAY_HEIGHT
	var walls: int = 0
	while walls < NoiseRules.MAX_WALLS:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from + lift, to + lift, WORLD_MASK, skipped)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			break
		walls += 1
		skipped.append(hit["rid"])
	return walls
