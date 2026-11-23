class_name MagazineType
extends Resource
## One kind of magazine. The family decides which weapons take it; the accepted calibers decide which rounds can be
## loaded into it (two separate checks, see MagazineRules).

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
## The magazine in the world (pickup on a table or the floor); the mesh carries no textures, so the pickup applies
## these. Without a mesh the pickup shows the icon.
@export var mesh: Mesh
@export var albedo: Texture2D
@export var normal: Texture2D
## Weapons list the families they accept, e.g. &"stanag" or &"glock_9mm".
@export var family: StringName
@export var accepted_calibers: Array[StringName] = []
@export var capacity: int = 30
