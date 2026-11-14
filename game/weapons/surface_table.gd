class_name SurfaceTable
extends Resource
## All surfaces by id. Unlisted ids (and nodes with no `surface` metadata) use default_surface.

@export var default_surface: SurfaceDefinition
@export var surfaces: Array[SurfaceDefinition] = []

var _by_id: Dictionary = {}


func lookup(id: StringName) -> SurfaceDefinition:
	if _by_id.size() != surfaces.size():
		_by_id.clear()
		for surface: SurfaceDefinition in surfaces:
			_by_id[surface.id] = surface
	return _by_id.get(id, default_surface)
