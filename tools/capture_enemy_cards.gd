extends Node3D

## 敵を 1 体ずつ正面から撮る（敵一覧の資料用）。描画結果が要るので --headless では実行しない。
##   godot --path . --resolution 700x900 res://tools/capture_enemy_cards.tscn
## 出力: docs/img/qc_enemy_<key>.png

const OUT_DIR := "res://docs/img"
const SETTLE_FRAMES := 60
const ENEMIES: Array[Dictionary] = [
	{"key": "grunt_a", "path": "res://actors/enemy/enemy.tscn"},
	{"key": "grunt_b", "path": "res://actors/enemy/roles/grunt_b.tscn"},
	{"key": "grunt_c", "path": "res://actors/enemy/roles/grunt_c.tscn"},
	{"key": "rusher", "path": "res://actors/enemy/roles/rusher.tscn"},
	{"key": "grunt_a_black", "path": "res://actors/enemy/roles/grunt_a_black.tscn"},
	{"key": "grunt_b_pink", "path": "res://actors/enemy/roles/grunt_b_pink.tscn"},
	{"key": "grunt_c_yellow", "path": "res://actors/enemy/roles/grunt_c_yellow.tscn"},
	{"key": "rusher_red", "path": "res://actors/enemy/roles/rusher_red.tscn"},
	{"key": "zombie_escort", "path": "res://actors/enemy/roles/zombie_escort.tscn"},
	{"key": "final_guard", "path": "res://actors/enemy/roles/final_guard.tscn"},
	{"key": "nike_blank", "path": "res://actors/enemy/roles/nike_blank.tscn", "yaw": -90.0},
	{"key": "boss1", "path": "res://actors/enemy/bosses/stage_1_boss.tscn"},
	{"key": "boss2", "path": "res://actors/enemy/bosses/stage_2_boss.tscn"},
	{"key": "boss3", "path": "res://actors/enemy/bosses/stage_3_boss.tscn", "yaw": -90.0},
	{"key": "boss4", "path": "res://actors/enemy/bosses/stage_4_boss.tscn"},
	{"key": "nike", "path": "res://actors/boss/nike.tscn", "yaw": -90.0},
]


const CARD_SIZE := Vector2i(600, 900)

var _viewport: SubViewport = null


func _ready() -> void:
	RunState.reset()
	_add_environment()
	# ウィンドウ寸法に依存しないよう、縦長の SubViewport（同じワールドを共有）に描いて保存する。
	_viewport = SubViewport.new()
	_viewport.size = CARD_SIZE
	_viewport.world_3d = get_world_3d()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var camera := Camera3D.new()
	_viewport.add_child(camera)
	camera.current = true
	camera.global_position = Vector3(0.0, 1.0, 2.1)
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	for entry in ENEMIES:
		var scene := load(entry["path"] as String) as PackedScene
		if scene == null:
			printerr("[enemy_cards] 読めない: %s" % entry["path"])
			continue
		var enemy := scene.instantiate() as Node3D
		add_child(enemy)
		enemy.global_position = Vector3.ZERO
		# 敵は -Z を正面にしているので、+Z 側のカメラへ向ける。
		enemy.rotation_degrees.y = float(entry.get("yaw", 180.0))
		# 行動は止めて姿勢だけ見る。敵本体が Animator に IDLE を指示する構造なので、
		# 止めた分をここで補う（Animator 自体は自分の _physics_process で進む）。
		enemy.set_physics_process(false)
		await get_tree().process_frame
		var animator := enemy.get_node_or_null(^"Animator") as NpcAnimator
		if animator != null and animator.is_active():
			animator.play(NpcAnimator.Clip.IDLE, 0.0, 1.0, true)
		for _i: int in range(SETTLE_FRAMES):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = _viewport.get_texture().get_image()
		var path := "%s/qc_enemy_%s.png" % [OUT_DIR, entry["key"]]
		var error: int = image.save_png(path)
		print("[enemy_cards] %s -> %s (%d)" % [entry["key"], path, error])
		enemy.queue_free()
		await get_tree().process_frame
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
