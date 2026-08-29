class_name PlayerGunFx
extends Node3D

## プレイヤー銃撃の表示専用部品。HitscanGun の判定結果を受け、銃口炎・弾道・
## 命中光・武器の短い反動・カメラシェイクへ変換する。ゲーム判定は変更しない。

const RADIAL_TEXTURE_SIZE: int = 64
const STREAK_TEXTURE_LENGTH: int = 128
const STREAK_TEXTURE_WIDTH: int = 32
const TEXTURE_EDGE_POWER: float = 2.0
const MIN_EFFECT_DURATION: float = 0.001

@export_group("Muzzle Flash")
## 実銃の銃口炎は数フレームで消える。長く残すと火炎放射器に見えるため短く保つ。
@export var muzzle_flash_duration: float = 0.045
@export var muzzle_core_size: float = 0.18
@export var muzzle_flame_size: Vector2 = Vector2(0.52, 0.13)
@export var muzzle_side_flame_size: Vector2 = Vector2(0.28, 0.075)
@export var muzzle_side_flame_angle_degrees: float = 34.0
## HitscanGun の射線原点から、表示モデルの銃口までの前方補正（m）。
@export var muzzle_forward_offset: float = 0.16
@export var muzzle_hot_color: Color = Color(1.0, 0.96, 0.78, 1.0)
@export var muzzle_flame_color: Color = Color(1.0, 0.57, 0.10, 0.88)
@export var muzzle_flash_emission_energy: float = 7.0
@export var muzzle_light_energy: float = 3.2
@export var muzzle_light_range: float = 2.4

@export_group("Muzzle Smoke")
@export var smoke_duration: float = 0.32
@export var smoke_puff_count: int = 3
@export var smoke_start_size: float = 0.13
@export var smoke_end_scale: float = 3.2
@export var smoke_forward_drift: float = 0.24
@export var smoke_upward_drift: float = 0.16
@export var smoke_color: Color = Color(0.34, 0.35, 0.38, 0.24)

@export_group("Ejected Casing")
@export var casing_lifetime: float = 0.44
@export var casing_size: Vector3 = Vector3(0.036, 0.012, 0.012)
@export var casing_color: Color = Color(0.78, 0.49, 0.12, 1.0)

@export_group("Tracer")
## 全射程の線はレーザーに見えるため、弾丸直後の短い残像だけを表示する。
@export var tracer_duration: float = 0.028
@export var tracer_start_distance: float = 0.75
@export var tracer_max_length: float = 1.6
@export var tracer_travel_distance: float = 0.55
@export var tracer_width: float = 0.014
@export var tracer_color: Color = Color(1.0, 0.78, 0.30, 0.48)
@export var tracer_emission_energy: float = 4.0

@export_group("Impact")
@export var impact_duration: float = 0.065
@export var impact_size: float = 0.12
@export var impact_color: Color = Color(1.0, 0.68, 0.22, 0.85)
@export var impact_emission_energy: float = 5.0
@export var impact_spark_amount: int = 7
@export var impact_spark_lifetime: float = 0.18

@export_group("Recoil")
@export var recoil_distance: float = 0.055
@export var recoil_lift: float = 0.018
@export var recoil_return_duration: float = 0.085
@export_range(0.0, 1.0, 0.01) var recoil_shake_strength: float = 0.28
@export var camera_shake_path: NodePath = ^"CameraShake"
@export_group("")

signal feedback_spawned(from: Vector3, to: Vector3, hit_body: Node3D)

var _radial_texture: Texture2D = null
var _streak_texture: Texture2D = null
var _recoil_tween: Tween = null
var _recoil_weapon: Node3D = null
var _recoil_base_position: Vector3 = Vector3.ZERO
var _camera_shake: Node = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_radial_texture = ProceduralGlow.make_radial_texture(RADIAL_TEXTURE_SIZE,
		TEXTURE_EDGE_POWER)
	_streak_texture = ProceduralGlow.make_streak_texture(STREAK_TEXTURE_LENGTH,
		STREAK_TEXTURE_WIDTH, TEXTURE_EDGE_POWER)
	_rng.randomize()


