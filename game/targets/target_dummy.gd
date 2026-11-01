class_name TargetDummy
extends StaticBody3D
## Shooting-range target with head / torso / limb hit zones (design §6). Shows floating damage
## numbers, falls over when killed and stands back up after a few seconds.

const RESPAWN_DELAY_S: float = 3.0
const FALL_TIME_S: float = 0.35

@onready var _health: HealthComponent = $HealthComponent
@onready var _model: Node3D = $Model

var _collision_layer: int


func _ready() -> void:
	_collision_layer = collision_layer
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)


func _on_damaged(info: DamageInfo, amount: float) -> void:
	var label: Label3D = Label3D.new()
	label.text = "%d" % roundi(amount)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	label.outline_size = 8
	label.modulate = Color(1.0, 0.35, 0.3) if info.hit_zone == &"head" else Color(1.0, 0.9, 0.4)
	get_parent().add_child(label)
	label.global_position = info.hit_position + Vector3.UP * 0.15
	var tween: Tween = label.create_tween().set_parallel()
	tween.tween_property(label, "global_position", label.global_position + Vector3.UP * 0.5, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)


func _on_died(_info: DamageInfo) -> void:
	collision_layer = 0
	var tween: Tween = create_tween()
	tween.tween_property(_model, "rotation:x", -PI * 0.5, FALL_TIME_S).set_ease(Tween.EASE_IN)
	tween.tween_interval(RESPAWN_DELAY_S)
	tween.tween_property(_model, "rotation:x", 0.0, FALL_TIME_S)
	tween.tween_callback(_respawn)


func _respawn() -> void:
	_health.reset()
	collision_layer = _collision_layer
