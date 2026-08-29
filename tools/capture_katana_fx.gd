extends Node3D

## 刀エフェクトを各段の接触付近で撮影する目視 QC。
## 実行: godot --path . tools/capture_katana_fx.tscn

const STAGE_PATH: String = "res://levels/belt_test.tscn"
const OUTPUT_DIRECTORY: String = "res://docs/img/"
const CAPTURE_SIZE: Vector2i = Vector2i(1280, 720)
const PLAYER_START: Vector3 = Vector3(0.0, 0.2, 0.0)
const DUMMY_PARK_POSITION: Vector3 = Vector3(80.0, 0.2, 0.0)
const CAMERA_OFFSET: Vector3 = Vector3(0.35, 1.25, 3.45)
const OBLIQUE_CAMERA_OFFSET: Vector3 = Vector3(2.70, 1.65, 2.80)
const CAMERA_TARGET_OFFSET: Vector3 = Vector3(0.20, 0.95, 0.0)
const PRESS_FRAMES: Array[int] = [0, 18, 50]
const SHOT_FRAMES: Array[int] = [12, 44, 78, 84, 90, 96]
const OBLIQUE_SHOT_FRAMES: Array[int] = [12, 44, 84]

var _stage: Node3D = null
var _player: Node3D = null
var _weapon: Node = null
var _katana_fx: Node = null
var _katana_combo: Node = null
var _camera: Camera3D = null


func _ready() -> void:
	get_window().size = CAPTURE_SIZE
	RunState.reset()
	_stage = (load(STAGE_PATH) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	for dummy_name: String in ["Dummy1", "Dummy2", "Dummy3"]:
		var dummy := _stage.get_node_or_null(NodePath(dummy_name)) as Node3D
		if dummy != null:
			dummy.global_position = DUMMY_PARK_POSITION
	_player = _stage.get_node(^"Player") as Node3D
	_weapon = _player.get_node(^"PlayerWeapon")
	_katana_fx = _player.get_node(^"PlayerKatanaSwing3D")
	_katana_combo = _player.get_node(^"PlayerKatanaCombo")
	_player.global_position = PLAYER_START
	_player.set("_facing", 1)
	var belt_camera := _stage.get_node_or_null(^"BeltCamera") as Camera3D
	if belt_camera != null:
		belt_camera.current = false
	_camera = Camera3D.new()
	_stage.add_child(_camera)
	_camera.current = true
	_weapon.call("equip_katana")
	await _settle(24)
	await _capture_combo()
	get_tree().quit(0)


func _capture_combo() -> void:
	for frame_index: int in range(112):
		if PRESS_FRAMES.has(frame_index):
			_press(&"fire")
		await get_tree().physics_frame
		if SHOT_FRAMES.has(frame_index):
			var stage_number: int = int(_katana_fx.call("active_stage"))
			var swing_visible: bool = bool(_katana_fx.call("swing_arc_visible"))
			var arc_visible: bool = bool(_katana_fx.call("final_arc_visible"))
			var blade_direction: Vector3 = _katana_fx.call("debug_blade_direction")
			var plane_normal: Vector3 = _katana_fx.call("debug_plane_normal")
			var progress: float = float(_katana_combo.call("stage_progress"))
			var contact: float = float(_katana_combo.call(
				"stage_contact_ratio", stage_number))
			print("[katana_fx] frame=%d stage=%d progress=%.3f contact=%.3f swing_arc=%s final_arc=%s blade=%s plane=%s" % [
				frame_index, stage_number, progress, contact,
				str(swing_visible), str(arc_visible),
				str(blade_direction), str(plane_normal),
			])
			await _shoot("qc_katana_fx_%03d.png" % frame_index)
			if OBLIQUE_SHOT_FRAMES.has(frame_index):
				await _shoot("qc_katana_fx_%03d_oblique.png" % frame_index,
					OBLIQUE_CAMERA_OFFSET)


func _shoot(file_name: String, camera_offset: Vector3 = CAMERA_OFFSET) -> void:
	var previous_process_mode: int = _player.process_mode
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_camera.global_position = _player.global_position + camera_offset
	_camera.look_at(_player.global_position + CAMERA_TARGET_OFFSET, Vector3.UP)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = OUTPUT_DIRECTORY + file_name
	var error: int = image.save_png(path)
	if error != OK:
		printerr("[capture] 保存できない: %s (%d)" % [path, error])
	else:
		print("[capture] %s" % path)
	_player.process_mode = previous_process_mode


func _press(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event.call_deferred(release)


func _settle(frame_count: int) -> void:
	for _index: int in frame_count:
		await get_tree().process_frame
