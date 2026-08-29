extends Node3D

## 武器の握り（オフセット・回転）を決めるための総当たり撮影。
## 武器モデルのローカル軸を実測してから、候補の回転で装着して手元を撮る。
## 描画結果が要るので --headless では実行しない。
##
## 実行:
##   godot --path . tools/capture_grip_sweep.tscn
##   godot --path . tools/capture_grip_sweep.tscn -- --weapon katana

const STAGE_PATH: String = "res://levels/belt_test.tscn"
const OUTPUT_DIRECTORY: String = "res://docs/img/"
const CAPTURE_SIZE: Vector2i = Vector2i(720, 720)
const SETTLE_FRAMES: int = 12
const DUMMY_NAMES: Array[String] = ["Dummy1", "Dummy2", "Dummy3"]
const DUMMY_PARK_POSITION: Vector3 = Vector3(80.0, 0.2, 0.0)
const PISTOL_PATH: String = "res://assets/weapons/pistol.glb"
const KATANA_PATH: String = "res://assets/weapons/katana.glb"

## 候補の回転（度）。現行値を先頭に置き、各軸 ±90 / 180 を組み合わせる。
const PISTOL_ROTATIONS: Array[Vector3] = [
	Vector3(0, -90, 0), Vector3(90, -90, 0), Vector3(-90, -90, 0), Vector3(180, -90, 0),
	Vector3(0, -90, 90), Vector3(0, -90, -90), Vector3(0, 90, 0), Vector3(90, 90, 0),
	Vector3(0, 0, 0), Vector3(90, 0, 0), Vector3(-90, 0, 0), Vector3(0, 180, 0),
]
const KATANA_ROTATIONS: Array[Vector3] = [
	Vector3(90, 0, 0), Vector3(-90, 0, 0), Vector3(90, 90, 0), Vector3(90, -90, 0),
	Vector3(90, 180, 0), Vector3(0, 0, 0), Vector3(0, 90, 0), Vector3(0, -90, 0),
	Vector3(180, 0, 0), Vector3(90, 0, 90), Vector3(90, 0, -90), Vector3(0, 0, 90),
]

var _stage: Node3D = null
var _player: Node3D = null
var _weapon: Node = null
var _holder: Node = null
var _camera: Camera3D = null
var _skeleton: Skeleton3D = null
var _right_hand_index: int = -1
var _weapon_kind: String = "pistol"
## 手のひら中心から外へ逃がす距離（m）。武器メッシュが手へめり込むのを避ける。
var palm_clearance: float = 0.0
## 手首→中指付け根のどこを手のひら中心とみなすか（0=手首、1=付け根）。
var palm_ratio: float = 0.15
## 握り軸のどこを握るか（0=上端／鍔側、1=下端／柄頭側）。
var grip_axis_ratio: float = 0.35
var _flip_blade: bool = false
var _offset_grid: bool = false
var _measure_only: bool = false
var _nudge_grid: bool = false
var _extreme_test: bool = false
var _little_sweep: bool = false
var _clearance_sweep: bool = false
var _scale_sweep: bool = false
## 現行の逃がし量（銃 0.016 / 刀 0.008）。ここからの差分を振る。
var _base_clearance: float = 0.016


