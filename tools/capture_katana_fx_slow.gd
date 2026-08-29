extends Node3D

## 横視点で日本刀3段コンボを動画化する。GIF化時に再生時間だけ引き伸ばす。
## 実行例:
## godot --path . --write-movie C:/.../frame.png --fixed-fps 60 \
##   res://tools/capture_katana_fx_slow.tscn

const STAGE_PATH: String = "res://levels/belt_test.tscn"
const CAPTURE_SIZE: Vector2i = Vector2i(1280, 720)
const PLAYER_START: Vector3 = Vector3(0.0, 0.2, 0.0)
const DUMMY_OFFSET: Vector3 = Vector3(1.35, 0.0, 0.0)
const PARK_POSITION: Vector3 = Vector3(80.0, 0.2, 0.0)
const CAMERA_OFFSET: Vector3 = Vector3(0.35, 1.25, 3.45)
const CAMERA_TARGET_OFFSET: Vector3 = Vector3(0.55, 0.95, 0.0)
const QUEUE_RATIO: float = 0.60
const TAIL_FRAMES: int = 24

var _stage: Node3D = null
var _player: Node3D = null
var _dummy: Node3D = null
var _weapon: Node = null
var _combo: PlayerKatanaCombo = null
var _camera: Camera3D = null
var _started: bool = false
var _queued_first: bool = false
var _queued_second: bool = false
var _finished: bool = false
var _tail_frames: int = 0


func _ready() -> void:
	get_window().size = CAPTURE_SIZE
	RunState.reset()
	_stage = (load(STAGE_PATH) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node(^"Player") as Node3D
	_player.global_position = PLAYER_START
	_player.set("_facing", 1)
	_player.set_process_unhandled_input(false)
	_weapon = _player.get_node(^"PlayerWeapon")
	_combo = _player.get_node(^"PlayerKatanaCombo") as PlayerKatanaCombo
	_combo.combo_finished.connect(_on_combo_finished)

	_dummy = _stage.get_node(^"Dummy1") as Node3D
	_dummy.global_position = PLAYER_START + DUMMY_OFFSET
	_dummy.set("knockback_speed", 0.0)
	var dummy_health := _dummy.get_node(^"Health") as Health
	dummy_health.max_hp = 1000.0
	dummy_health.revive()
	for dummy_name: String in ["Dummy2", "Dummy3"]:
		var parked := _stage.get_node_or_null(NodePath(dummy_name)) as Node3D
		if parked != null:
			parked.global_position = PARK_POSITION

	var belt_camera := _stage.get_node_or_null(^"BeltCamera") as Camera3D
	if belt_camera != null:
		belt_camera.current = false
	_camera = Camera3D.new()
	_stage.add_child(_camera)
	_camera.current = true
	_update_camera()

	_weapon.call("equip_katana")
	await _wait_frames(18)
	_combo.press()
	_started = true


func _physics_process(_delta: float) -> void:
	if not _started:
		return
	var stage_number: int = _combo.current_stage()
	var progress: float = _combo.stage_progress()
	if stage_number == 1 and not _queued_first and progress >= QUEUE_RATIO:
		_queued_first = true
		_combo.press()
	elif stage_number == 2 and not _queued_second and progress >= QUEUE_RATIO:
		_queued_second = true
		_combo.press()
	if not _finished:
		return
	_tail_frames += 1
	if _tail_frames >= TAIL_FRAMES:
		get_tree().quit(0)


func _process(_delta: float) -> void:
	_update_camera()


func _update_camera() -> void:
	if _camera == null or _player == null:
		return
	_camera.global_position = _player.global_position + CAMERA_OFFSET
	_camera.look_at(_player.global_position + CAMERA_TARGET_OFFSET, Vector3.UP)


func _on_combo_finished(completed: bool) -> void:
	if completed:
		_finished = true


func _wait_frames(frame_count: int) -> void:
	for _index: int in frame_count:
		await get_tree().process_frame
