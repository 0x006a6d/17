extends Node3D
class_name DirectionalBloodSpray3D

## 敵への斬撃・銃撃を、攻撃の進行方向へ流れる短命な血しぶきとして描く。
## 判定は Hurtbox が担い、このノードは実ダメージ成立後の表示だけを受け持つ。

const TEXTURE_SIZE: int = 48
const STREAK_TEXTURE_LENGTH: int = 96
const STREAK_TEXTURE_WIDTH: int = 20
const MIN_DIRECTION_LENGTH_SQUARED: float = 0.000001

static var _shared_radial_texture: Texture2D = null
static var _shared_streak_texture: Texture2D = null

enum AttackKind { NONE, SLASH, SHOT }

@export_group("Palette")
@export var blood_red: Color = Color(0.72, 0.008, 0.025, 0.94)
@export var blood_bright: Color = Color(0.96, 0.025, 0.035, 0.88)
@export var blood_dark: Color = Color(0.22, 0.002, 0.008, 0.92)

@export_group("Katana")
@export var slash_streak_length: float = 0.92
@export var slash_streak_width: float = 0.115
@export var slash_streak_duration: float = 0.20
@export var slash_droplet_count: int = 15
@export var slash_droplet_speed: Vector2 = Vector2(1.7, 3.8)
@export var slash_spread: float = 0.46

@export_group("Gunshot")
@export var shot_streak_length: float = 0.58
@export var shot_streak_width: float = 0.075
@export var shot_streak_duration: float = 0.16
@export var shot_droplet_count: int = 10
@export var shot_droplet_speed: Vector2 = Vector2(2.2, 4.5)
@export var shot_spread: float = 0.27

@export_group("Droplets")
@export var droplet_lifetime: Vector2 = Vector2(0.28, 0.52)
@export var droplet_length: Vector2 = Vector2(0.045, 0.14)
@export var droplet_width: Vector2 = Vector2(0.018, 0.046)
@export var gravity: float = 5.8
@export_group("")

var _radial_texture: Texture2D = null
var _streak_texture: Texture2D = null
var _rng := RandomNumberGenerator.new()
var _last_kind: int = AttackKind.NONE
var _last_impact_position: Vector3 = Vector3.ZERO
var _last_flow_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	if _shared_radial_texture == null:
		_shared_radial_texture = ProceduralGlow.make_radial_texture(TEXTURE_SIZE, 2.4)
	if _shared_streak_texture == null:
		_shared_streak_texture = ProceduralGlow.make_streak_texture(
			STREAK_TEXTURE_LENGTH, STREAK_TEXTURE_WIDTH, 1.8)
	_radial_texture = _shared_radial_texture
	_streak_texture = _shared_streak_texture
	_rng.randomize()


func play_slash(impact_position: Vector3, blade_flow: Vector3) -> void:
	_spawn(AttackKind.SLASH, impact_position, blade_flow,
		slash_streak_length, slash_streak_width, slash_streak_duration,
		slash_droplet_count, slash_droplet_speed, slash_spread)


func play_shot(impact_position: Vector3, bullet_flow: Vector3) -> void:
	_spawn(AttackKind.SHOT, impact_position, bullet_flow,
		shot_streak_length, shot_streak_width, shot_streak_duration,
		shot_droplet_count, shot_droplet_speed, shot_spread)


func debug_last_kind() -> int:
	return _last_kind


func debug_last_impact_position() -> Vector3:
	return _last_impact_position


func debug_last_flow_direction() -> Vector3:
	return _last_flow_direction


func active_burst_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child.name == &"KatanaBloodSpray" or child.name == &"GunshotBloodSpray":
			count += 1
	return count


func _spawn(kind: int, impact_position: Vector3, raw_flow: Vector3,
		streak_length: float, streak_width: float, streak_duration: float,
		droplet_count: int, speed_range: Vector2, spread: float) -> void:
	var flow := raw_flow
	if flow.length_squared() < MIN_DIRECTION_LENGTH_SQUARED:
		flow = Vector3.RIGHT
	flow = flow.normalized()
	_last_kind = kind
	_last_impact_position = impact_position
	_last_flow_direction = flow

	var burst := Node3D.new()
	burst.name = &"KatanaBloodSpray" if kind == AttackKind.SLASH \
		else &"GunshotBloodSpray"
	add_child(burst)
	# 敵がノックバック・ダウンしても、放たれた飛沫は命中したワールド座標に残す。
	burst.top_level = true
	burst.global_transform = Transform3D.IDENTITY

	_spawn_directional_streaks(burst, impact_position, flow, streak_length,
		streak_width, streak_duration, 3 if kind == AttackKind.SLASH else 2)
	_spawn_mist(burst, impact_position, flow, streak_width, streak_duration)
	_spawn_droplets(burst, impact_position, flow, droplet_count, speed_range, spread)

	var maximum_lifetime: float = maxf(streak_duration,
		maxf(droplet_lifetime.x, droplet_lifetime.y)) + 0.08
	var cleanup := burst.create_tween()
	cleanup.tween_interval(maximum_lifetime)
	cleanup.tween_callback(burst.queue_free)


