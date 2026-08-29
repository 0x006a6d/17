extends Node

## ベルトスクロール化（8/23）の検証。
##   godot --path . --headless res://tools/test_belt_depth.tscn
##
##   (1) 奥行きが揃った相手には判定が当たり、hit_landed が 1 回出る
##   (2) 判定球に重なっていても奥行きが depth_tolerance を超える相手には当たらず、
##       hit_landed も出ない
##   (3) D で +X へ進み向きが +X（Model ヨー +90°）、A で -X へ進み向きが -X
##   (4) W で奥へ進み belt_z_min で止まる。S で手前へ進み belt_z_max で止まる
##   (5) 画面端より外へ出られない（BeltCamera の left_limit/right_limit）

const STAGE := "res://levels/belt_test.tscn"
const SETTLE_FRAMES := 12
const MAX_FRAMES := 2000

var _pass: int = 0
var _fail: int = 0
var _stage: Node3D = null
var _player: Node3D = null
var _model: Node3D = null
var _camera: Node3D = null
var _near: Node3D = null
var _far: Node3D = null
var _near_health: Health = null
var _far_health: Health = null
var _landed: int = 0
var _frames: int = 0
var _phase: int = 0
var _phase_started: int = 0
var _x_before: float = 0.0


func _ready() -> void:
	print("=== ベルトスクロール 段移動・奥行き判定 検証開始 ===")
	var packed := load(STAGE) as PackedScene
	if packed == null:
		_fatal("belt_test load 失敗")
		return
	_stage = packed.instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node_or_null("Player") as Node3D
	_camera = _stage.get_node_or_null("BeltCamera") as Node3D
	_near = _stage.get_node_or_null("Dummy1") as Node3D
	_far = _stage.get_node_or_null("Dummy2") as Node3D
	if _player == null or _near == null or _far == null or _camera == null:
		_fatal("Player / Dummy1 / Dummy2 / BeltCamera が見つからない")
		return
	_model = _player.get_node_or_null("Model") as Node3D
	_near_health = _near.get_node_or_null("Health") as Health
	_far_health = _far.get_node_or_null("Health") as Health
	var hitbox := _player.get_node_or_null("Model/MeleeHitbox") as Hitbox
	hitbox.hit_landed.connect(func(_t: Node3D) -> void: _landed += 1)


func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > MAX_FRAMES:
		_assert("全ケースが MAX_FRAMES 内に完了した (phase=%d)" % _phase, false)
		_finish()
		return
	if _frames < 6:
		return
	var local := _frames - _phase_started
	match _phase:
		0:
			# 判定球（Model ローカル (0, 1.2, 0.5)、r=0.45。+X 向きで本体の +0.5 X）に
			# 近い側のダミーは同じ奥行き、遠い側は 0.7 m 奥へずらして重ねる。
			_player.global_position = Vector3(2.0, 0.2, 0.0)
			_near.global_position = Vector3(2.8, 0.2, 0.0)
			_far.global_position = Vector3(2.5, 0.2, 0.7)
			_advance(1)
		1:
			if local == 1:
				_player.call("_enable_hitbox", 10.0, 2.0)
			if local >= SETTLE_FRAMES:
				_player.call("_disable_hitbox")
				_assert("(1) 奥行きが揃ったダミーに当たる",
					_near_health.current_hp() < _near_health.max_hp)
				_assert("(2) 0.7 m 奥のダミーには当たらない",
					is_equal_approx(_far_health.current_hp(), _far_health.max_hp))
				_assert("(1)(2) hit_landed はちょうど 1 回 (実測 %d)" % _landed, _landed == 1)
				_near.global_position = Vector3(30.0, 0.2, 0.0)
				_far.global_position = Vector3(30.0, 0.2, 1.2)
				_x_before = _player.global_position.x
				_key(KEY_D, true)
				_advance(2)
		2:
			if local >= 40:
				_key(KEY_D, false)
				var moved := _player.global_position.x - _x_before
				_assert("(3) D で +X へ進む (%.2f m)" % moved, moved > 1.0)
				_assert("(3) 向きが +X", int(_player.call("facing")) == 1)
				_assert("(3) Model ヨーが +90° (%.1f°)" % rad_to_deg(_model.rotation.y),
					absf(angle_difference(_model.rotation.y, PI * 0.5)) < deg_to_rad(3.0))
				_x_before = _player.global_position.x
				_key(KEY_A, true)
				_advance(3)
		3:
			# 反転は accel=10 m/s² で 4.5→-4.5 に 0.9 s 掛かるため、窓は 90 フレーム取る。
			if local >= 90:
				_key(KEY_A, false)
				var moved := _x_before - _player.global_position.x
				_assert("(3) A で -X へ進む (%.2f m)" % moved, moved > 1.0)
				_assert("(3) 向きが -X", int(_player.call("facing")) == -1)
				_assert("(3) Model ヨーが -90° (%.1f°)" % rad_to_deg(_model.rotation.y),
					absf(angle_difference(_model.rotation.y, -PI * 0.5)) < deg_to_rad(3.0))
				_key(KEY_W, true)
				_advance(4)
		4:
			if local >= 150:
				_key(KEY_W, false)
				var z := _player.global_position.z
				_assert("(4) W で奥へ進み belt_z_min=-1.5 で止まる (z=%.2f)" % z,
					absf(z - (-1.5)) < 0.05)
				_key(KEY_S, true)
				_advance(5)
		5:
			if local >= 300:
				_key(KEY_S, false)
				var z := _player.global_position.z
				_assert("(4) S で手前へ進み belt_z_max=1.5 で止まる (z=%.2f)" % z,
					absf(z - 1.5) < 0.05)
				# 画面端: カメラを x=0 に固定し、左へ走らせる。
				_camera.call("lock_at", 0.0)
				_player.global_position = Vector3(0.0, 0.2, 0.0)
				_key(KEY_A, true)
				_advance(6)
		6:
			if local >= 150:
				_key(KEY_A, false)
				var left: float = float(_camera.call("left_limit"))
				var x := _player.global_position.x
				_assert("(5) 画面左端より外へ出ない (x=%.2f, left=%.2f)" % [x, left],
					x >= left - 0.01)
				_assert("(5) 画面端で止まっている (x - left < 1.0)", x - left < 1.0)
				_camera.call("unlock")
				_finish()


func _advance(phase: int) -> void:
	_phase = phase
	_phase_started = _frames


func _assert(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[PASS] " + label)
	else:
		_fail += 1
		print("[FAIL] " + label)


func _fatal(msg: String) -> void:
	print("[FATAL] " + msg)
	_fail += 1
	_finish()


func _finish() -> void:
	set_physics_process(false)
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)
