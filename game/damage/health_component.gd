class_name HealthComponent
extends Node
## Health of its parent (design §6). Damage dealers find it as the child named "HealthComponent"
## of the collider they hit.

signal damaged(info: DamageInfo, amount: float)
signal died(info: DamageInfo)

const NODE_NAME: StringName = &"HealthComponent"

@export var max_health: float = 100.0

var health: float = 0.0
var is_dead: bool:
	get:
		return health <= 0.0


func _ready() -> void:
	health = max_health


## Returns the damage actually applied (capped by remaining health; 0 when already dead).
func apply_damage(info: DamageInfo) -> float:
	if is_dead or info.amount <= 0.0:
		return 0.0
	var applied: float = minf(info.amount, health)
	health -= applied
	damaged.emit(info, applied)
	EventBus.damage_applied.emit(get_parent(), info, is_dead)
	if is_dead:
		died.emit(info)
	return applied


func reset() -> void:
	health = max_health


## The HealthComponent of a hit collider, or null if it cannot be damaged.
static func of(target: Object) -> HealthComponent:
	var node: Node = target as Node
	if node == null:
		return null
	return node.get_node_or_null(NodePath(NODE_NAME)) as HealthComponent
