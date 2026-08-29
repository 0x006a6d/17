extends Node3D

## 武器の握り・射撃の見え方・必殺の踏み込みを QC するためのキャプチャ。
## 描画結果が要るので --headless では実行しない。
##
## 実行:
##   godot --path . tools/capture_weapon_grip.tscn
##
## 出力（docs/img/ は qc_*.png が gitignore 済み）:
##   qc_weapon_gun_idle.png / qc_weapon_gun_hand.png
##   qc_weapon_gun_fire_*.png
##   qc_weapon_katana_idle.png / qc_weapon_katana_hand.png / qc_weapon_katana_swing_*.png
##   qc_weapon_special_*.png
## 併せて、右手ボーンと武器の位置関係、必殺中の前進量を数値で出力する。

const STAGE_PATH: String = "res://levels/belt_test.tscn"
const OUTPUT_DIRECTORY: String = "res://docs/img/"
const CAPTURE_SIZE: Vector2i = Vector2i(1280, 720)
const SETTLE_FRAMES: int = 20
const DUMMY_NAMES: Array[String] = ["Dummy1", "Dummy2", "Dummy3"]
const DUMMY_PARK_POSITION: Vector3 = Vector3(80.0, 0.2, 0.0)
const PLAYER_START: Vector3 = Vector3(0.0, 0.2, 0.0)
const ENEMY_SCENE_PATH: String = "res://actors/enemy/enemy.tscn"
## 敵の SPAWN 無敵が明けるまでの待ち。
const SPAWN_WAIT_FRAMES: int = 150

## 全身（右手側から見る。プレイヤーは +X を向くので右手はカメラ側 +Z にある）。
const BODY_CAMERA_POSITION: Vector3 = Vector3(0.6, 1.15, 3.2)
const BODY_CAMERA_TARGET: Vector3 = Vector3(0.2, 0.95, 0.0)
## 手元の寄り。右手ボーン位置をその場で見る。
const HAND_CAMERA_DISTANCE: float = 0.85
const HAND_CAMERA_LIFT: float = 0.12

var _stage: Node3D = null
var _player: Node3D = null
var _weapon: Node = null
var _holder: Node = null
var _camera: Camera3D = null
var _skeleton: Skeleton3D = null
var _right_hand_index: int = -1


