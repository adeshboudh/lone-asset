class_name UiSounds
extends RefCounted
## Menu sounds for every button under a node: hover on mouse-over and keyboard focus, a click on press.

const HOVER: StringName = &"ui_hover"
const CLICK: StringName = &"ui_click"
## Set on a button once wired, so a menu that contains another wired menu (the settings panel) is not wired twice.
const WIRED: StringName = &"ui_wired"


## Connects the sounds to every BaseButton at or below root. Call once the menu's buttons exist.
static func wire(root: Node) -> void:
	var buttons: Array[Node] = root.find_children("*", "BaseButton", true, false)
	if root is BaseButton:
		buttons.append(root)
	for node: Node in buttons:
		var button: BaseButton = node as BaseButton
		if button.has_meta(WIRED):
			continue
		button.set_meta(WIRED, true)
		button.mouse_entered.connect(_play_hover.bind(button))
		button.focus_entered.connect(_play_hover.bind(button))
		button.pressed.connect(_play_press)


static func _play_hover(button: BaseButton) -> void:
	if not button.disabled:
		Audio.play_ui(HOVER)


static func _play_press() -> void:
	Audio.play_ui(CLICK)