func _ready() -> void:
	_parse_options(OS.get_cmdline_user_args())
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
	_player.global_position = Vector3(0.0, 0.2, 0.0)
	_player.set("_facing", 1)
	_resolve_skeleton()

	var belt_camera := _stage.get_node_or_null(^"BeltCamera") as Camera3D
	if belt_camera != null:
		belt_camera.current = false
	_camera = Camera3D.new()
	_stage.add_child(_camera)
	_camera.current = true
	_camera.fov = 40.0

	# PlayerMelee が AnimationTree を組み終えてから装備しないと、
	# 銃 locomotion の解除が反映されず膝立ちのままになる。
	for _index: int in range(90):
		await get_tree().physics_frame
	if _weapon_kind == "katana":
		_weapon.call("equip_katana")
	elif _weapon_kind == "none":
		_weapon.call("unequip")
	else:
		_weapon.call("equip_gun")
	for _index: int in range(90):
		await get_tree().physics_frame

	if _nudge_grid:
		await _sweep_nudge()
		get_tree().quit(0)
		return
	if _scale_sweep:
		var path3: String = KATANA_PATH if _weapon_kind == "katana" else PISTOL_PATH
		var scene3: PackedScene = load(path3) as PackedScene
		var index3: int = 0
		for weapon_scale: float in [0.50, 0.45, 0.40, 0.35]:
			_solve_grip()
			# scale を変えると握り点も比例して動くので、オフセットを掛け直す。
			var base_scale: float = 0.50 if _weapon_kind == "katana" else 0.12
			var scaled_offset: Vector3 = _solved_offset * (weapon_scale / base_scale)
			_holder.call("equip", scene3, scaled_offset, _solved_rotation, weapon_scale)
			await _settle(4)
			print("[scale] %.2f offset=(%.4f, %.4f, %.4f)" % [
				weapon_scale, scaled_offset.x, scaled_offset.y, scaled_offset.z])
			await _measure_after_modifier()
			var target3: Vector3 = _hand_position()
			_camera.global_position = target3 + Vector3(0.30, 0.10, 0.42)
			_camera.look_at(target3, Vector3.UP)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				OUTPUT_DIRECTORY + "qc_scale_%s_%02d.png" % [_weapon_kind, index3])
			index3 += 1
		get_tree().quit(0)
		return
	if _clearance_sweep:
		_base_clearance = 0.008 if _weapon_kind == "katana" else 0.016
		var path2: String = KATANA_PATH if _weapon_kind == "katana" else PISTOL_PATH
		var scene2: PackedScene = load(path2) as PackedScene
		var scale2: Vector3 = Vector3(0.40, 0.40, 0.50) if _weapon_kind == "katana" else Vector3(0.12, 0.12, 0.12)
		var index2: int = 0
		for clearance: float in [_base_clearance, _base_clearance + 0.006, _base_clearance + 0.012, _base_clearance + 0.018]:
			palm_clearance = clearance
			_solve_grip()
			_holder.call("equip", scene2, _solved_offset, _solved_rotation, scale2)
			await _settle(3)
			print("[clear] %02d clearance=%+.3f offset=(%.4f, %.4f, %.4f)" % [
				index2, clearance, _solved_offset.x, _solved_offset.y, _solved_offset.z])
			var target2: Vector3 = _hand_position()
			var weapon2: Node3D = _holder.call("current_weapon") as Node3D
			if weapon2 != null:
				target2 = weapon2.global_transform * _measure_grip_point(path2)
			_camera.global_position = target2 + Vector3(0.30, 0.10, 0.42)
			_camera.look_at(target2, Vector3.UP)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				OUTPUT_DIRECTORY + "qc_clear_%s_%02d.png" % [_weapon_kind, index2])
			index2 += 1
		get_tree().quit(0)
		return
	if _little_sweep:
		var grip: Node = _player.get_node_or_null(^"PlayerWeaponGrip")
		if grip == null:
			print("[little] PlayerWeaponGrip が無い")
			get_tree().quit(1)
			return
		var base: Vector3 = grip.get("katana_little_curl")
		print("[little] 現在値=(%.0f, %.0f, %.0f)" % [base.x, base.y, base.z])
		for inter: float in [45.0, 55.0, 65.0, 75.0]:
			for dist: float in [10.0, 20.0, 30.0]:
				grip.set("katana_little_curl", Vector3(base.x, inter, dist))
				grip.call("use_katana_grip")
				for _index: int in range(4):
					await get_tree().physics_frame
				print("[little] 第2関節=%.0f 指先=%.0f →" % [inter, dist])
				_report_finger_wrap("小指探索")
		get_tree().quit(0)
		return
	if _extreme_test:
		# modifier が本当に効いているかの切り分け: 極端な角度を入れて描画が変わるか見る。
		var grip: Node = _player.get_node_or_null(^"PlayerWeaponGrip")
		if grip != null:
			grip.set("katana_index_curl", Vector3(90.0, 90.0, 90.0))
			grip.set("katana_middle_curl", Vector3(90.0, 90.0, 90.0))
			grip.set("katana_ring_curl", Vector3(90.0, 90.0, 90.0))
			grip.set("katana_little_curl", Vector3(90.0, 90.0, 90.0))
			grip.call("use_katana_grip")
			print("[extreme] 90度を適用した")
		for _index: int in range(30):
			await get_tree().physics_frame
		_report_finger_wrap("極端角度")
		await _shoot_angles()
		get_tree().quit(0)
		return
	if _measure_only:
		_report_grip_error(_weapon_kind)
		if _weapon_kind == "katana":
			_report_blade_clearance("実装値")
		# 指の上書きは SkeletonModifier3D の modification_processed で当たるので、
		# そのシグナルの中（＝上書き後の姿勢）で測る。
		await _measure_after_modifier()
		await _shoot_angles()
		get_tree().quit(0)
		return
	if _offset_grid:
		await _sweep_offsets()
		get_tree().quit(0)
		return
	_report_model_axes()
	_measure_grip_axis(KATANA_PATH if _weapon_kind == "katana" else PISTOL_PATH)
	# 待機モーションへのブレンドが終わるまで待ってから、複数フレームで解いて収束を見る。
	for _index: int in range(120):
		await get_tree().physics_frame
	for sample: int in range(8):
		_solve_grip()
		for _index: int in range(6):
			await get_tree().physics_frame
	# 候補撮影は同一ポーズで比較したいので、ここで時間を止める。
	_freeze_pose()
	await _sweep()
	get_tree().quit(0)


## 待機ポーズを固定する（全候補を同一ポーズ・同一画角で撮るため）。
func _freeze_pose() -> void:
	# AnimationTree.active=false だと rest ポーズへ戻ってしまうので、時間だけ止める。
	Engine.time_scale = 0.0
	print("[freeze] time_scale=0 で待機ポーズを保持した")


