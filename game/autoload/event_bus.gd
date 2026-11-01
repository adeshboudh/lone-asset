extends Node
## Global gameplay signals (design §2.4). No logic lives here.

## target: the damaged node (parent of its HealthComponent).
signal damage_applied(target: Node, info: DamageInfo, killed: bool)
signal noise_emitted(event: NoiseEvent)

## guard: the Guard whose state machine changed state.
signal guard_state_changed(guard: Node, old_state: StringName, new_state: StringName)
