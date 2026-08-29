extends Node3D
class_name PlayerKatanaSwing3D

## 刀身の現在方向と角速度から3D回転面を求め、その面上に赤い円弧を描く。
## 刀身方向は維持しつつ、横視点で円弧が潰れない範囲まで回転面をカメラへ向ける。
## 刀先の移動軌跡は線として残さず、弧の終端だけを現在の刀先方向へ揃える。

const KATANA_SWING_MESH := preload("res://fx/katana_swing_mesh.gd")
const KATANA_SWING_TRACKER := preload("res://fx/katana_swing_tracker.gd")
const FINAL_STAGE: int = 3

@export_group("Nodes")
@export var combo_path: NodePath = ^"../PlayerKatanaCombo"
@export var weapon_holder_path: NodePath = ^"../WeaponHolder"
@export var hitbox_path: NodePath = ^"../Model/KatanaHitbox"

@export_group("Normal arcs: stage 1 / 2")
@export var normal_radius_scales: Array[float] = [1.20, 1.24]
@export var normal_sweep_angles_deg: Array[float] = [142.0, 148.0]
## 横視点で振り始め側へ弧を伸ばす回転方向。
@export var normal_sweep_directions: Array[float] = [-1.0, -1.0]
## 実測面から横カメラへ見える面へ寄せる量。刀身方向は変えない。
@export var normal_side_view_weights: Array[float] = [1.0, 1.0]
## 接触の直前・直後だけ光らせ、構えと振り抜きには残さない。
@export var normal_reveal_before_contact: Array[float] = [0.10, 0.09]
@export var normal_hold_after_contact: Array[float] = [0.015, 0.015]
@export var normal_fade_after_contact: Array[float] = [0.10, 0.10]
@export var normal_halo_half_width: float = 0.18
@export var normal_core_half_width: float = 0.078
@export var normal_rim_half_width: float = 0.014

@export_group("Final arc")
@export var final_radius_scale: float = 1.92
@export var final_sweep_angle_deg: float = 346.0
@export var final_side_view_weight: float = 0.96
@export var final_center_height: float = 0.86
@export_range(0.0, 1.0) var final_body_center_weight: float = 0.72
@export var final_reveal_before_contact: float = 0.12
@export var final_hold_after_contact: float = 0.035
@export var final_fade_after_contact: float = 0.14

@export_group("Red palette")
@export var deep_red: Color = Color(0.58, 0.002, 0.001, 0.30)
@export var slash_red: Color = Color(1.0, 0.045, 0.003, 0.62)
@export var hot_orange: Color = Color(1.0, 0.19, 0.018, 0.76)
@export var white_gold: Color = Color(1.0, 0.62, 0.24, 0.88)
@export_group("")

var _combo: PlayerKatanaCombo = null
var _holder: WeaponHolder = null
var _hitbox: Hitbox = null
var _tracker: KATANA_SWING_TRACKER = null
var _stage: int = 0
var _normal_halo: MeshInstance3D = null
var _normal_core: MeshInstance3D = null
var _normal_rim: MeshInstance3D = null
var _final_halo: MeshInstance3D = null
var _final_core: MeshInstance3D = null
var _final_rim: MeshInstance3D = null
var _final_spokes: MeshInstance3D = null


func _ready() -> void:
	process_priority = 100
	_combo = get_node_or_null(combo_path) as PlayerKatanaCombo
	_holder = get_node_or_null(weapon_holder_path) as WeaponHolder
	_hitbox = get_node_or_null(hitbox_path) as Hitbox
	_tracker = KATANA_SWING_TRACKER.new()
	_tracker.configure(_holder)
	_create_layers()
	if _combo == null:
		push_warning("katana_swing_3d: PlayerKatanaCombo が見つからない")
		set_process(false)
		return
	_combo.stage_started.connect(_on_stage_started)
	_combo.combo_finished.connect(_on_combo_finished)


