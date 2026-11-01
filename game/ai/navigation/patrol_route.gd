class_name PatrolRoute
extends Node3D
## An ordered list of PatrolPoint children that guards walk (design §10).

@export var mode: PatrolSequence.Mode = PatrolSequence.Mode.LOOP


func points() -> Array[PatrolPoint]:
	var result: Array[PatrolPoint] = []
	for child: Node in get_children():
		var point: PatrolPoint = child as PatrolPoint
		if point != null:
			result.append(point)
	return result
