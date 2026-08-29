extends Node3D

## ニケの外見上書き（NikeSkin）の確認用キャプチャ（ウィンドウありで実行）。
##   godot --path . --resolution 1280x720 res://tools/capture_nike_head.tscn
## 左: 素の VRM（プレイヤー）、中: ヘアピン非表示（人質）、右: ヘアピン非表示＋赤シャツ（ボス）。
## 頭部アップと全身の 2 枚を docs/img/qc_nike_skin_*.png へ保存する。

const OUT_DIR := "res://docs/img"
const VRM := "res://assets/vrm/nikechan_player.vrm"
const SKIN := "res://actors/boss/nike_skin.gd"

var _frames: int = 0
var _camera: Camera3D = null
var _shots: Array[String] = []


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.12, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.75)
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	add_child(light)
	var offsets := [-0.7, 0.0, 0.7]
	for i in range(3):
		var holder := Node3D.new()
		holder.position = Vector3(offsets[i], 0.0, 0.0)
		add_child(holder)
		var model := Node3D.new()
		model.name = "Model"
		holder.add_child(model)
		model.add_child((load(VRM) as PackedScene).instantiate())
		if i >= 1:
			var skin := Node.new()
			skin.set_script(load(SKIN))
			skin.name = "NikeSkin"
			skin.set("model_path", NodePath("../Model"))
			skin.set("recolor_shirt", i == 2)
			holder.add_child(skin)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.fov = 20.0


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames == 20:
		_camera.position = Vector3(0.0, 1.42, 2.6)
		_camera.look_at(Vector3(0.0, 1.42, 0.0))
	if _frames == 30:
		_shoot("head")
	if _frames == 32:
		_camera.position = Vector3(0.0, 0.9, 5.6)
		_camera.look_at(Vector3(0.0, 0.85, 0.0))
	if _frames == 42:
		_shoot("full")
		get_tree().quit()


func _shoot(tag: String) -> void:
	_shots.append(tag)
	var img := get_viewport().get_texture().get_image()
	var path := "%s/qc_nike_skin_%s.png" % [OUT_DIR, tag]
	print("[capture] %s -> %s (%s)" % [tag, path, error_string(img.save_png(path))])