func _process(_delta: float) -> void:
	if _stage <= 0 or _combo.current_stage() != _stage:
		return
	var progress: float = _combo.stage_progress()
	var contact: float = _combo.stage_contact_ratio(_stage)
	# 通常段はフォロースルー中も刀身へ追従する。最終段だけ接触姿勢で円を固定する。
	var lock_pose: bool = _stage == FINAL_STAGE and progress >= contact
	if not _tracker.sample(lock_pose):
		return
	var swing_pose: Transform3D = _tracker.swing_transform()
	# basis.y は刀身の角速度から求めた刃の実進行方向。見やすさ補正前の
	# 実測方向を Hitbox に保持し、命中時の血しぶきへそのまま渡す。
	if _hitbox != null:
		_hitbox.set_impact_flow_direction(swing_pose.basis.y)
	var blade_radius: float = _tracker.blade_radius()
	if _stage == FINAL_STAGE:
		swing_pose = _side_visible_pose(swing_pose, final_side_view_weight)
		_update_final_arc(progress, contact, swing_pose, blade_radius)
	else:
		var side_view_weight: float = _stage_value_float(
			normal_side_view_weights, _stage)
		swing_pose = _side_visible_pose(swing_pose, side_view_weight)
		_update_normal_arc(progress, contact, swing_pose, blade_radius)


func active_stage() -> int:
	return _stage


func swing_arc_visible() -> bool:
	return _normal_core != null and _normal_core.mesh != null


func final_arc_visible() -> bool:
	return _final_core != null and _final_core.mesh != null


func debug_swing_basis() -> Basis:
	return _tracker.swing_transform().basis if _tracker != null else Basis.IDENTITY


func debug_blade_direction() -> Vector3:
	return _tracker.blade_direction() if _tracker != null else Vector3.ZERO


func debug_plane_normal() -> Vector3:
	return _tracker.plane_normal() if _tracker != null else Vector3.ZERO


func _on_stage_started(stage_number: int) -> void:
	_stage = stage_number
	if _hitbox != null:
		_hitbox.set_impact_flow_direction(Vector3.ZERO)
	_tracker.begin_stage()
	_clear_normal_arc()
	_clear_final_arc()


func _on_combo_finished(_completed: bool) -> void:
	_stage = 0
	_clear_normal_arc()
	_clear_final_arc()


func _create_layers() -> void:
	_normal_halo = _create_layer(&"SwingArcHalo", 70, 0.78)
	_normal_core = _create_layer(&"SwingArcCore", 71, 1.08)
	_normal_rim = _create_layer(&"SwingArcRim", 72, 1.42)
	_final_halo = _create_layer(&"FinalArcHalo", 73, 0.72)
	_final_core = _create_layer(&"FinalArcCore", 74, 1.06)
	_final_rim = _create_layer(&"FinalArcRim", 75, 1.48)
	_final_spokes = _create_layer(&"FinalArcSpokes", 76, 1.12)


func _create_layer(layer_name: StringName, priority: int, energy: float) -> MeshInstance3D:
	var layer := MeshInstance3D.new()
	layer.name = layer_name
	add_child(layer)
	layer.top_level = true
	layer.global_transform = Transform3D.IDENTITY
	layer.material_override = KATANA_SWING_MESH.make_additive_material(priority, energy)
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return layer


func _update_normal_arc(progress: float, contact: float,
		swing_pose: Transform3D, blade_radius: float) -> void:
	var reveal_before: float = _stage_value_float(
		normal_reveal_before_contact, _stage)
	var hold_after: float = _stage_value_float(
		normal_hold_after_contact, _stage)
	var fade_after: float = _stage_value_float(
		normal_fade_after_contact, _stage)
	var reveal_start: float = maxf(0.0, contact - reveal_before)
	var fade_start: float = contact + hold_after
	var fade_end: float = contact + maxf(fade_after, hold_after + 0.001)
	var reveal: float = smoothstep(reveal_start, contact, progress)
	var fade: float = 1.0 - smoothstep(fade_start, fade_end, progress)
	var opacity: float = reveal * fade
	if opacity <= 0.001:
		_clear_normal_arc()
		return
	var radius: float = blade_radius * _stage_value_float(
		normal_radius_scales, _stage)
	var sweep: float = deg_to_rad(_stage_value_float(
		normal_sweep_angles_deg, _stage)) * reveal
	var sweep_direction: float = signf(_stage_value_float(
		normal_sweep_directions, _stage))
	if is_zero_approx(sweep_direction):
		sweep_direction = 1.0
	var signed_sweep: float = sweep * sweep_direction
	_draw_normal_layers(swing_pose, radius, -signed_sweep, signed_sweep, opacity)


