extends SceneTree

const TITLE_PATH: String = "res://ui/title_screen.tscn"
const FIRST_STAGE_PATH: String = "res://levels/stage_1.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var load_error: Error = change_scene_to_file(TITLE_PATH)
	if load_error != OK:
		_fail("タイトル画面を読み込めない: %d" % load_error)
		return
	await scene_changed
	var title: Node = current_scene
	if title == null or title.scene_file_path != TITLE_PATH:
		_fail("起動シーンがタイトル画面ではない")
		return
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	title.call("_input", accept)
	await scene_changed
	if current_scene == null or current_scene.scene_file_path != FIRST_STAGE_PATH:
		_fail("決定入力で1面へ遷移しない")
		return
	print("[PASS] タイトル画面を読み込める")
	print("[PASS] 決定入力で1面へ遷移する")
	print("ALL PASS")
	quit(0)


func _fail(message: String) -> void:
	printerr("[FAIL] %s" % message)
	quit(1)
