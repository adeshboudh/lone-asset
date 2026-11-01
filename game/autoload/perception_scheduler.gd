extends Node
## Spreads guards' vision checks over time (design §8.3) so many guards never cost more than a fixed
## number of rays per physics tick. Global because the ray budget is shared by every guard.

## Rays allowed per physics tick.
const RAY_BUDGET: int = 24
const SMOOTHING: float = 0.05

## Seconds of simulated time since the scheduler started.
var clock: float = 0.0
## Statistics of the last tick, for the debug overlay and tests.
var rays_last_tick: int = 0
var checks_last_tick: int = 0
var max_rays_per_tick: int = 0
var average_ms: float = 0.0

var _player: Player


func _ready() -> void:
	if not Performance.has_custom_monitor(&"ai/perception_ms"):
		Performance.add_custom_monitor(&"ai/perception_ms", get_average_ms)


func _exit_tree() -> void:
	if Performance.has_custom_monitor(&"ai/perception_ms"):
		Performance.remove_custom_monitor(&"ai/perception_ms")


func get_average_ms() -> float:
	return average_ms


func _physics_process(delta: float) -> void:
	clock += delta
	var started: int = Time.get_ticks_usec()
	rays_last_tick = 0
	checks_last_tick = 0

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player != null:
		var due: Array[PerceptionComponent] = []
		for node: Node in get_tree().get_nodes_in_group(PerceptionComponent.GROUP):
			var component: PerceptionComponent = node as PerceptionComponent
			if component.is_active() and component.next_check_time <= clock:
				due.append(component)
		# Whoever has waited longest goes first, so nobody starves when the budget runs out.
		due.sort_custom(func(a: PerceptionComponent, b: PerceptionComponent) -> bool: return a.next_check_time < b.next_check_time)
		for component: PerceptionComponent in due:
			if rays_last_tick + PerceptionRules.RAYS_PER_CHECK > RAY_BUDGET:
				break
			rays_last_tick += component.check(_player, clock)
			checks_last_tick += 1

	max_rays_per_tick = maxi(max_rays_per_tick, rays_last_tick)
	average_ms = lerpf(average_ms, (Time.get_ticks_usec() - started) / 1000.0, SMOOTHING)
