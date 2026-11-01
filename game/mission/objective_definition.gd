class_name ObjectiveDefinition
extends Resource
## One step of a mission (design §11.1). Level objects are referenced by stable string IDs.

const TYPE_REACH_TRIGGER: StringName = &"reach_trigger"
const TYPE_INTERACT: StringName = &"interact"
const TYPE_ELIMINATE: StringName = &"eliminate"
const TYPE_EXTRACT: StringName = &"extract"
## Optional: no guard reached the Combat band by the time the mission ends.
const TYPE_STEALTH: StringName = &"stealth"

@export var id: StringName
@export var text: String
@export var type: StringName = TYPE_REACH_TRIGGER
## trigger_id, interactable_id or guard_id, depending on the type.
@export var target_id: StringName
@export var optional: bool = false
## Objectives that must be completed before this one becomes active.
@export var activate_on: Array[StringName] = []
@export var checkpoint_on_complete: bool = true
