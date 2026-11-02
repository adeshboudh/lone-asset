extends Node
## Runs the current mission (design §11.2): turns gameplay events into objective progress.

## Something about the objectives changed; the HUD redraws its list.
signal changed
signal objective_completed(objective: ObjectiveDefinition)
signal mission_completed
signal mission_failed(reason: StringName)

var state: MissionState = MissionState.new()
## Seconds of play since the mission started (paused time does not count).
var elapsed_s: float = 0.0
## Guards the player has killed this mission.
var guards_eliminated: int = 0


func _ready() -> void:
	state.definition = MissionDefinition.new()
	EventBus.trigger_entered.connect(func(id: StringName) -> void: state.on_trigger(id))
	EventBus.interaction_completed.connect(func(id: StringName, _actor: Node) -> void: state.on_interaction(id))
	EventBus.guard_alert_band_changed.connect(_on_alert_band_changed)
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.player_died.connect(func() -> void: state.fail(&"player_died"))


func start(mission: MissionDefinition) -> void:
	elapsed_s = 0.0
	guards_eliminated = 0
	state = MissionState.new()
	state.objective_changed.connect(_on_objective_changed)
	state.checkpoint_reached.connect(func(objective: ObjectiveDefinition) -> void: EventBus.checkpoint_requested.emit(objective.id))
	state.completed.connect(_on_completed)
	state.failed.connect(func(reason: StringName) -> void: mission_failed.emit(reason))
	state.start(mission)
	Log.info(&"mission", "Started '%s'" % mission.id)
	changed.emit()


func _process(delta: float) -> void:
	if not state.is_finished:
		elapsed_s += delta


func save_state() -> Dictionary:
	return {"elapsed_s": elapsed_s, "guards_eliminated": guards_eliminated, "combat_reached": state.combat_reached}


func load_state(mission: Dictionary, objectives: Dictionary) -> void:
	state.load_state(objectives, bool(mission.get("combat_reached", false)))
	elapsed_s = float(mission.get("elapsed_s", 0.0))
	guards_eliminated = int(mission.get("guards_eliminated", 0))
	changed.emit()


## What the end screen shows after a completed mission.
func summary_text() -> String:
	var seconds: int = int(elapsed_s)
	var text: String = "Time  %d:%02d\nDetected  %s\nGuards eliminated  %d" % [
		seconds / 60, seconds % 60, "yes" if state.combat_reached else "no", guards_eliminated]
	for objective: ObjectiveDefinition in state.definition.objectives:
		if objective.type == ObjectiveDefinition.TYPE_STEALTH:
			var status: MissionState.Status = state.status_of(objective.id)
			text += "\n%s  %s" % [objective.text, "completed" if status == MissionState.Status.COMPLETED else "not achieved"]
	return text


func _on_damage_applied(target: Node, info: DamageInfo, killed: bool) -> void:
	if killed and target is Guard and info.source != null and info.source.is_in_group(&"player"):
		guards_eliminated += 1


func _on_objective_changed(objective: ObjectiveDefinition, status: MissionState.Status) -> void:
	if status == MissionState.Status.COMPLETED:
		Log.info(&"mission", "Objective '%s' completed" % objective.id)
		objective_completed.emit(objective)
	changed.emit()


func _on_completed() -> void:
	Log.info(&"mission", "Mission completed in %.1f s" % elapsed_s)
	mission_completed.emit()


func _on_alert_band_changed(_guard: Node, _old_band: int, new_band: int) -> void:
	if new_band == SuspicionRules.Band.COMBAT:
		state.on_combat_reached()
		changed.emit()
