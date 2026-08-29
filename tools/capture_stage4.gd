extends Node3D

## 4面の画面確認用キャプチャ（ウィンドウありで実行。修正はしない）。
##   godot --path . --resolution 1280x720 res://tools/capture_stage4.tscn
## 冒頭カード（ミカゼ）→ 右へ走ってボスバー表示 → 正面（盾）→ 側面へ回る → 撃破（HP を直接削る）
## → 身体が崩れたままの開示カード（全ページ）→ フラッシュ後、の各時点を docs/img/qc_stage4_*.png へ保存する。
## 冒頭カードでツリーが止まる間は時間を進めず、PLAY に入ってからの経過で動かす。

const OUT_DIR := "res://docs/img"

var _stage: BeltStage = null
var _frames: int = 0
var _play_started_frame: int = -1
var _shots: Array[String] = []
var _boss: Node3D = null
var _reveal_pages: int = 0
var _reveal_wait: int = 0
var _reveal_done: bool = false
var _op_frames: int = 0


func _ready() -> void:
	# カードがツリーを止めている間も進行・撮影・終了できるようにする。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = (load("res://levels/stage_4.tscn") as PackedScene).instantiate() as BeltStage
	add_child(_stage)
	StageDirector.boss_started.connect(func(b: Node3D) -> void:
		_boss = b
		_shoot_later("boss_bar", 0.6))
	StageDirector.phase_changed.connect(func(phase: int) -> void:
		if phase == StageDirector.Phase.PLAY and _play_started_frame < 0:
			_play_started_frame = _frames)


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
	var card := _stage.text_card()
	# --- 冒頭カード: 撮って閉じる ---
	if _play_started_frame < 0:
		if card != null and card.is_open():
			_op_frames += 1
			if _op_frames == 20:
				_shoot("op")
			if _op_frames == 24 or _op_frames == 30:
				_accept()
		if _frames > 600:
			print("[capture] opening card did not open")
			get_tree().quit()
		return
	# --- 開示カード: 全ページを撮る ---
	if _boss != null and card != null and card.is_open() and not _reveal_done:
		_reveal_wait += 1
		if _reveal_wait == 6:
			# 表示途中を全文にしてから撮る。
			_accept()
		if _reveal_wait == 12:
			_shoot("reveal_%02d" % card.page_index())
			_reveal_pages += 1
			_accept()
			_reveal_wait = 0
		return
	if _reveal_pages > 0 and not _reveal_done and (card == null or not card.is_open()):
		_reveal_done = true
		_shoot_later("after", 0.12)
		get_tree().create_timer(1.0, true).timeout.connect(func() -> void:
			print("[capture] reveal pages=%d" % _reveal_pages)
			get_tree().quit())
		return
	var t := (_frames - _play_started_frame) / float(Engine.physics_ticks_per_second)
	if _frames - _play_started_frame == 1:
		_key(KEY_D, true)
	if t >= 0.8 and not _shots.has("start"):
		_shoot("start")
	if t >= 3.2 and not _shots.has("front"):
		_key(KEY_D, false)
		_shoot("front")
	if t >= 3.4 and t < 4.6:
		# 奥のレーンへ移ってから右へ抜けて背面へ。
		_key(KEY_W, true)
		_key(KEY_D, true)
	if t >= 4.6 and not _shots.has("crossing"):
		_key(KEY_W, false)
		_shoot("crossing")
	if t >= 5.6 and not _shots.has("behind"):
		_key(KEY_D, false)
		_shoot("behind")
		if _boss != null:
			var h := _boss.get_node_or_null("Health") as Health
			if h != null:
				h.take_hit(h.max_hp)
	if t >= 7.2 and not _shots.has("collapsed"):
		# 身体が崩れ、カードが出る直前。
		_shoot("collapsed")
	if t >= 30.0:
		print("[capture] timeout")
		get_tree().quit()


func _shoot_later(tag: String, seconds: float) -> void:
	get_tree().create_timer(seconds, true).timeout.connect(func() -> void: _shoot(tag))


func _shoot(tag: String) -> void:
	if _shots.has(tag):
		return
	_shots.append(tag)
	var img := get_viewport().get_texture().get_image()
	var path := "%s/qc_stage4_%s.png" % [OUT_DIR, tag]
	var err := img.save_png(path)
	print("[capture] %s -> %s (%s) frame=%d" % [tag, path, error_string(err), _frames])
