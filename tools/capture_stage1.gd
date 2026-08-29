extends Node3D

## 1面の画面確認用キャプチャ（ウィンドウありで実行。修正はしない）。
##   godot --path . --resolution 1280x720 res://tools/capture_stage1.tscn
## D を押しっぱなしで右へ走り、画面ロック → 波 → （敵を自動で倒し）→ GO → ボスまでの
## 各時点を docs/img/qc_stage1_*.png へ保存する。敵は倒すのが目的ではないので、
## 一定時間ごとに HP を直接削って進行させる。

const OUT_DIR := "res://docs/img"

var _stage: Node3D = null
var _frames: int = 0
var _shots: Array[String] = []
var _kill_timer: float = 0.0


func _ready() -> void:
	# OP カードがツリーを止めるので、止まっていても動けるようにする。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = (load("res://levels/stage_1.tscn") as PackedScene).instantiate() as Node3D
	add_child(_stage)
	StageDirector.lock_started.connect(func(i: int) -> void: _shoot.call_deferred("lock%d" % i))
	StageDirector.lock_cleared.connect(func(i: int) -> void: _shoot_later("go%d" % i, 0.3))
	StageDirector.boss_started.connect(func(_b: Node3D) -> void: _shoot_later("boss", 1.2))


func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _physics_process(delta: float) -> void:
	_frames += 1
	var t := _frames / float(Engine.physics_ticks_per_second)
	# OP カードを閉じてから走り出す。
	if t >= 0.4 and not _shots.has("op_dismiss"):
		_shoot("op")
		var ev := InputEventAction.new()
		ev.action = "ui_accept"
		ev.pressed = true
		Input.parse_input_event(ev)
		var ev2 := InputEventAction.new()
		ev2.action = "ui_accept"
		ev2.pressed = true
		Input.parse_input_event.call_deferred(ev2)
		_shots.append("op_dismiss")
	if t >= 1.0 and not _shots.has("started_run"):
		_shots.append("started_run")
		_key(KEY_D, true)
	if t >= 1.2 and not _shots.has("start"):
		_shoot("start")
	# 波の敵を 2.5 秒ごとに 1 体ずつ倒して進行させる（撮影は波の最中の絵も残す）。
	if StageDirector.phase == StageDirector.Phase.LOCKED or StageDirector.phase == StageDirector.Phase.BOSS:
		_kill_timer += delta
		if _kill_timer >= 2.5:
			_kill_timer = 0.0
			if not _shots.has("wave") and StageDirector.phase == StageDirector.Phase.LOCKED:
				_shoot("wave")
			_kill_one()
	if t >= 60.0 or StageDirector.phase == StageDirector.Phase.CLEARED:
		if not _shots.has("cleared"):
			_shoot("cleared")
		get_tree().quit()


func _kill_one() -> void:
	for e in get_tree().get_nodes_in_group(&"enemy"):
		var h := (e as Node).get_node_or_null("Health") as Health
		if h != null and not h.is_downed():
			h.take_hit(h.max_hp)
			return


func _shoot_later(tag: String, seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(func() -> void: _shoot(tag))


func _shoot(tag: String) -> void:
	if _shots.has(tag):
		return
	_shots.append(tag)
	var img := get_viewport().get_texture().get_image()
	var path := "%s/qc_stage1_%s.png" % [OUT_DIR, tag]
	var err := img.save_png(path)
	print("[capture] %s -> %s (%s) t=%.1f" % [tag, path, error_string(err), _frames / 60.0])