func _parse_options(args: PackedStringArray) -> void:
	for index: int in range(args.size()):
		if args[index] == "--weapon" and index + 1 < args.size():
			_weapon_kind = args[index + 1]
		if args[index] == "--flip":
			_flip_blade = true
		if args[index] == "--offsets":
			_offset_grid = true
		if args[index] == "--measure":
			_measure_only = true
		if args[index] == "--nudge":
			_nudge_grid = true
		if args[index] == "--extreme":
			_extreme_test = true
		if args[index] == "--little":
			_little_sweep = true
		if args[index] == "--clear":
			_clearance_sweep = true
		if args[index] == "--scale":
			_scale_sweep = true


# --- モデルのローカル軸を測る -------------------------------------------

func _report_model_axes() -> void:
	var path: String = KATANA_PATH if _weapon_kind == "katana" else PISTOL_PATH
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		print("[axes] %s を読めない" % path)
		return
	var probe: Node3D = scene.instantiate() as Node3D
	add_child(probe)
	probe.global_transform = Transform3D.IDENTITY
	var bounds: AABB = _visual_bounds(probe)
	print("[axes] %s aabb_position=(%.3f, %.3f, %.3f) size=(%.3f, %.3f, %.3f)" % [
		path.get_file(), bounds.position.x, bounds.position.y, bounds.position.z,
		bounds.size.x, bounds.size.y, bounds.size.z])
	print("[axes] %s center=(%.3f, %.3f, %.3f) 最長軸=%s" % [
		path.get_file(), bounds.get_center().x, bounds.get_center().y, bounds.get_center().z,
		_longest_axis_name(bounds.size)])
	probe.queue_free()


## 武器メッシュの頂点から、握る部位の重心をモデル座標で実測する。
## 銃: グリップは原点より下（-Y）側。刀: 柄は原点より +Z 側。
## 握り部の実際の軸を、メッシュ頂点の上端側スライスと下端側スライスの重心から出す。
## モデルの座標軸と握りの軸は一致しない（銃把は後ろへ傾き、位置もずれている）。
func _measure_grip_axis(path: String) -> Array:
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return []
	var probe: Node3D = scene.instantiate() as Node3D
	add_child(probe)
	probe.global_transform = Transform3D.IDENTITY
	var samples: Array[Vector3] = []
	for node: Node in _descendants(probe):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface: int in range(mesh_instance.mesh.get_surface_count()):
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
			for vertex: Vector3 in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var local: Vector3 = mesh_instance.transform * vertex
				var inside: bool = local.z > 0.02 if _weapon_kind == "katana" \
					else local.y < -0.05
				if inside:
					samples.append(local)
	probe.queue_free()
	if samples.size() < 10:
		return []
	# 握りに沿う座標（刀は +Z、銃は -Y）で上下 25% を切り出し、その重心を軸の両端にする。
	var keys: Array[float] = []
	for sample: Vector3 in samples:
		keys.append(sample.z if _weapon_kind == "katana" else -sample.y)
	keys.sort()
	var low_key: float = keys[int(float(keys.size()) * 0.25)]
	var high_key: float = keys[int(float(keys.size()) * 0.75)]
	var low_total: Vector3 = Vector3.ZERO
	var low_count: int = 0
	var high_total: Vector3 = Vector3.ZERO
	var high_count: int = 0
	for sample: Vector3 in samples:
		var key: float = sample.z if _weapon_kind == "katana" else -sample.y
		if key <= low_key:
			low_total += sample
			low_count += 1
		elif key >= high_key:
			high_total += sample
			high_count += 1
	if low_count == 0 or high_count == 0:
		return []
	var near_end: Vector3 = low_total / float(low_count)
	var far_end: Vector3 = high_total / float(high_count)
	print("[gripaxis] %s 手前側=(%.4f, %.4f, %.4f) 奥側=(%.4f, %.4f, %.4f) 長さ=%.4f" % [
		path.get_file(), near_end.x, near_end.y, near_end.z,
		far_end.x, far_end.y, far_end.z, near_end.distance_to(far_end)])
	return [near_end, far_end]


func _measure_grip_point(path: String) -> Vector3:
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return Vector3.ZERO
	var probe: Node3D = scene.instantiate() as Node3D
	add_child(probe)
	probe.global_transform = Transform3D.IDENTITY
	var total: Vector3 = Vector3.ZERO
	var count: int = 0
	var grip_min: Vector3 = Vector3.INF
	var grip_max: Vector3 = -Vector3.INF
	for node: Node in _descendants(probe):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var mesh: Mesh = mesh_instance.mesh
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var world_vertex: Vector3 = mesh_instance.transform * vertex
				var inside: bool = world_vertex.z > 0.02 if _weapon_kind == "katana" \
					else world_vertex.y < -0.05
				if inside:
					total += world_vertex
					count += 1
					grip_min = grip_min.min(world_vertex)
					grip_max = grip_max.max(world_vertex)
	probe.queue_free()
	if count == 0:
		print("[gripmeasure] 該当頂点なし")
		return Vector3.ZERO
	var centroid: Vector3 = total / float(count)
	# 重心は頂点密度に引っ張られる（柄は端に頂点が密）。握り位置は区間の中点を使う。
	# 境界箱の中点ではなく、握り部の実軸（上下スライスの重心を結んだ線）の中点を使う。
	var axis: Array = _measure_grip_axis(path)
	var midpoint: Vector3 = (grip_min + grip_max) * 0.5
	if axis.size() == 2:
		# 銃は手のひらがグリップ上端へ来るので上寄り、刀は柄の中央を握る。
		var ratio: float = 0.5 if _weapon_kind == "katana" else grip_axis_ratio
		midpoint = (axis[0] as Vector3).lerp(axis[1] as Vector3, ratio)
	print("[gripmeasure] %s 握り部: 重心=(%.4f, %.4f, %.4f) 区間=%.4f〜%.4f 中点=(%.4f, %.4f, %.4f) 頂点数=%d" % [
		path.get_file(), centroid.x, centroid.y, centroid.z,
		(grip_min.z if _weapon_kind == "katana" else grip_min.y),
		(grip_max.z if _weapon_kind == "katana" else grip_max.y),
		midpoint.x, midpoint.y, midpoint.z, count])
	return midpoint


