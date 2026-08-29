extends Node
## 面の開始直後を連続で撮る（髪が舞い上がる原因の切り分け用）。
##   godot --path . --resolution 960x540 res://tools/capture_stage_start.tscn
const STAGE := "res://levels/stage_1.tscn"
const OUTPUT_DIRECTORY := "res://docs/img/"
const SHOTS: int = 14
const GAP_FRAMES: int = 6

var _stage: Node3D = null
var _player: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.reset()
	_stage = (load(STAGE) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node_or_null(^"Player") as Node3D
	_run()


func _accept() -> void:
	var ev := InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)


func _run() -> void:
	for i: int in range(SHOTS):
		await RenderingServer.frame_post_draw
		var path := OUTPUT_DIRECTORY + "qc_start_%02d.png" % i
		get_viewport().get_texture().get_image().save_png(path)
		var y: float = _player.global_position.y if _player != null else -1.0
		var vy: float = float(_player.get("velocity").y) if _player != null else 0.0
		print("[shot] %02d  player.y=%.3f  velocity.y=%.3f  paused=%s"
			% [i, y, vy, str(get_tree().paused)])
		for _f: int in range(GAP_FRAMES):
			await get_tree().process_frame
		# 2枚ごとにカードを送り、開始 → 会話 → 操作開始まで通す。
		if i % 2 == 1:
			_accept()
			await _wait(4)
	get_tree().quit()


func _wait(count: int) -> void:
	for _f: int in range(count):
		await get_tree().process_frame
