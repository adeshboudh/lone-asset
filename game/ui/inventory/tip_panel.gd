class_name TipPanel
extends PanelContainer
## A panel that shows the inventory's hover box (the same box as an ItemSlot) for its `tooltip_text`.


func _make_custom_tooltip(for_text: String) -> Object:
	return ItemSlot.make_tip(for_text)
