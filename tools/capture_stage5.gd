extends Node3D

## 5面（ニケ戦）と OP カードの画面確認用キャプチャ（ウィンドウありで実行。修正はしない）。
##   godot --path . --resolution 1280x720 res://tools/capture_stage5.tscn
## 1面の OP カード → 5面のニケ戦（接近・攻撃の瞬間）→ 撃破 → ED カード を撮る。

const OUT_DIR := "res://docs/img"

var _frames: int = 0
var _shots: Array[String] = []
var _accepted: Array[String] = []
var _boss: Node3D = null
var _stage: Node3D = null
var _mode: String = "op"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = (load("res://levels/stage_1.tscn") as PackedScene).instantiate() as Node3D
	add_child(_stage)
	StageDirector.boss_started.connect(func(b: Node3D) -> void:
		_boss = b
		_shoot_later("boss_enter", 1.0)
		_shoot_later("fight_a", 3.0)
		_shoot_later("fight_b", 5.0))


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
	var t := _frames / float(Engine.physics_ticks_per_second)
	if _mode == "op":
		if t >= 1.2 and not _shots.has("op_typing"):
			_shoot("op_typing")
		if t >= 2.0 and not _accepted.has("op1"):
			_accepted.append("op1")
			_accept()
			_shoot_later("op_full", 0.2)
		if t >= 2.8:
			_mode = "stage5"
			_frames = 0
			_stage.queue_free()
			_stage = (load("res://levels/stage_5.tscn") as PackedScene).instantiate() as Node3D
			add_child(_stage)
			_key(KEY_D, true)
		return
	if t >= 2.2:
		_key(KEY_D, false)
	if t >= 7.0 and not _accepted.has("kill"):
		_accepted.append("kill")
		if _boss != null:
			var h := _boss.get_node_or_null("Health") as Health
			if h != null:
				h.take_hit(h.max_hp)
	if t >= 10.5 and not _shots.has("ed"):
		_shoot("ed")
	if t >= 11.0 and not _accepted.has("ed1"):
		_accepted.append("ed1")
		_accept()
		_shoot_later("ed_full", 0.2)
	if t >= 12.5:
		get_tree().quit()


func _shoot_later(tag: String, seconds: float) -> void:
	get_tree().create_timer(seconds, true).timeout.connect(func() -> void: _shoot(tag))


func _shoot(tag: String) -> void:
	if _shots.has(tag):
		return
	_shots.append(tag)
	var img := get_viewport().get_texture().get_image()
	var path := "%s/qc_stage5_%s.png" % [OUT_DIR, tag]
	var err := img.save_png(path)
	print("[capture] %s -> %s (%s) t=%.1f" % [tag, path, error_string(err), _frames / 60.0])
