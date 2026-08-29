extends Node3D

## 各面を開いて背景の見た目を確認するキャプチャ（ウィンドウありで実行。修正はしない）。
##   godot --path . --resolution 1280x720 res://tools/capture_stage_view.tscn -- --stage 2
## 冒頭カードを閉じ、開始位置と、右へ 3 秒歩いた位置の 2 枚を docs/img/qc_bg_stage<N>_*.png へ保存する。
## `-- --stage 4 --fight 9` のように --fight を付けると、その秒数まで走らせて戦闘中の1枚
## （qc_bg_stage<N>_fight.png）も撮る。雑魚の波が出るまで待ちたいときに使う。

const OUT_DIR := "res://docs/img"

var _stage_index: int = 1
## 追加で撮る戦闘中の秒数（0 以下なら撮らない）。
var _fight_seconds: float = 0.0
var _stage: BeltStage = null
var _frames: int = 0
var _op_frames: int = 0
var _play_started: int = -1
var _shots: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--stage":
			_stage_index = int(args[i + 1])
		elif args[i] == "--fight":
			_fight_seconds = float(args[i + 1])
	_stage = (load("res://levels/stage_%d.tscn" % _stage_index) as PackedScene).instantiate() as BeltStage
	add_child(_stage)
	StageDirector.phase_changed.connect(func(phase: int) -> void:
		if phase == StageDirector.Phase.PLAY and _play_started < 0:
			_play_started = _frames)
	# 冒頭カードの無い面は add_child の時点で PLAY に入っている。
	if StageDirector.phase == StageDirector.Phase.PLAY:
		_play_started = _frames


func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _accept() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _play_started < 0:
		var card := _stage.text_card()
		if card != null and card.is_open():
			_op_frames += 1
			if _op_frames % 6 == 0:
				_accept()
		if _frames > 900:
			print("[stage_view] PLAY に入らない")
			get_tree().quit()
		return
	var t := (_frames - _play_started) / float(Engine.physics_ticks_per_second)
	if t >= 0.5 and not _shots.has("start"):
		_shoot("start")
		_key(KEY_D, true)
	if t >= 3.5 and not _shots.has("walk"):
		_key(KEY_D, false)
		_shoot("walk")
	if _fight_seconds > 0.0:
		# 雑魚が寄ってくるまで待って、戦闘中の絵を1枚撮る。
		if t >= _fight_seconds and not _shots.has("fight"):
			_shoot("fight")
		if t >= _fight_seconds + 0.5:
			get_tree().quit()
		return
	if t >= 4.0:
		get_tree().quit()


func _shoot(tag: String) -> void:
	_shots.append(tag)
	var img := get_viewport().get_texture().get_image()
	var path := "%s/qc_bg_stage%d_%s.png" % [OUT_DIR, _stage_index, tag]
	print("[stage_view] %s (%s)" % [path, error_string(img.save_png(path))])