func play_shot(from: Vector3, to: Vector3, hit_body: Node3D, facing: int,
		weapon: Node3D) -> void:
	var visual_muzzle: Vector3 = from \
		+ Vector3(float(facing) * muzzle_forward_offset, 0.0, 0.0)
	_spawn_muzzle_flash(visual_muzzle, facing)
	_spawn_muzzle_smoke(visual_muzzle, facing)
	_spawn_casing(visual_muzzle, facing)
	_spawn_tracer(visual_muzzle, to)
	if hit_body != null:
		_spawn_impact(to, (to - visual_muzzle).normalized())
	_kick_weapon(weapon, facing)
	_shake_camera()
	feedback_spawned.emit(from, to, hit_body)


func _spawn_muzzle_flash(position: Vector3, facing: int) -> void:
	var anchor := Node3D.new()
	anchor.name = "GunMuzzleFlash"
	anchor.top_level = true
	add_child(anchor)
	anchor.global_position = position

	var halo := ProceduralGlow.make_quad(_radial_texture,
		Vector2.ONE * muzzle_core_size * 1.35, muzzle_flame_color,
		muzzle_flash_emission_energy * 0.55)
	halo.name = "MuzzleHalo"
	anchor.add_child(halo)
	var core := ProceduralGlow.make_quad(_radial_texture,
		Vector2.ONE * muzzle_core_size, muzzle_hot_color,
		muzzle_flash_emission_energy)
	core.name = "MuzzleWhiteCore"
	anchor.add_child(core)
	var flame := ProceduralGlow.make_quad(_streak_texture, muzzle_flame_size,
		muzzle_flame_color, muzzle_flash_emission_energy)
	flame.name = "MuzzleFlame"
	anchor.add_child(flame)
	flame.position.x = float(facing) * muzzle_flame_size.x * 0.38
	flame.rotation.z = PI if facing < 0 else 0.0
	for angle_sign: float in [-1.0, 1.0]:
		var side_flame := ProceduralGlow.make_quad(_streak_texture,
			muzzle_side_flame_size * _rng.randf_range(0.82, 1.12),
			muzzle_hot_color, muzzle_flash_emission_energy * 0.82)
		side_flame.name = "MuzzleSideFlame"
		anchor.add_child(side_flame)
		side_flame.position.x = float(facing) * muzzle_side_flame_size.x * 0.25
		var angle: float = muzzle_side_flame_angle_degrees \
			+ _rng.randf_range(-5.0, 5.0)
		side_flame.rotation.z = deg_to_rad(angle * angle_sign * float(facing)) \
			+ (PI if facing < 0 else 0.0)
	_spawn_muzzle_light(position)
	_fade_anchor(anchor, muzzle_flash_duration, 0.76)


func _spawn_muzzle_light(position: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "GunMuzzleLight"
	light.top_level = true
	light.light_color = muzzle_hot_color
	light.light_energy = muzzle_light_energy
	light.omni_range = muzzle_light_range
	light.omni_attenuation = 1.65
	light.shadow_enabled = false
	add_child(light)
	light.global_position = position
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0,
		maxf(muzzle_flash_duration, MIN_EFFECT_DURATION))
	tween.tween_callback(light.queue_free)


func _spawn_muzzle_smoke(position: Vector3, facing: int) -> void:
	if smoke_puff_count <= 0 or smoke_duration <= 0.0:
		return
	var anchor := Node3D.new()
	anchor.name = "GunMuzzleSmoke"
	anchor.top_level = true
	add_child(anchor)
	anchor.global_position = position
	for puff_index: int in smoke_puff_count:
		var size_variation: float = _rng.randf_range(0.78, 1.18)
		var puff := _make_smoke_quad(Vector2.ONE * smoke_start_size * size_variation)
		puff.name = "SmokePuff%02d" % puff_index
		anchor.add_child(puff)
		puff.position = Vector3(float(facing) * float(puff_index) * 0.035,
			_rng.randf_range(-0.025, 0.035), _rng.randf_range(-0.018, 0.018))
		puff.rotation.z = _rng.randf_range(-PI, PI)
		var duration: float = smoke_duration * _rng.randf_range(0.86, 1.08)
		var drift := Vector3(float(facing) * smoke_forward_drift,
			smoke_upward_drift, 0.0) * _rng.randf_range(0.78, 1.12)
		var tween := puff.create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "position", puff.position + drift, duration)
		tween.tween_property(puff, "scale", Vector3.ONE * smoke_end_scale, duration)
		tween.tween_property(puff, "transparency", 1.0, duration)
	var lifetime := anchor.create_tween()
	lifetime.tween_interval(smoke_duration * 1.12)
	lifetime.tween_callback(anchor.queue_free)