func _longest_axis_name(size: Vector3) -> String:
	if size.x >= size.y and size.x >= size.z:
		return "X (%.3fm)" % size.x
	if size.y >= size.z:
		return "Y (%.3fm)" % size.y
	return "Z (%.3fm)" % size.z


## 装着後の実測: 武器の握り部の重心が、手のひらからどれだけ離れているか（m）。
## 1方向からの目視では視線方向のずれが見えないので、これを合否の基準にする。
func _report_grip_error(label: String) -> void:
	var weapon_node: Node3D = _holder.call("current_weapon") as Node3D
	if weapon_node == null or _skeleton == null:
		print("[griperr] %s 取得できない" % label)
		return
	var model_grip: Vector3 = _measure_grip_point(
		KATANA_PATH if _weapon_kind == "katana" else PISTOL_PATH)
	var world_grip: Vector3 = weapon_node.global_transform * model_grip
	var wrist: Vector3 = _hand_position()
	var middle_index: int = _skeleton.find_bone(&"RightMiddleProximal")
	var knuckle: Vector3 = wrist
	if middle_index >= 0:
		knuckle = (_skeleton.global_transform \
			* _skeleton.get_bone_global_pose(middle_index)).origin
	# 握りが収まるのは指の付け根の並び（拳の中）。手首寄りの点ではない。
	var palm: Vector3 = _knuckle_center()
	if palm == Vector3.ZERO:
		palm = wrist.lerp(knuckle, palm_ratio)
	var error: Vector3 = world_grip - palm
	print("[griperr] %s 握り重心=(%.3f, %.3f, %.3f) 手のひら=(%.3f, %.3f, %.3f) ずれ=%.4fm 内訳=(%.4f, %.4f, %.4f)" % [
		label, world_grip.x, world_grip.y, world_grip.z, palm.x, palm.y, palm.z,
		error.length(), error.x, error.y, error.z])


# --- 望ましい向きから逆算する ---------------------------------------------

## 手ボーンの姿勢 B に対し、武器のワールド姿勢が目標 T になる局所回転 R = B^-1 * T を出す。
## 併せて、握るべき部位（銃=グリップ / 刀=柄の中央）を手の位置へ寄せるオフセットも出す。
func _solve_grip() -> void:
	var attachment: Node3D = _current_attachment()
	if attachment == null:
		print("[solve] BoneAttachment3D を取得できない")
		return
	var bone_basis: Basis = attachment.global_transform.basis.orthonormalized()
	var target: Basis = Basis.IDENTITY
	var grip_point: Vector3 = Vector3.ZERO
	var grip_scale: float = 0.12
	if _weapon_kind == "katana":
		# 刀は世界基準で向きを決めるとポーズごとに答えが変わる。手の骨格を基準にする。
		# 柄は拳の握り溝（人差し指付け根→小指付け根）に沿い、刀身は人差し指側へ伸びる。
		var hand_basis: Basis = _grip_channel_basis()
		if hand_basis == Basis.IDENTITY:
			print("[solve] 指の骨を取れないので握り溝を作れない")
			return
		target = hand_basis
		grip_scale = 0.40
		grip_point = _measure_grip_point(KATANA_PATH)
	else:
		# 銃身はモデル +X。ワールド +X（正面）へ向け、グリップ（-Y）は下を向く。
		target = Basis.IDENTITY
		grip_point = _measure_grip_point(PISTOL_PATH)
	var local_basis: Basis = bone_basis.inverse() * target
	var euler_deg: Vector3 = local_basis.get_euler() * 180.0 / PI
	# 手ボーンの原点は手首。握りは手のひら中心（手首と中指付け根の中点）へ寄せる。
	var palm_offset: Vector3 = _palm_offset_in_bone_space(attachment)
	# 刀は軸別スケール (0.40, 0.40, 0.50)。握り点は各軸で掛ける。
	var scale_vector: Vector3 = Vector3(0.40, 0.40, 0.50) if _weapon_kind == "katana" \
		else Vector3(grip_scale, grip_scale, grip_scale)
	var offset: Vector3 = palm_offset - (local_basis * (grip_point * scale_vector))
	print("[solve] %s palm_offset=(%.4f, %.4f, %.4f)" % [
		_weapon_kind, palm_offset.x, palm_offset.y, palm_offset.z])
	print("[solve] %s bone_euler=(%.1f, %.1f, %.1f)" % [_weapon_kind,
		bone_basis.get_euler().x * 180.0 / PI, bone_basis.get_euler().y * 180.0 / PI,
		bone_basis.get_euler().z * 180.0 / PI])
	print("[solve] %s 推奨 rotation=(%.1f, %.1f, %.1f) offset=(%.4f, %.4f, %.4f) scale=%.2f" % [
		_weapon_kind, euler_deg.x, euler_deg.y, euler_deg.z,
		offset.x, offset.y, offset.z, grip_scale])
	_solved_rotation = euler_deg
	_solved_offset = offset


