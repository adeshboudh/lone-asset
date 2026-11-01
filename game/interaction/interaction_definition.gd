class_name InteractionDefinition
extends Resource
## What interacting with an object looks like (design §12). Edited in data/interaction/.

@export var id: StringName
## Shown in the HUD prompt: "Open", "Download data".
@export var prompt_text: String = "Use"
## Seconds the key must be held; 0 means a single press.
@export var hold_duration: float = 0.0
@export var required_item: StringName = &""
@export var interrupt_on_damage: bool = true
## Noise made when the player completes the interaction; 0 is silent.
@export var noise_radius_m: float = 0.0
@export var noise_type: StringName = NoiseEvent.DOOR
## Disables the interactable once completed.
@export var one_shot: bool = false
