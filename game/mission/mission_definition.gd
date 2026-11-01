class_name MissionDefinition
extends Resource
## A mission: its objectives and what ends it badly (design §11.1).

@export var id: StringName
@export var display_name: String
@export var objectives: Array[ObjectiveDefinition] = []
## Reasons that fail the mission, such as &"player_died".
@export var fail_conditions: Array[StringName] = []