var _solved_rotation: Vector3 = Vector3.ZERO
var _solved_offset: Vector3 = Vector3.ZERO


## 4本の指の付け根の中心。握った柄・グリップが収まる位置。
func _knuckle_center() -> Vector3:
	# 指を握り込んだ状態では、柄が収まるのは第2関節がつくる輪の中心。
	var names: Array[StringName] = [&"RightIndexIntermediate", &"RightMiddleIntermediate",
		&"RightRingIntermediate", &"RightLittleIntermediate"]
	var total: Vector3 = Vector3.ZERO
	var count: int = 0
	for bone_name: StringName in names:
		var bone_index: int = _skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		total += (_skeleton.global_transform * _skeleton.get_bone_global_pose(bone_index)).origin
		count += 1
	if count == 0:
		return Vector3.ZERO
	return total / float(count)


## 握り溝を基準にした目標姿勢。刀身（モデル -Z）が人差し指側へ伸び、
## 柄（モデル +Z）が小指側へ抜ける向きになる。ポーズに依らず一定。
func _grip_channel_basis() -> Basis:
	var index_index: int = _skeleton.find_bone(&"RightIndexProximal")
	var little_index: int = _skeleton.find_bone(&"RightLittleProximal")
	var middle_index: int = _skeleton.find_bone(&"RightMiddleProximal")
	if index_index < 0 or little_index < 0 or middle_index < 0:
		return Basis.IDENTITY
	var index_pos: Vector3 = (_skeleton.global_transform \
		* _skeleton.get_bone_global_pose(index_index)).origin
	var little_pos: Vector3 = (_skeleton.global_transform \
		* _skeleton.get_bone_global_pose(little_index)).origin
	var middle_pos: Vector3 = (_skeleton.global_transform \
		* _skeleton.get_bone_global_pose(middle_index)).origin
	var across: Vector3 = (little_pos - index_pos).normalized()
	var along: Vector3 = (middle_pos - _hand_position()).normalized()
	var normal: Vector3 = across.cross(along).normalized()
	# モデル -Z を「人差し指側」へ向けたいので z 列 = across（-z 列 = -across）。
	# --flip で刀身を反対（小指側）へ出す。どちらが前を向くかはポーズ依存なので実測で決める。
	var z_col: Vector3 = -across if _flip_blade else across
	var x_col: Vector3 = normal
	var y_col: Vector3 = z_col.cross(x_col).normalized()
	return Basis(x_col, y_col, z_col).orthonormalized()


## 手首→手のひら中心のずれを、BoneAttachment3D のローカル空間で返す。
func _palm_offset_in_bone_space(attachment: Node3D) -> Vector3:
	if _skeleton == null or _right_hand_index < 0:
		return Vector3.ZERO
	var finger_index: int = _skeleton.find_bone(&"RightMiddleProximal")
	if finger_index < 0:
		return Vector3.ZERO
	var wrist: Vector3 = _hand_position()
	var knuckle: Vector3 = (_skeleton.global_transform \
		* _skeleton.get_bone_global_pose(finger_index)).origin
	# 握りが収まるのは指の付け根の並び（拳の中）。手首寄りの点ではない。
	var palm: Vector3 = _knuckle_center()
	if palm == Vector3.ZERO:
		palm = wrist.lerp(knuckle, palm_ratio)
	# 手のひら中心そのものに武器の中心を置くと、メッシュへめり込む。
	# 手のひら法線（親指側→小指側 と 指方向 の外積）へ palm_clearance ぶん逃がす。
	var index_index: int = _skeleton.find_bone(&"RightIndexProximal")
	var little_index: int = _skeleton.find_bone(&"RightLittleProximal")
	if index_index >= 0 and little_index >= 0:
		var index_pos: Vector3 = (_skeleton.global_transform \
			* _skeleton.get_bone_global_pose(index_index)).origin
		var little_pos: Vector3 = (_skeleton.global_transform \
			* _skeleton.get_bone_global_pose(little_index)).origin
		var across: Vector3 = (little_pos - index_pos).normalized()
		var along: Vector3 = (knuckle - wrist).normalized()
		var normal: Vector3 = across.cross(along).normalized()
		palm += normal * palm_clearance
		print("[solve] palm_normal=(%.3f, %.3f, %.3f) clearance=%.3fm" % [
			normal.x, normal.y, normal.z, palm_clearance])
	return attachment.global_transform.affine_inverse() * palm


