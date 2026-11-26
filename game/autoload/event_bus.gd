extends Node
## Global gameplay signals (design §2.4). No logic lives here.

## target: the damaged node (parent of its HealthComponent).
signal damage_applied(target: Node, info: DamageInfo, killed: bool)
signal noise_emitted(event: NoiseEvent)
signal player_died

## A guard's suspicion moved into another band (see SuspicionRules.Band).
signal guard_alert_band_changed(guard: Node, old_band: int, new_band: int)

## guard: the Guard whose state machine changed state.
signal guard_state_changed(guard: Node, old_state: StringName, new_state: StringName)

## The player entered a TriggerZone.
signal trigger_entered(trigger_id: StringName)

## An Interactable finished (a door toggled, a terminal download completed). actor: who used it.
signal interaction_completed(interactable_id: StringName, actor: Node)

## A mission objective that asks for a checkpoint was completed (WP 12 saves on it).
signal checkpoint_requested(objective_id: StringName)

## A reload could not start. reason: &"no_magazine" (no spare magazine fits or holds more rounds) or &"full".
signal reload_blocked(reason: StringName)

## The magazine in a weapon changed (a reload finished). weapon_id: the weapon definition's id.
signal magazine_changed(weapon_id: StringName)

## A short message for the HUD toast (a pickup taken, the pouches full).
signal toast_requested(text: String)

## The player opened a container: show its contents next to the inventory. anchor is where it is (walking away closes it).
signal container_opened(store: LootStore, title: String, anchor: Node3D)