func _make_smoke_quad(size: Vector2) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = _radial_texture
	material.albedo_color = smoke_color
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	return mesh


func _spawn_casing(position: Vector3, facing: int) -> void:
	if casing_lifetime <= 0.0:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = casing_color
	material.metallic = 0.72
	material.roughness = 0.32
	var box := BoxMesh.new()
	box.size = casing_size
	box.material = material
	var casing := MeshInstance3D.new()
	casing.name = "GunCasing"
	casing.mesh = box
	casing.top_level = true
	add_child(casing)
	casing.global_position = position \
		+ Vector3(float(-facing) * 0.12, 0.055, _rng.randf_range(-0.025, 0.025))
	casing.rotation.z = _rng.randf_range(-0.4, 0.4)
	var apex := casing.global_position + Vector3(float(-facing) * 0.14,
		0.22, _rng.randf_range(-0.05, 0.05))
	var landing := apex + Vector3(float(-facing) * 0.16, -0.34,
		_rng.randf_range(-0.04, 0.04))
	var movement := casing.create_tween()
	movement.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	movement.tween_property(casing, "global_position", apex, casing_lifetime * 0.34)
	movement.set_ease(Tween.EASE_IN)
	movement.tween_property(casing, "global_position", landing, casing_lifetime * 0.66)
	movement.tween_callback(casing.queue_free)
	var spin := casing.create_tween().set_parallel(true)
	spin.tween_property(casing, "rotation:z",
		casing.rotation.z + float(facing) * TAU * 2.4, casing_lifetime)
	spin.tween_property(casing, "transparency", 1.0,
		casing_lifetime * 0.32).set_delay(casing_lifetime * 0.68)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var offset: Vector3 = to - from
	var distance: float = offset.length()
	if distance <= tracer_start_distance or tracer_max_length <= 0.0:
		return
	var direction: Vector3 = offset.normalized()
	var length: float = minf(distance - tracer_start_distance, tracer_max_length)
	var start: Vector3 = from + direction * tracer_start_distance
	var endpoint: Vector3 = start + direction * length
	var anchor := Node3D.new()
	anchor.name = "GunTracer"
	anchor.top_level = true
	add_child(anchor)
	anchor.global_position = start.lerp(endpoint, 0.5)
	anchor.rotation.z = atan2(direction.y, direction.x)
	var tracer := ProceduralGlow.make_quad(_streak_texture,
		Vector2(length, tracer_width), tracer_color, tracer_emission_energy)
	tracer.name = "TracerGlow"
	anchor.add_child(tracer)
	var core := ProceduralGlow.make_quad(_streak_texture,
		Vector2(length * 0.72, tracer_width * 0.36), muzzle_hot_color,
		tracer_emission_energy * 1.35)
	core.name = "TracerCore"
	anchor.add_child(core)
	var tween := anchor.create_tween().set_parallel(true)
	tween.tween_property(anchor, "global_position",
		anchor.global_position + direction * tracer_travel_distance,
		maxf(tracer_duration, MIN_EFFECT_DURATION))
	for child: Node in anchor.get_children():
		var visual := child as GeometryInstance3D
		if visual != null:
			tween.tween_property(visual, "transparency", 1.0,
				maxf(tracer_duration, MIN_EFFECT_DURATION))
	tween.chain().tween_callback(anchor.queue_free)


func _spawn_impact(position: Vector3, shot_direction: Vector3) -> void:
	var anchor := Node3D.new()
	anchor.name = "GunImpact"
	anchor.top_level = true
	add_child(anchor)
	anchor.global_position = position
	var impact := ProceduralGlow.make_quad(_radial_texture,
		Vector2.ONE * impact_size, impact_color, impact_emission_energy)
	impact.name = "ImpactFlash"
	anchor.add_child(impact)
	var core := ProceduralGlow.make_quad(_radial_texture,
		Vector2.ONE * impact_size * 0.38, muzzle_hot_color,
		impact_emission_energy * 1.35)
	core.name = "ImpactCore"
	anchor.add_child(core)
	_fade_anchor(anchor, impact_duration, 1.55)
	_spawn_impact_sparks(position, shot_direction)