func _current_attachment() -> Node3D:
	var weapon_node: Node3D = _holder.call("current_weapon") as Node3D
	if weapon_node == null:
		return null
	return weapon_node.get_parent() as Node3D


## 握り位置（手のひら比率 × 逃がし量）の格子で撮る。
func _sweep_offsets() -> void:
	var path: String = KATANA_PATH if _weapon_kind == "katana" else PISTOL_PATH
	var scene: PackedScene = load(path) as PackedScene
	var grip_scale: Vector3 = Vector3(0.40, 0.40, 0.50) if _weapon_kind == "katana" else Vector3(0.12, 0.12, 0.12)
	# 姿勢が動くと回転の解も動いて比較にならないので、まず待機ポーズを止める。
	_freeze_pose()
	var ratios: Array[float] = [0.15, 0.30, 0.45]
	var clearances: Array[float] = [0.000, 0.010, 0.020]
	var index: int = 0
	for ratio: float in ratios:
		for clearance: float in clearances:
			palm_ratio = ratio
			palm_clearance = clearance
			_solve_grip()
			_holder.call("equip", scene, _solved_offset, _solved_rotation, grip_scale)
			await _settle(3)
			print("[offsets] %02d ratio=%.2f clearance=%.3f rot=(%.1f, %.1f, %.1f) offset=(%.4f, %.4f, %.4f)" % [
				index, ratio, clearance, _solved_rotation.x, _solved_rotation.y,
				_solved_rotation.z, _solved_offset.x, _solved_offset.y, _solved_offset.z])
			await _shoot("qc_off_%s_%02d.png" % [_weapon_kind, index])
			index += 1


# --- 総当たり撮影 ---------------------------------------------------------

func _sweep() -> void:
	var path: String = KATANA_PATH if _weapon_kind == "katana" else PISTOL_PATH
	var scene: PackedScene = load(path) as PackedScene
	var grip_scale: Vector3 = Vector3(0.40, 0.40, 0.50) if _weapon_kind == "katana" else Vector3(0.12, 0.12, 0.12)
	var rotations: Array[Vector3] = KATANA_ROTATIONS if _weapon_kind == "katana" \
		else PISTOL_ROTATIONS
	# 逆算した値をまず撮る（00 番）。
	_holder.call("equip", scene, _solved_offset, _solved_rotation, grip_scale)
	await _settle(3)
	_report_grip_error(_weapon_kind)
	if _weapon_kind == "katana":
		_report_blade_clearance("flip" if _flip_blade else "正規(人差し指側)")
	await _shoot_angles()
	for index: int in range(rotations.size()):
		var rotation_deg: Vector3 = rotations[index]
		_holder.call("equip", scene, Vector3.ZERO, rotation_deg, grip_scale)
		await _settle(3)
		var weapon_node: Node3D = _holder.call("current_weapon") as Node3D
		var bounds: AABB = _visual_bounds(weapon_node)
		var hand: Vector3 = _hand_position()
		print("[sweep] %02d rot=(%.0f, %.0f, %.0f) aabb_size=(%.3f, %.3f, %.3f) center-hand=(%.3f, %.3f, %.3f)" % [
			index, rotation_deg.x, rotation_deg.y, rotation_deg.z,
			bounds.size.x, bounds.size.y, bounds.size.z,
			bounds.get_center().x - hand.x, bounds.get_center().y - hand.y,
			bounds.get_center().z - hand.z])
		await _shoot("qc_grip_%s_%02d.png" % [_weapon_kind, index])


## 握り位置を手のひら面に沿って動かす格子。回転は解いた値のまま固定し、
## 指方向（手首→中指付け根）と手のひら法線の2軸だけ動かして3方向から撮る。
func _sweep_nudge() -> void:
	var path: String = KATANA_PATH if _weapon_kind == "katana" else PISTOL_PATH
	var scene: PackedScene = load(path) as PackedScene
	var grip_scale: Vector3 = Vector3(0.40, 0.40, 0.50) if _weapon_kind == "katana" else Vector3(0.12, 0.12, 0.12)
	_solve_grip()
	_freeze_pose()
	var attachment: Node3D = _current_attachment()
	if attachment == null or _skeleton == null:
		print("[nudge] 武器またはスケルトンを取得できない")
		return
	var wrist: Vector3 = _hand_position()
	var middle_index: int = _skeleton.find_bone(&"RightMiddleProximal")
	var knuckle: Vector3 = (_skeleton.global_transform \
		* _skeleton.get_bone_global_pose(middle_index)).origin
	var along_world: Vector3 = (knuckle - wrist).normalized()
	var index_index: int = _skeleton.find_bone(&"RightIndexProximal")
	var little_index: int = _skeleton.find_bone(&"RightLittleProximal")
	if middle_index < 0 or index_index < 0 or little_index < 0:
		print("[nudge] 指の骨を取得できない")
		return
	var across_world: Vector3 = ((_skeleton.global_transform \
		* _skeleton.get_bone_global_pose(little_index)).origin \
		- (_skeleton.global_transform \
		* _skeleton.get_bone_global_pose(index_index)).origin).normalized()
	var normal_world: Vector3 = across_world.cross(along_world).normalized()
	var basis_inverse: Basis = attachment.global_transform.basis.orthonormalized().inverse()
	var along_local: Vector3 = basis_inverse * along_world
	var normal_local: Vector3 = basis_inverse * normal_world
	var index: int = 0
	for along: float in [0.00, 0.025, 0.05]:
		for normal: float in [-0.02, 0.00, 0.02]:
			var offset: Vector3 = _solved_offset + along_local * along + normal_local * normal
			_holder.call("equip", scene, offset, _solved_rotation, grip_scale)
			await _settle(2)
			print("[nudge] %02d 指方向=%.3f 法線=%.3f offset=(%.4f, %.4f, %.4f)" % [
				index, along, normal, offset.x, offset.y, offset.z])
			await _shoot_nudge_angles(index)
			index += 1


