class_name MagazineType
extends Resource
## One kind of magazine. The family decides which weapons take it; the accepted calibers decide which rounds can be
## loaded into it (two separate checks, see MagazineRules).

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
## Weapons list the families they accept, e.g. &"stanag" or &"glock_9mm".
@export var family: StringName
@export var accepted_calibers: Array[StringName] = []
@export var capacity: int = 30
