extends Control
class_name TitleScreen

const FIRST_STAGE_PATH: String = "res://levels/stage_1.tscn"

var _starting: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func _input(event: InputEvent) -> void:
	if _starting:
		return
	var accepted: bool = event.is_action_pressed(&"ui_accept")
	if not accepted and event is InputEventKey and event.pressed \
			and not event.echo:
		var key_event := event as InputEventKey
		accepted = key_event.physical_keycode == KEY_ENTER \
			or key_event.physical_keycode == KEY_KP_ENTER \
			or key_event.physical_keycode == KEY_SPACE
	if not accepted and event is InputEventMouseButton and event.pressed:
		accepted = (event as InputEventMouseButton).button_index \
			== MOUSE_BUTTON_LEFT
	if not accepted:
		return
	_starting = true
	get_viewport().set_input_as_handled()
	get_tree().change_scene_to_file(FIRST_STAGE_PATH)
