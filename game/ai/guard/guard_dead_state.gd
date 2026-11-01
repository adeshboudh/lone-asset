class_name GuardDeadState
extends GuardState
## The guard has died: stops, falls over and stays where it fell (design §7.4).


func enter(_previous: StringName) -> void:
	guard.on_death()
