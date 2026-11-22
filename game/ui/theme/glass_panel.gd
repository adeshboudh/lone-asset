class_name GlassPanel
extends PanelContainer
## A frosted-glass window: the picture behind it is blurred, dimmed and tinted (glass.gdshader), with a thin light border.
## Add content as ordinary children. Look: data/ui/glass_material.tres and the "GlassPanel" theme variation.

const GLASS: ShaderMaterial = preload("res://data/ui/glass_material.tres")


func _init() -> void:
	theme_type_variation = &"GlassPanel"
	material = GLASS
