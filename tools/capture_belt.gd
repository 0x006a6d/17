extends Node3D

## ベルトステージの画面確認用キャプチャ（ウィンドウありで実行する。修正はしない）。
##   godot --path . --resolution 1280x720 res://tools/capture_belt.tscn
## 1.0 s: 待機、1.0〜1.5 s: D で右へ走る、2.2 s: J でパンチ、2.45 s: 命中付近。
## 各時点のビューポートを docs/img/qc_belt_*.png へ保存して終了する。

const OUT_DIR := "res://docs/img"

var _frames: int = 0
var _done: Array[String] = []


func _ready() -> void:
	var stage := (load("res://levels/belt_test.tscn") as PackedScene).instantiate()
	add_child(stage)


func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _physics_process(_delta: float) -> void:
	_frames += 1
	var t := _frames / float(Engine.physics_ticks_per_second)
	if t >= 1.0 and not _done.has("idle"):
		_shoot("idle")
		_key(KEY_D, true)
	if t >= 1.5 and not _done.has("run"):
		_shoot("run")
		_key(KEY_D, false)
	if t >= 2.2 and not _done.has("press"):
		_done.append("press")
		_key(KEY_J, true)
		_key.call_deferred(KEY_J, false)
	if t >= 2.45 and not _done.has("punch"):
		_shoot("punch")
	if t >= 2.8:
		get_tree().quit()


func _shoot(tag: String) -> void:
	_done.append(tag)
	var img := get_viewport().get_texture().get_image()
	var path := "%s/qc_belt_%s.png" % [OUT_DIR, tag]
	var err := img.save_png(path)
	print("[capture] %s -> %s (%s)" % [tag, path, error_string(err)])