func _draw_normal_layers(pose: Transform3D, radius: float,
		start_angle: float, sweep_angle: float, opacity: float) -> void:
	_normal_halo.mesh = KATANA_SWING_MESH.arc(pose.origin, pose.basis.x, pose.basis.y,
		radius - normal_halo_half_width, radius + normal_halo_half_width,
		start_angle, sweep_angle, deep_red, slash_red, opacity * 0.66)
	_normal_core.mesh = KATANA_SWING_MESH.arc(pose.origin, pose.basis.x, pose.basis.y,
		radius - normal_core_half_width, radius + normal_core_half_width,
		start_angle, sweep_angle, slash_red, hot_orange, opacity * 0.94)
	_normal_rim.mesh = KATANA_SWING_MESH.arc(pose.origin, pose.basis.x, pose.basis.y,
		radius - normal_rim_half_width, radius + normal_rim_half_width,
		start_angle, sweep_angle, white_gold, white_gold, opacity * 0.92)


func _update_final_arc(progress: float, contact: float, swing_pose: Transform3D,
		blade_radius: float) -> void:
	var reveal_start: float = maxf(0.0,
		contact - final_reveal_before_contact)
	var fade_start: float = contact + final_hold_after_contact
	var fade_end: float = contact + maxf(final_fade_after_contact,
		final_hold_after_contact + 0.001)
	var reveal: float = smoothstep(reveal_start, contact, progress)
	var fade: float = 1.0 - smoothstep(fade_start, fade_end, progress)
	var opacity: float = reveal * fade
	if opacity <= 0.001:
		_clear_final_arc()
		return
	var body_center: Vector3 = global_position + Vector3.UP * final_center_height
	swing_pose.origin = swing_pose.origin.lerp(body_center,
		clampf(final_body_center_weight, 0.0, 1.0))
	var radius: float = blade_radius * final_radius_scale
	var sweep: float = deg_to_rad(lerpf(18.0, final_sweep_angle_deg, reveal))
	var start_angle: float = -sweep
	_final_halo.mesh = KATANA_SWING_MESH.arc(swing_pose.origin,
		swing_pose.basis.x, swing_pose.basis.y, radius - 0.25, radius + 0.22,
		start_angle, sweep, deep_red, slash_red, opacity * 0.62)
	_final_core.mesh = KATANA_SWING_MESH.arc(swing_pose.origin,
		swing_pose.basis.x, swing_pose.basis.y, radius - 0.12, radius + 0.09,
		start_angle, sweep, slash_red, hot_orange, opacity * 0.92)
	_final_rim.mesh = KATANA_SWING_MESH.arc(swing_pose.origin,
		swing_pose.basis.x, swing_pose.basis.y, radius - 0.012, radius + 0.018,
		start_angle, sweep, white_gold, white_gold, opacity * 0.92)
	var spoke_opacity: float = opacity * smoothstep(0.36, 0.72, reveal)
	var spoke_angles: Array[float] = [0.0, deg_to_rad(-124.0)]
	_final_spokes.mesh = KATANA_SWING_MESH.spokes(swing_pose.origin,
		swing_pose.basis.x, swing_pose.basis.y, spoke_angles, radius * 1.08,
		0.014, slash_red, spoke_opacity * 0.34)


func _side_visible_pose(pose: Transform3D, weight: float) -> Transform3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null or weight <= 0.001:
		return pose
	var blade_direction: Vector3 = pose.basis.x.normalized()
	var measured_normal: Vector3 = pose.basis.z.normalized()
	var to_camera: Vector3 = (camera.global_position - pose.origin).normalized()
	# 刀身を含み、かつカメラへ最も正対する面の法線。
	var visible_normal: Vector3 = to_camera \
		- blade_direction * to_camera.dot(blade_direction)
	if visible_normal.length_squared() <= 0.0001:
		return pose
	visible_normal = visible_normal.normalized()
	if visible_normal.dot(measured_normal) < 0.0:
		visible_normal = -visible_normal
	var plane_normal: Vector3 = measured_normal.slerp(visible_normal,
		clampf(weight, 0.0, 1.0)).normalized()
	var tangent: Vector3 = plane_normal.cross(blade_direction).normalized()
	return Transform3D(Basis(blade_direction, tangent, plane_normal).orthonormalized(),
		pose.origin)


func _stage_value_float(values: Array[float], stage_number: int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(stage_number - 1, 0, values.size() - 1)]


func _clear_normal_arc() -> void:
	if _normal_halo != null:
		_normal_halo.mesh = null
	if _normal_core != null:
		_normal_core.mesh = null
	if _normal_rim != null:
		_normal_rim.mesh = null


func _clear_final_arc() -> void:
	if _final_halo != null:
		_final_halo.mesh = null
	if _final_core != null:
		_final_core.mesh = null
	if _final_rim != null:
		_final_rim.mesh = null
	if _final_spokes != null:
		_final_spokes.mesh = null
