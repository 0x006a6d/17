extends Node3D

## 各面のボスを並べて撮る QC 用キャプチャ。モデルの差し替えと武器の装着を目で確認する。
## 描画結果が要るので --headless では実行しない。
##
## 実行: godot --path . tools/capture_bosses.tscn

const OUTPUT_PATH: String = "res://docs/img/qc_bosses.png"
const CAPTURE_SIZE: Vector2i = Vector2i(1600, 700)
const SETTLE_FRAMES: int = 90
const SPACING: float = 1.6
const BOSSES: Array[Dictionary] = [
	{"label": "1面 ch35", "path": "res://actors/enemy/bosses/stage_1_boss.tscn"},
	{"label": "2面 swat 刀", "path": "res://actors/enemy/bosses/stage_2_boss.tscn"},
	{"label": "3面 ch15 ライフル", "path": "res://actors/enemy/bosses/stage_3_boss.tscn"},
	{"label": "4面 ch16_boss 拳銃", "path": "res://actors/enemy/bosses/stage_4_boss.tscn"},
]


func _ready() -> void:
	get_window().size = CAPTURE_SIZE
	RunState.reset()
	_add_environment()
	var left: float = -SPACING * float(BOSSES.size() - 1) * 0.5
	for index: int in range(BOSSES.size()):
		var entry: Dictionary = BOSSES[index]
		var scene: PackedScene = load(entry["path"] as String) as PackedScene
		if scene == null:
			printerr("[bosses] 読めない: %s" % entry["path"])
			continue
		var boss: Node3D = scene.instantiate() as Node3D
		add_child(boss)
		boss.global_position = Vector3(left + SPACING * float(index), 0.0, 0.0)
		# 撮影中に動かれると比較にならないので、行動は止めて姿勢だけ見る。
		boss.set_physics_process(false)
		print("[bosses] %s を配置" % entry["label"])

	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.global_position = Vector3(0.0, 1.15, 4.6)
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)

	for _index: int in range(SETTLE_FRAMES):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: int = image.save_png(OUTPUT_PATH)
	print("[bosses] 保存 %s (%d)" % [OUTPUT_PATH, error])
	get_tree().quit(0)


func _add_environment() -> void:
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.12, 0.15)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	environment.ambient_light_energy = 0.8
	world.environment = environment
	add_child(world)