func _ready() -> void:
	get_window().size = CAPTURE_SIZE
	RunState.reset()
	_stage = (load(STAGE_PATH) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	for dummy_name: String in DUMMY_NAMES:
		var dummy := _stage.get_node_or_null(NodePath(dummy_name)) as Node3D
		if dummy != null:
			dummy.global_position = DUMMY_PARK_POSITION
	_player = _stage.get_node("Player") as Node3D
	_weapon = _player.get_node("PlayerWeapon")
	_holder = _player.get_node("WeaponHolder")
	_player.global_position = PLAYER_START
	_player.set("_facing", 1)
	_resolve_skeleton()

	var belt_camera := _stage.get_node_or_null(^"BeltCamera") as Camera3D
	if belt_camera != null:
		belt_camera.current = false
	_camera = Camera3D.new()
	_stage.add_child(_camera)
	_camera.current = true

	await _settle(SETTLE_FRAMES)
	await _capture_gun()
	await _capture_katana()
	await _capture_special()
	get_tree().quit(0)


# --- 撮影 -----------------------------------------------------------------

func _capture_gun() -> void:
	_weapon.call("equip_gun")
	await _settle(SETTLE_FRAMES)
	_report_grip("gun")
	await _shoot_body("qc_weapon_gun_idle.png")
	await _shoot_hand("qc_weapon_gun_hand.png")
	# 射撃の見え方。撃った瞬間から数フレームぶん連続で撮る。
	_send_action("fire")
	for frame_index: int in [1, 3, 6, 10]:
		await _advance_to_frame(frame_index)
		await _shoot_body("qc_weapon_gun_fire_%02d.png" % frame_index)


func _capture_katana() -> void:
	_weapon.call("equip_katana")
	await _settle(SETTLE_FRAMES)
	_report_grip("katana")
	await _shoot_body("qc_weapon_katana_idle.png")
	await _shoot_hand("qc_weapon_katana_hand.png")
	# 実戦に近い形の独立確認: 通常どおり生成した敵（物理を止めない・SPAWN 明けを待つ）を
	# 正面に置き、3段が実際に HP を削るかをテストとは別経路で測る。
	var enemy: Node3D = (load(ENEMY_SCENE_PATH) as PackedScene).instantiate() as Node3D
	_stage.add_child(enemy)
	enemy.global_position = _player.global_position + Vector3(1.2, 0.0, 0.0)
	var enemy_health: Node = enemy.get_node_or_null(^"Health")
	for _index: int in range(SPAWN_WAIT_FRAMES):
		await get_tree().physics_frame
	var hp_before: float = float(enemy_health.call("current_hp"))
	print("[katana] 敵HP 斬撃前=%.0f" % hp_before)

	# 3段コンボ。初段 0.500s / 二段 0.600s / 三段 0.750s = 合計 1.850s ≒ 111 フレーム。
	# 押下は 0 / 18 / 50 フレーム（各段の受付窓の内側）。
	var press_frames: Array[int] = [0, 18, 50]
	var shot_frames: Array[int] = [3, 9, 15, 21, 27, 33, 42, 51, 60, 69, 78, 87, 96, 105]
	_elapsed_frames = 0
	for frame_index: int in range(0, 112):
		if press_frames.has(frame_index):
			_press("fire")
		if shot_frames.has(frame_index):
			await _shoot_hand("qc_weapon_katana_combo_%03d.png" % frame_index)
		if frame_index in [33, 69, 105]:
			print("[katana] frame=%d 敵HP=%.0f 累計ダメージ=%.0f" % [
				frame_index, float(enemy_health.call("current_hp")),
				hp_before - float(enemy_health.call("current_hp"))
			])
		await get_tree().physics_frame
		_elapsed_frames += 1
	# 必殺の踏み込み計測を邪魔しないよう、確認用の敵は片付ける。
	enemy.queue_free()
	await _settle(SETTLE_FRAMES)


func _capture_special() -> void:
	_weapon.call("equip_gun")
	_player.global_position = PLAYER_START
	await _settle(SETTLE_FRAMES)
	var start_x: float = _player.global_position.x
	_send_action("special")
	# 必殺は 2.000 秒（接触 1.280 秒）。開始から終わりまでを等間隔で見る。
	for frame_index: int in [6, 20, 40, 60, 77, 100, 120] :
		await _advance_to_frame(frame_index)
		var elapsed: float = float(frame_index) / float(Engine.physics_ticks_per_second)
		print("[special] frame=%d elapsed=%.3fs x=%.3f advance=%.3fm" % [
			frame_index, elapsed, _player.global_position.x,
			_player.global_position.x - start_x
		])
		await _shoot_body("qc_weapon_special_%03d.png" % frame_index)
	print("[special] total_advance=%.3fm" % (_player.global_position.x - start_x))


# --- 計測 -----------------------------------------------------------------

func _report_grip(label: String) -> void:
	var weapon_node: Node3D = _find_weapon_node()
	if _skeleton == null or _right_hand_index < 0 or weapon_node == null:
		print("[grip] %s: 右手ボーンまたは武器ノードを取得できない" % label)
		return
	var hand_transform: Transform3D = _skeleton.global_transform \
		* _skeleton.get_bone_global_pose(_right_hand_index)
	var hand_position: Vector3 = hand_transform.origin
	var weapon_aabb: AABB = _visual_bounds(weapon_node)
	print("[grip] %s hand=(%.3f, %.3f, %.3f) weapon_origin=(%.3f, %.3f, %.3f) offset=%.3fm" % [
		label, hand_position.x, hand_position.y, hand_position.z,
		weapon_node.global_position.x, weapon_node.global_position.y,
		weapon_node.global_position.z,
		hand_position.distance_to(weapon_node.global_position)
	])
	print("[grip] %s weapon_aabb_size=(%.3f, %.3f, %.3f) center=(%.3f, %.3f, %.3f)" % [
		label, weapon_aabb.size.x, weapon_aabb.size.y, weapon_aabb.size.z,
		weapon_aabb.get_center().x, weapon_aabb.get_center().y, weapon_aabb.get_center().z
	])


func _visual_bounds(root: Node3D) -> AABB:
	var bounds: AABB = AABB()
	var initialized: bool = false
	for node: Node in _descendants(root):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var world_aabb: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		if initialized:
			bounds = bounds.merge(world_aabb)
		else:
			bounds = world_aabb
			initialized = true
	return bounds


func _descendants(root: Node) -> Array[Node]:
	var found: Array[Node] = [root]
	for child: Node in root.get_children():
		found.append_array(_descendants(child))
	return found


func _find_weapon_node() -> Node3D:
	# WeaponHolder が装着した実体をそのまま貰う（VRM 側の別 BoneAttachment3D を拾わないため）。
	if _holder == null or not _holder.has_method("current_weapon"):
		return null
	return _holder.call("current_weapon") as Node3D


func _resolve_skeleton() -> void:
	var model := _player.get_node_or_null(^"Model")
	if model == null:
		return
	for node: Node in _descendants(model):
		var skeleton := node as Skeleton3D
		if skeleton != null:
			_skeleton = skeleton
			break
	if _skeleton != null:
		_right_hand_index = _skeleton.find_bone(&"RightHand")


# --- 撮影の下回り ---------------------------------------------------------

func _shoot_body(file_name: String) -> void:
	_camera.global_position = _player.global_position + BODY_CAMERA_POSITION
	_camera.look_at(_player.global_position + BODY_CAMERA_TARGET, Vector3.UP)
	await _save(file_name)


func _shoot_hand(file_name: String) -> void:
	var target: Vector3 = _player.global_position + Vector3(0.0, 1.0, 0.0)
	if _skeleton != null and _right_hand_index >= 0:
		var hand_transform: Transform3D = _skeleton.global_transform \
			* _skeleton.get_bone_global_pose(_right_hand_index)
		target = hand_transform.origin
	_camera.global_position = target + Vector3(0.25, HAND_CAMERA_LIFT, HAND_CAMERA_DISTANCE)
	_camera.look_at(target, Vector3.UP)
	await _save(file_name)


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = OUTPUT_DIRECTORY + file_name
	var error: int = image.save_png(path)
	if error != OK:
		printerr("[capture] 保存できない: %s (%d)" % [path, error])
	else:
		print("[capture] %s" % path)


func _settle(frames: int) -> void:
	for _index: int in range(frames):
		await get_tree().process_frame


func _advance_to_frame(target_frame: int) -> void:
	# 直前の _advance_to_frame からの相対ではなく、押下からの累積フレーム数で待つ。
	while _elapsed_frames < target_frame:
		await get_tree().physics_frame
		_elapsed_frames += 1


var _elapsed_frames: int = 0


func _send_action(action_name: String) -> void:
	_elapsed_frames = 0
	_press(action_name)


## 押下だけを送る（経過フレーム数は呼び出し側が持つ）。
func _press(action_name: String) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	Input.parse_input_event(event)
