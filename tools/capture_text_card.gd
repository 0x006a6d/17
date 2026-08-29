extends Node

## テキストカードの見た目確認用キャプチャ（ウィンドウありで実行。修正はしない）。
##   godot --path . --resolution 1280x720 res://tools/capture_text_card.tscn
## 各面の opening_lines / reveal_lines を順に出し、ページごとに全文表示の状態を
## docs/img/qc_card_<面>_<種別>_<ページ>.png へ保存する。

const OUT_DIR := "res://docs/img"
const STAGES := [
	"res://levels/stage_1.tscn", "res://levels/stage_2.tscn", "res://levels/stage_3.tscn",
	"res://levels/stage_4.tscn", "res://levels/stage_5.tscn",
]

var _card: TextCard = null
var _jobs: Array = []
var _job_index: int = 0
var _frames: int = 0
var _state: String = "idle"
var _shots: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_card = (load("res://ui/text_card.tscn") as PackedScene).instantiate() as TextCard
	_card.chars_per_second = 10000.0
	add_child(_card)
	for i in range(STAGES.size()):
		var packed := load(STAGES[i]) as PackedScene
		var state := packed.instantiate()
		var opening: Array[String] = state.get("opening_lines")
		var reveal: Array[String] = state.get("reveal_lines")
		if not opening.is_empty():
			_jobs.append({"name": "s%d_opening" % (i + 1), "lines": opening})
		if not reveal.is_empty():
			_jobs.append({"name": "s%d_reveal" % (i + 1), "lines": reveal})
		state.free()
	_card.closed.connect(_on_closed)
	_start_job()


func _start_job() -> void:
	if _job_index >= _jobs.size():
		print("captured %d shots" % _shots)
		get_tree().quit()
		return
	var job: Dictionary = _jobs[_job_index]
	_card.lines = job["lines"]
	_card.show_card()
	_frames = 0
	_state = "wait"


func _on_closed() -> void:
	_job_index += 1
	_start_job.call_deferred()


func _process(_delta: float) -> void:
	if _state != "wait":
		return
	_frames += 1
	# 全文表示になってから数フレーム待って撮り、次のページへ。
	if _frames == 8:
		var job: Dictionary = _jobs[_job_index]
		var path := "%s/qc_card_%s_%02d.png" % [OUT_DIR, job["name"], _card.page_index()]
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path(path))
		_shots += 1
		print("shot ", path)
		var ev := InputEventAction.new()
		ev.action = "ui_accept"
		ev.pressed = true
		Input.parse_input_event(ev)
		_frames = 0