func _spawn_directional_streaks(burst: Node3D, position: Vector3,
		flow: Vector3, length: float, width: float, duration: float,
		count: int) -> void:
	for index: int in maxi(count, 1):
		var lane: float = float(index) - float(maxi(count, 1) - 1) * 0.5
		var lane_direction: Vector3 = _spread_direction(flow,
			lane * 0.085, lane * 0.035)
		var lane_length: float = length * (1.0 - absf(lane) * 0.16) \
			* _rng.randf_range(0.90, 1.08)
		var lane_width: float = width * _rng.randf_range(0.72, 1.12)
		var streak := _make_quad(_streak_texture,
			Vector2(lane_length, lane_width),
			blood_bright if index == 0 else blood_red)
		streak.name = &"BloodFlowStreak"
		burst.add_child(streak)
		streak.global_position = position + lane_direction * lane_length * 0.38
		streak.global_basis = _camera_facing_basis(lane_direction, position)
		var drift: Vector3 = lane_direction * lane_length * 0.24 \
			+ Vector3.DOWN * lane_width * 0.35
		var tween := streak.create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(streak, "global_position",
			streak.global_position + drift, maxf(duration, 0.001))
		tween.tween_property(streak, "scale",
			Vector3(1.14, 0.28, 1.0), maxf(duration, 0.001))
		tween.tween_property(streak, "transparency", 1.0,
			maxf(duration * 0.64, 0.001)).set_delay(duration * 0.36)


func _spawn_mist(burst: Node3D, position: Vector3, flow: Vector3,
		base_width: float, duration: float) -> void:
	var mist := _make_quad(_radial_texture,
		Vector2.ONE * maxf(base_width * 2.8, 0.12),
		Color(blood_dark.r, blood_dark.g, blood_dark.b, 0.58))
	mist.name = &"BloodMist"
	burst.add_child(mist)
	mist.global_position = position + flow * base_width * 0.5
	mist.global_basis = _camera_facing_basis(flow, position)
	var tween := mist.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mist, "global_position",
		mist.global_position + flow * 0.24 + Vector3.UP * 0.035,
		maxf(duration * 1.35, 0.001))
	tween.tween_property(mist, "scale", Vector3.ONE * 2.6,
		maxf(duration * 1.35, 0.001))
	tween.tween_property(mist, "transparency", 1.0,
		maxf(duration, 0.001)).set_delay(duration * 0.35)


func _spawn_droplets(burst: Node3D, position: Vector3, flow: Vector3,
		count: int, speed_range: Vector2, spread: float) -> void:
	for index: int in maxi(count, 0):
		var side_spread: float = _rng.randf_range(-spread, spread)
		var vertical_spread: float = _rng.randf_range(-spread * 0.62, spread * 0.62)
		var direction := _spread_direction(flow, side_spread, vertical_spread)
		var speed: float = _rng.randf_range(minf(speed_range.x, speed_range.y),
			maxf(speed_range.x, speed_range.y))
		var velocity: Vector3 = direction * speed
		var lifetime: float = _rng.randf_range(
			minf(droplet_lifetime.x, droplet_lifetime.y),
			maxf(droplet_lifetime.x, droplet_lifetime.y))
		var size := Vector2(
			_rng.randf_range(minf(droplet_length.x, droplet_length.y),
				maxf(droplet_length.x, droplet_length.y)),
			_rng.randf_range(minf(droplet_width.x, droplet_width.y),
				maxf(droplet_width.x, droplet_width.y)))
		var droplet := _make_quad(_streak_texture, size,
			blood_red if index % 3 != 0 else blood_dark)
		droplet.name = &"BloodDroplet"
		burst.add_child(droplet)
		var start: Vector3 = position + direction * _rng.randf_range(0.015, 0.08)
		droplet.global_position = start
		droplet.global_basis = _camera_facing_basis(velocity, start)
		var end: Vector3 = start + velocity * lifetime \
			+ Vector3.DOWN * 0.5 * gravity * lifetime * lifetime
		var movement := droplet.create_tween().set_parallel(true)
		movement.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		movement.tween_property(droplet, "global_position", end,
			maxf(lifetime, 0.001))
		movement.tween_property(droplet, "scale", Vector3(0.62, 0.28, 1.0),
			maxf(lifetime, 0.001))
		movement.tween_property(droplet, "transparency", 1.0,
			maxf(lifetime * 0.38, 0.001)).set_delay(lifetime * 0.62)


func _spread_direction(axis: Vector3, side_amount: float,
		vertical_amount: float) -> Vector3:
	var side: Vector3 = axis.cross(Vector3.UP)
	if side.length_squared() < MIN_DIRECTION_LENGTH_SQUARED:
		side = axis.cross(Vector3.FORWARD)
	side = side.normalized()
	var vertical: Vector3 = side.cross(axis).normalized()
	return (axis + side * side_amount + vertical * vertical_amount).normalized()


func _camera_facing_basis(direction: Vector3, position: Vector3) -> Basis:
	var facing_normal := Vector3.FORWARD
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		facing_normal = camera.global_position - position
		if facing_normal.length_squared() >= MIN_DIRECTION_LENGTH_SQUARED:
			facing_normal = facing_normal.normalized()
	var visible_direction: Vector3 = direction \
		- facing_normal * direction.dot(facing_normal)
	if visible_direction.length_squared() < MIN_DIRECTION_LENGTH_SQUARED:
		visible_direction = Vector3.RIGHT
	visible_direction = visible_direction.normalized()
	var vertical: Vector3 = facing_normal.cross(visible_direction)
	if vertical.length_squared() < MIN_DIRECTION_LENGTH_SQUARED:
		vertical = Vector3.UP
	vertical = vertical.normalized()
	var normal: Vector3 = visible_direction.cross(vertical).normalized()
	return Basis(visible_direction, vertical, normal).orthonormalized()


func _make_quad(texture: Texture2D, size: Vector2,
		color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = texture
	material.albedo_color = color
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh
