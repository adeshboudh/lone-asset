class_name MissionState
extends RefCounted
## Runtime state of one mission (design §11.2): which objectives are inactive, active, done or
## failed. Pure logic: the Mission autoload feeds it events and the HUD reads it.

enum Status { INACTIVE, ACTIVE, COMPLETED, FAILED }

signal objective_changed(objective: ObjectiveDefinition, status: Status)
signal checkpoint_reached(objective: ObjectiveDefinition)
signal completed
signal failed(reason: StringName)

var definition: MissionDefinition
var is_finished: bool = false
var was_successful: bool = false
## True once any guard reached the Combat band.
var combat_reached: bool = false

var _status: Dictionary[StringName, Status] = {}


func start(mission: MissionDefinition) -> void:
	definition = mission
	is_finished = false
	was_successful = false
	combat_reached = false
	_status.clear()
	for objective: ObjectiveDefinition in mission.objectives:
		_status[objective.id] = Status.INACTIVE
	_activate_ready()


func status_of(objective_id: StringName) -> Status:
	return _status.get(objective_id, Status.INACTIVE)


func on_trigger(trigger_id: StringName) -> void:
	_complete_matching(ObjectiveDefinition.TYPE_REACH_TRIGGER, trigger_id)
	_complete_matching(ObjectiveDefinition.TYPE_EXTRACT, trigger_id)


func on_interaction(interactable_id: StringName) -> void:
	_complete_matching(ObjectiveDefinition.TYPE_INTERACT, interactable_id)


func on_guard_eliminated(guard_id: StringName) -> void:
	_complete_matching(ObjectiveDefinition.TYPE_ELIMINATE, guard_id)


func on_combat_reached() -> void:
	combat_reached = true
	if is_finished:
		return
	for objective: ObjectiveDefinition in definition.objectives:
		if objective.type == ObjectiveDefinition.TYPE_STEALTH and status_of(objective.id) == Status.ACTIVE:
			_set_status(objective, Status.FAILED)


## Ends the mission unsuccessfully if `reason` is one of its fail conditions.
func fail(reason: StringName) -> void:
	if is_finished or not definition.fail_conditions.has(reason):
		return
	is_finished = true
	failed.emit(reason)


func _complete_matching(type: StringName, target_id: StringName) -> void:
	if is_finished:
		return
	for objective: ObjectiveDefinition in definition.objectives:
		if objective.type == type and objective.target_id == target_id and status_of(objective.id) == Status.ACTIVE:
			_complete(objective)


func _complete(objective: ObjectiveDefinition) -> void:
	_set_status(objective, Status.COMPLETED)
	if objective.checkpoint_on_complete:
		checkpoint_reached.emit(objective)
	_activate_ready()
	_check_finished()


## Activates every inactive objective whose prerequisites are all completed.
func _activate_ready() -> void:
	for objective: ObjectiveDefinition in definition.objectives:
		if status_of(objective.id) != Status.INACTIVE:
			continue
		var ready: bool = true
		for required: StringName in objective.activate_on:
			if status_of(required) != Status.COMPLETED:
				ready = false
		if ready:
			_set_status(objective, Status.ACTIVE)


## The mission succeeds once every required objective is done. The stealth bonus is settled then.
func _check_finished() -> void:
	for objective: ObjectiveDefinition in definition.objectives:
		if not objective.optional and status_of(objective.id) != Status.COMPLETED:
			return
	for objective: ObjectiveDefinition in definition.objectives:
		if objective.type == ObjectiveDefinition.TYPE_STEALTH and status_of(objective.id) == Status.ACTIVE:
			_set_status(objective, Status.FAILED if combat_reached else Status.COMPLETED)
	is_finished = true
	was_successful = true
	completed.emit()


func _set_status(objective: ObjectiveDefinition, status: Status) -> void:
	_status[objective.id] = status
	objective_changed.emit(objective, status)
