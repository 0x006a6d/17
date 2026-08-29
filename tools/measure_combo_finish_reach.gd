extends "res://tools/capture_combo.gd"

## 0.35秒間隔の3連撃で、3段目の有効窓における中心間距離と不足距離を実測する。
@export_enum("punch", "kick") var combo_kind: String = "punch"
@export var dummy_knockback_speed: float = 3.0

var _current_technique: StringName = &""
var _previous_monitoring: bool = false
var _active_min_gap: float = INF
var _active_center_distance: float = 0.0
var _active_effective_reach: float = 0.0
var _active_hit: bool = false
var _previous_hit_distance: float = 0.0
var _finisher_start_distance: float = 0.0


func _ready() -> void:
	scenario = "d" if combo_kind == "punch" else "k3"
	multi_hit_dummy_knockback_speed = dummy_knockback_speed
	super._ready()
	var dummy := get_node_or_null(^"Dummy") as CharacterBody3D
	if dummy != null:
		dummy.set("knockback_speed", dummy_knockback_speed)
	_melee.stage_started.connect(_on_measured_stage_started)
	_hitbox.hit_landed.connect(_on_measured_hit_landed)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var monitoring: bool = _hitbox != null and _hitbox.monitoring
	if monitoring and _is_finisher():
		_measure_window()
	if _previous_monitoring and not monitoring and _is_finisher():
		_print_window_result()
	_previous_monitoring = monitoring


func _on_measured_stage_started(technique: StringName, _stage: int) -> void:
	_current_technique = technique
	print("[STAGE] kind=%s technique=%s stage=%d" % [combo_kind, technique, _stage])
	if _is_finisher():
		_active_min_gap = INF
		_active_hit = false
		_finisher_start_distance = _center_distance()


func _on_measured_hit_landed(_target: Node3D) -> void:
	print("[HIT] kind=%s technique=%s distance=%.3f m" % [
		combo_kind, _current_technique, _center_distance()])
	if _is_finisher():
		_active_hit = true
	else:
		_previous_hit_distance = _center_distance()


func _measure_window() -> void:
	var player_position := Vector2(_player.global_position.x, _player.global_position.z)
	var dummy_position := Vector2(_dummy_hurtbox.global_position.x,
		_dummy_hurtbox.global_position.z)
	var hit_position := Vector2(_hitbox.global_position.x, _hitbox.global_position.z)
	var hit_radius: float = _shape_radius(_hitbox)
	var hurt_radius: float = _shape_radius(_dummy_hurtbox)
	var hit_to_hurt: float = hit_position.distance_to(dummy_position)
	var gap: float = hit_to_hurt - hit_radius - hurt_radius
	if gap < _active_min_gap:
		_active_min_gap = gap
		_active_center_distance = player_position.distance_to(dummy_position)
		_active_effective_reach = _active_center_distance - maxf(gap, 0.0)


func _print_window_result() -> void:
	print(("[MEASURE] kind=%s technique=%s previous_hit=%.3f m " \
		+ "finisher_start=%.3f m center_distance=%.3f m " \
		+ "effective_reach=%.3f m gap=%.3f m hit=%s") % [
		combo_kind, _current_technique, _previous_hit_distance,
		_finisher_start_distance, _active_center_distance,
		_active_effective_reach, maxf(_active_min_gap, 0.0), str(_active_hit)])


func _center_distance() -> float:
	var player_position := Vector2(_player.global_position.x, _player.global_position.z)
	var dummy_position := Vector2(_dummy_hurtbox.global_position.x,
		_dummy_hurtbox.global_position.z)
	return player_position.distance_to(dummy_position)


func _shape_radius(area: Area3D) -> float:
	var collision := area.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if collision == null:
		return 0.0
	if collision.shape is SphereShape3D:
		return (collision.shape as SphereShape3D).radius
	if collision.shape is CapsuleShape3D:
		return (collision.shape as CapsuleShape3D).radius
	return 0.0


func _is_finisher() -> bool:
	return _current_technique == &"hook" or _current_technique == &"high"
