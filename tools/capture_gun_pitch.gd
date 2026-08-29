extends Node3D

## 銃身の傾きを真横から撮る（プレイヤーの構えと歩行、4面ボスの構え）。
## 握りの角度を変えたときの確認に使う。描画結果が要るので --headless では実行しない。
##   godot --path . --resolution 900x600 tools/capture_gun_pitch.tscn -- --tag before

const OUT_DIR: String = "res://docs/img"
const SIZE: Vector2i = Vector2i(900, 600)
const SETTLE: int = 30

var _viewport: SubViewport = null
var _camera: Camera3D = null


func _ready() -> void:
	RunState.reset()
	_add_environment()
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.world_3d = get_world_3d()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_camera = Camera3D.new()
	_viewport.add_child(_camera)
	_camera.current = true

	var stage := (load("res://levels/belt_test.tscn") as PackedScene).instantiate() as Node3D
	add_child(stage)
	for dummy_name: String in ["Dummy1", "Dummy2", "Dummy3"]:
		var dummy := stage.get_node_or_null(NodePath(dummy_name)) as Node3D
		if dummy != null:
			dummy.global_position = Vector3(80.0, 0.2, 0.0)
	var player := stage.get_node(^"Player") as CharacterBody3D
	await _wait(4)
	player.get_node(^"PlayerWeapon").call("equip_gun")
	await _wait(SETTLE)
	await _shoot(player.get_node(^"WeaponHolder") as WeaponHolder, "player")
	# 歩いているところ。握りの補正は本体の速度から決まるので、実際に歩かせる。
	Input.action_press(&"move_right")
	await _wait(SETTLE)
	await _shoot(player.get_node(^"WeaponHolder") as WeaponHolder, "playerwalk")
	Input.action_release(&"move_right")
	stage.queue_free()
	await _wait(2)

	var boss := (load("res://actors/enemy/bosses/stage_4_boss.tscn") as PackedScene) \
		.instantiate() as Node3D
	add_child(boss)
	await _wait(4)
	boss.set_physics_process(false)
	var animator := boss.get_node_or_null(^"Animator") as NpcAnimator
	if animator != null and animator.is_active():
		animator.play(NpcAnimator.Clip.IDLE, 0.0, 1.0, true)
	await _wait(SETTLE)
	await _shoot(boss.get_node_or_null(^"WeaponHolder") as WeaponHolder, "boss4")
	get_tree().quit(0)


## 武器を画面いっぱいに入れて真横から撮る。
func _shoot(holder: WeaponHolder, key: String) -> void:
	var weapon: Node3D = holder.current_weapon() if holder != null else null
	if weapon == null:
		printerr("[gunpitch] %s: 武器なし" % key)
		return
	var center: Vector3 = weapon.global_position
	# 銃身の水平向きに直交する側から見る（キャラの向きに依らず真横になる）。
	var barrel: Vector3 = weapon.global_transform.basis.x
	var flat := Vector3(barrel.x, 0.0, barrel.z)
	if flat.is_zero_approx():
		flat = Vector3.RIGHT
	flat = flat.normalized()
	var side := Vector3(-flat.z, 0.0, flat.x)
	_camera.global_position = center + side * 0.75
	_camera.look_at(center, Vector3.UP)
	_camera.fov = 40.0
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	var path := "%s/qc_gunpitch_%s_%s.png" % [OUT_DIR, key, _tag()]
	print("[gunpitch] %s (%d)" % [path, image.save_png(path)])
	# 握りの寄り。手と柄の噛み合いを見る。
	_camera.global_position = center + side * 0.26
	_camera.look_at(center, Vector3.UP)
	await RenderingServer.frame_post_draw
	var zoom: Image = _viewport.get_texture().get_image()
	var zoom_path := "%s/qc_gungrip_%s_%s.png" % [OUT_DIR, key, _tag()]
	print("[gungrip] %s (%d)" % [zoom_path, zoom.save_png(zoom_path)])


func _tag() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size() - 1):
		if args[index] == "--tag":
			return args[index + 1]
	return "before"


func _add_environment() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
	add_child(light)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.11, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.ambient_light_energy = 1.0
	environment.environment = env
	add_child(environment)


func _wait(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame
