extends Node3D

## 撃った直後に歩いたときの脚を見る。描画結果が要るので --headless では実行しない。
##   godot --path . --resolution 1280x720 tools/capture_gun_fire_walk.tscn -- --tag after
## 出力: docs/img/qc_gunfirewalk_<tag>.png（発砲からの経過フレームを横に並べた1枚）

const OUT_DIR: String = "res://docs/img"
const FRAME_SIZE: Vector2i = Vector2i(360, 560)
## 発砲してから撮るまでのフレーム数。0.130〜1.167秒の重なりを等間隔で見る。
const SHOT_FRAMES: Array[int] = [4, 12, 20, 30, 42, 56]
const WALK_SPEED: float = 4.5
const SETTLE_FRAMES: int = 30

var _viewport: SubViewport = null


func _ready() -> void:
	RunState.reset()
	_add_environment()
	_viewport = SubViewport.new()
	_viewport.size = FRAME_SIZE
	_viewport.world_3d = get_world_3d()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var camera := Camera3D.new()
	_viewport.add_child(camera)
	camera.current = true
	# 真横から。脚の入れ替わりが見たいので腰から下を大きく取る。
	camera.global_position = Vector3(0.0, 0.95, 2.6)
	camera.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)

	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() \
		as CharacterBody3D
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	# 実速度は 0 なので、本体の locomotion 更新を止めてここから歩行を与える。
	player.set_physics_process(false)
	var melee: Node = player.get_node(^"PlayerMelee")
	var weapon: Node = player.get_node(^"PlayerWeapon")
	weapon.call("equip_gun")
	for _i: int in range(SETTLE_FRAMES):
		melee.call("set_locomotion", WALK_SPEED)
		await get_tree().process_frame

	melee.call("play_gun_fire")
	var strip: Image = null
	var elapsed: int = 0
	for index: int in range(SHOT_FRAMES.size()):
		while elapsed < SHOT_FRAMES[index]:
			melee.call("set_locomotion", WALK_SPEED)
			await get_tree().process_frame
			elapsed += 1
		await RenderingServer.frame_post_draw
		var image: Image = _viewport.get_texture().get_image()
		if strip == null:
			# ビューポートの実フォーマットに合わせて確保する（blit は同一形式が要る）。
			strip = Image.create(FRAME_SIZE.x * SHOT_FRAMES.size(), FRAME_SIZE.y,
				false, image.get_format())
		strip.blit_rect(image, Rect2i(Vector2i.ZERO, FRAME_SIZE),
			Vector2i(FRAME_SIZE.x * index, 0))
	if strip == null:
		printerr("[gunfirewalk] 1枚も撮れなかった")
		get_tree().quit(1)
		return
	var path := "%s/qc_gunfirewalk_%s.png" % [OUT_DIR, _tag()]
	print("[gunfirewalk] %s (%d) フレーム=%s" % [path, strip.save_png(path), SHOT_FRAMES])
	get_tree().quit(0)


## `-- --tag <名前>` で出力名を分ける。未指定なら after。
func _tag() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size() - 1):
		if args[index] == "--tag":
			return args[index + 1]
	return "after"


func _add_environment() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	add_child(light)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.ambient_light_energy = 1.0
	environment.environment = env
	add_child(environment)