func _shoot_nudge_angles(index: int) -> void:
	var target: Vector3 = _hand_position()
	var views: Array = [["s", Vector3(0.0, 0.05, 0.55)], ["f", Vector3(0.55, 0.05, 0.0)],
		["t", Vector3(0.05, 0.55, 0.05)]]
	for view: Array in views:
		_camera.global_position = target + (view[1] as Vector3)
		_camera.look_at(target, Vector3.UP if view[0] != "t" else Vector3.FORWARD)
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png(OUTPUT_DIRECTORY + "qc_nudge_%s_%02d_%s.png" % [
			_weapon_kind, index, view[0]])


## ボーンのローカル姿勢を親までたどって合成し、ワールド位置を出す。
## get_bone_global_pose() は modifier の書き込みを反映しない場合があるため、
## 計測はこちらを使う。
func _bone_global_position(bone_index: int) -> Vector3:
	var transform: Transform3D = Transform3D.IDENTITY
	var current: int = bone_index
	while current >= 0:
		transform = _skeleton.get_bone_pose(current) * transform
		current = _skeleton.get_bone_parent(current)
	return (_skeleton.global_transform * transform).origin


## modifier 適用後の姿勢で指の巻き付きを測る。
func _measure_after_modifier() -> void:
	var modifier: Node = null
	if _skeleton != null:
		modifier = _skeleton.get_node_or_null(^"RightHandWeaponGripModifier")
	if modifier == null:
		print("[wrap] modifier が見つからない（上書き前の姿勢で測る）")
		_report_finger_wrap("modifier無し")
		return
	print("[wrap] modifier active=%s" % str((modifier as SkeletonModifier3D).active))
	var measured: Array[bool] = [false]
	(modifier as SkeletonModifier3D).modification_processed.connect(
		func() -> void:
			if measured[0]:
				return
			measured[0] = true
			_report_finger_wrap("modifier適用後"))
	for _index: int in range(6):
		await get_tree().physics_frame
	if not measured[0]:
		print("[wrap] シグナルが来ないので上書き前の姿勢で測る")
		_report_finger_wrap("シグナル無し")


## 柄が指の握りの中を通っているかを、関節ごとの距離で測る。
## 握れているなら、各指の Proximal / Intermediate / Distal が柄軸を取り巻き、
## Distal（指先側）は手のひらの反対側＝柄をまたいだ位置に来る。
func _report_finger_wrap(label: String) -> void:
	var weapon_node: Node3D = _holder.call("current_weapon") as Node3D
	if weapon_node == null or _skeleton == null:
		return
	# SkeletonModifier3D の結果を含めた最終姿勢で測る。
	_skeleton.force_update_all_bone_transforms()
	# 柄の軸: 刀はモデル +Z の 0〜0.275、銃はグリップ（-Y 側）の 0〜-0.48。
	# 軸はメッシュ実測（モデルの座標軸とは一致しない）。
	var axis: Array = _measure_grip_axis(
		KATANA_PATH if _weapon_kind == "katana" else PISTOL_PATH)
	if axis.size() != 2:
		return
	var grip_a: Vector3 = weapon_node.global_transform * (axis[0] as Vector3)
	var grip_b: Vector3 = weapon_node.global_transform * (axis[1] as Vector3)
	var radius: float = 0.019 if _weapon_kind == "katana" else 0.016
	# 指ボーンの回転そのものを出して、上書きが効いているかを直接確かめる。
	for bone_name: StringName in [&"RightIndexProximal", &"RightIndexIntermediate",
			&"RightIndexDistal"]:
		var bone_index: int = _skeleton.find_bone(bone_name)
		if bone_index >= 0:
			var euler: Vector3 = _skeleton.get_bone_pose_rotation(bone_index).get_euler() \
				* 180.0 / PI
			print("[bone] %s pose=(%.1f, %.1f, %.1f)" % [bone_name, euler.x, euler.y, euler.z])
	# 拳が柄のどこを握っているか（0=鍔側の端、1=柄頭側の端）。
	var ring: Vector3 = _knuckle_center()
	var span: Vector3 = grip_b - grip_a
	var position_ratio: float = clampf((ring - grip_a).dot(span) / span.length_squared(),
		0.0, 1.0)
	print("[hold] 拳の位置=%.2f（0=鍔側 1=柄頭側） 柄の長さ=%.3fm" % [
		position_ratio, span.length()])
	print("[wrap] --- %s 柄の軸 A=(%.3f, %.3f, %.3f) B=(%.3f, %.3f, %.3f) 半径=%.3fm" % [
		label, grip_a.x, grip_a.y, grip_a.z, grip_b.x, grip_b.y, grip_b.z, radius])
	for finger: String in ["Index", "Middle", "Ring", "Little", "Thumb"]:
		var line: String = "[wrap] %-6s" % finger
		for part: String in ["Proximal", "Intermediate", "Distal"]:
			var bone_index: int = _skeleton.find_bone(StringName("Right%s%s" % [finger, part]))
			if bone_index < 0:
				line += "  %s=--" % part.substr(0, 4)
				continue
			var joint: Vector3 = _bone_global_position(bone_index)
			var segment: Vector3 = grip_b - grip_a
			var t: float = clampf((joint - grip_a).dot(segment) / segment.length_squared(),
				0.0, 1.0)
			var nearest: Vector3 = grip_a + segment * t
			var distance: float = joint.distance_to(nearest) - radius
			line += "  %s=%+.3f" % [part.substr(0, 4), distance]
		print(line)


