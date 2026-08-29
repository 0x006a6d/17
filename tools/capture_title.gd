extends Node

const LIT_OUTPUT_PATH: String = "res://docs/img/qc_title_screen.png"
const UNLIT_OUTPUT_PATH: String = "res://docs/img/qc_title_screen_unlit.png"


func _ready() -> void:
	for _frame: int in 4:
		await get_tree().process_frame
	print("[capture] window=%s viewport=%s" % [
		get_window().size, get_viewport().get_visible_rect().size])
	var error: Error = _save_viewport(LIT_OUTPUT_PATH)
	if error != OK:
		get_tree().quit(error)
		return
	for _frame: int in 50:
		await get_tree().process_frame
	error = _save_viewport(UNLIT_OUTPUT_PATH)
	get_tree().quit(error)


func _save_viewport(path: String) -> Error:
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(path)
	if error == OK:
		print("[capture] %s" % path)
	else:
		printerr("[capture] failed: %s (%d)" % [path, error])
	return error
