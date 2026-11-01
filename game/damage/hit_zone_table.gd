class_name HitZoneTable
extends Resource
## Damage multipliers per hit zone (design §6). Collision shapes name their zone with the
## "hit_zone" metadata; shapes without it count as torso.

const META_KEY: StringName = &"hit_zone"
const DEFAULT_ZONE: StringName = &"torso"

@export var multipliers: Dictionary[StringName, float] = {
	&"head": 4.0,
	&"torso": 1.0,
	&"limb": 0.6,
}


func multiplier(zone: StringName) -> float:
	return multipliers.get(zone, 1.0)


## Zone of the collision shape that was hit, from a raycast's collider and shape index.
static func zone_of(collider: Object, shape_index: int) -> StringName:
	var body: CollisionObject3D = collider as CollisionObject3D
	if body == null or shape_index < 0:
		return DEFAULT_ZONE
	var shape_node: Node = body.shape_owner_get_owner(body.shape_find_owner(shape_index)) as Node
	if shape_node != null and shape_node.has_meta(META_KEY):
		return shape_node.get_meta(META_KEY)
	return DEFAULT_ZONE