## 刀身と頭・胴の距離を測る（刃が体へ刺さっていないかの合否判定用）。
func _report_blade_clearance(label: String) -> void:
	var weapon_node: Node3D = _holder.call("current_weapon") as Node3D
	if weapon_node == null or _skeleton == null:
		return
	# 刀身はモデル -Z 方向、鍔付近から先端 -1.437 まで。
	var tsuba: Vector3 = weapon_node.global_transform * Vector3(0.0, 0.0, 0.0)
	var tip: Vector3 = weapon_node.global_transform * Vector3(0.0, 0.0, -1.437)
	var checks: Array[StringName] = [&"Head", &"Neck", &"Chest", &"UpperChest"]
	for bone_name: StringName in checks:
		var bone_index: int = _skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		var bone_position: Vector3 = (_skeleton.global_transform \
			* _skeleton.get_bone_global_pose(bone_index)).origin
		var segment: Vector3 = tip - tsuba
		var t: float = clampf((bone_position - tsuba).dot(segment) / segment.length_squared(),
			0.0, 1.0)
		var nearest: Vector3 = tsuba + segment * t
		print("[blade] %s %s までの最短距離=%.3fm（刀身上の位置 %.2f）" % [
			label, bone_name, nearest.distance_to(bone_position), t])
	print("[blade] %s 鍔=(%.3f, %.3f, %.3f) 切先=(%.3f, %.3f, %.3f)" % [
		label, tsuba.x, tsuba.y, tsuba.z, tip.x, tip.y, tip.z])


## 3方向から撮る（1方向だと視線方向のずれが見えない）。
func _shoot_angles() -> void:
	# 手ではなく握り部の重心を中心に据える（手首基準だと武器が枠外に出る）。
	var target: Vector3 = _hand_position()
	var weapon_node: Node3D = _holder.call("current_weapon") as Node3D
	if weapon_node != null:
		var model_grip: Vector3 = _measure_grip_point(
			KATANA_PATH if _weapon_kind == "katana" else PISTOL_PATH)
		target = weapon_node.global_transform * model_grip
	var views: Array[Dictionary] = [
		{"name": "game", "offset": Vector3(0.30, 0.10, 0.42)},
		{"name": "side", "offset": Vector3(0.0, 0.05, 0.34)},
		{"name": "front", "offset": Vector3(0.34, 0.05, 0.0)},
		{"name": "top", "offset": Vector3(0.05, 0.34, 0.05)},
		{"name": "back", "offset": Vector3(-0.34, 0.05, 0.0)},
	]
	for view: Dictionary in views:
		_camera.global_position = target + (view["offset"] as Vector3)
		_camera.look_at(target, Vector3.UP if view["name"] != "top" else Vector3.FORWARD)
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png(OUTPUT_DIRECTORY + "qc_angle_%s_%s.png" % [_weapon_kind, view["name"]])
		print("[angle] %s %s" % [_weapon_kind, view["name"]])


# --- 下回り ---------------------------------------------------------------

func _hand_position() -> Vector3:
	if _skeleton == null or _right_hand_index < 0:
		return Vector3.ZERO
	return (_skeleton.global_transform \
		* _skeleton.get_bone_global_pose(_right_hand_index)).origin


func _shoot(file_name: String) -> void:
	var target: Vector3 = _hand_position()
	_camera.global_position = target + Vector3(0.30, 0.10, 0.75)
	_camera.look_at(target, Vector3.UP)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: int = image.save_png(OUTPUT_DIRECTORY + file_name)
	if error != OK:
		printerr("[sweep] 保存できない: %s" % file_name)


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


func _settle(frames: int) -> void:
	for _index: int in range(frames):
		await get_tree().process_frame