func _spawn_impact_sparks(position: Vector3, shot_direction: Vector3) -> void:
	if impact_spark_amount <= 0 or impact_spark_lifetime <= 0.0:
		return
	var particles := GPUParticles3D.new()
	particles.name = "GunImpactSparks"
	particles.top_level = true
	add_child(particles)
	particles.global_position = position
	particles.amount = impact_spark_amount
	particles.lifetime = impact_spark_lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.55
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0),
		Vector3(4.0, 4.0, 4.0))
	var process := ParticleProcessMaterial.new()
	process.direction = (-shot_direction + Vector3.UP * 0.28).normalized()
	process.spread = 42.0
	process.initial_velocity_min = 0.9
	process.initial_velocity_max = 2.4
	process.damping_min = 2.0
	process.damping_max = 4.0
	process.gravity = Vector3(0.0, -5.5, 0.0)
	process.scale_min = 0.65
	process.scale_max = 1.15
	process.particle_flag_align_y = true
	process.color_ramp = _spark_ramp()
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.075)
	quad.material = ProceduralGlow.make_material(_streak_texture,
		impact_color, impact_emission_energy, true)
	particles.draw_pass_1 = quad
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func _spark_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.38, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.96, 0.76, 1.0),
		Color(1.0, 0.48, 0.08, 0.86),
		Color(0.55, 0.12, 0.01, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


func _kick_weapon(weapon: Node3D, facing: int) -> void:
	_reset_recoil_weapon()
	if weapon == null or not is_instance_valid(weapon):
		return
	var weapon_parent := weapon.get_parent() as Node3D
	if weapon_parent == null:
		return
	_recoil_weapon = weapon
	_recoil_base_position = weapon.position
	var world_offset := Vector3(float(-facing) * recoil_distance, recoil_lift, 0.0)
	var local_offset: Vector3 = weapon_parent.global_transform.basis.inverse() * world_offset
	weapon.position = _recoil_base_position + local_offset
	_recoil_tween = create_tween()
	_recoil_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(weapon, "position", _recoil_base_position,
		maxf(recoil_return_duration, MIN_EFFECT_DURATION))
	_recoil_tween.finished.connect(_on_recoil_finished, CONNECT_ONE_SHOT)


func _reset_recoil_weapon() -> void:
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	if _recoil_weapon != null and is_instance_valid(_recoil_weapon):
		_recoil_weapon.position = _recoil_base_position
	_recoil_tween = null
	_recoil_weapon = null


func _on_recoil_finished() -> void:
	_recoil_tween = null
	_recoil_weapon = null


func _shake_camera() -> void:
	if _camera_shake == null or not is_instance_valid(_camera_shake):
		_camera_shake = null
		var camera := get_tree().get_first_node_in_group(&"belt_camera")
		if camera != null:
			_camera_shake = camera.get_node_or_null(camera_shake_path)
	if _camera_shake != null and _camera_shake.has_method("shake"):
		_camera_shake.call("shake", recoil_shake_strength)


func _fade_anchor(anchor: Node3D, duration: float, end_scale: float) -> void:
	var effect_duration: float = maxf(duration, MIN_EFFECT_DURATION)
	var tween := anchor.create_tween().set_parallel(true)
	for child: Node in anchor.get_children():
		var visual := child as GeometryInstance3D
		if visual != null:
			tween.tween_property(visual, "transparency", 1.0, effect_duration)
	tween.tween_property(anchor, "scale", Vector3.ONE * end_scale, effect_duration)
	tween.chain().tween_callback(anchor.queue_free)


func _fade_visual(visual: GeometryInstance3D, duration: float) -> void:
	var tween := visual.create_tween()
	tween.tween_property(visual, "transparency", 1.0,
		maxf(duration, MIN_EFFECT_DURATION))
	tween.tween_callback(visual.queue_free)
