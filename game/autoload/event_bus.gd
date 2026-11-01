extends Node
## Global gameplay signals (design §2.4). No logic lives here.

## target: the damaged node (parent of its HealthComponent).
signal damage_applied(target: Node, info: DamageInfo, killed: bool)
signal noise_emitted(event: NoiseEvent)
