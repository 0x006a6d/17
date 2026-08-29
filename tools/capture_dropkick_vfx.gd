extends Node3D

## △ドロップキックだけを真横から60fpsで撮る視覚QC。

const PLAYER: PackedScene = preload("res://actors/player/player.tscn")
const ENEMY: PackedScene = preload("res://actors/enemy/enemy.tscn")

var _player: Node3D
var _action: Node
var _frames: int = 0
var _started: bool = false


func _ready() -> void:
	# 比較撮影へ実機の押下状態を混ぜない。InputMap の変更はこのプロセス内だけで、
	# project.godot には保存されない。
	for action: StringName in [
			&"move_left", &"move_right", &"move_forward", &"move_back"]:
		InputMap.action_erase_events(action)
	get_window().size = Vector2i(1280, 720)
	_build_world()


func _build_world() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(24.0, 0.5, 8.0)
	collision.shape = floor_shape
	collision.position = Vector3(0.0, -0.25, 0.0)
	floor_body.add_child(collision)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = floor_shape.size
	floor_mesh.mesh = box
	floor_mesh.position = collision.position
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.19, 0.205, 0.24)
	floor_material.metallic = 0.15
	floor_material.roughness = 0.68
	floor_mesh.material_override = floor_material
	floor_body.add_child(floor_mesh)
	add_child(floor_body)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -24.0, 0.0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	add_child(light)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.045, 0.07)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.46, 0.56)
	environment.ambient_light_energy = 0.52
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.78
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.18
	environment.glow_hdr_threshold = 0.78
	environment.glow_hdr_scale = 2.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)

	_player = PLAYER.instantiate() as Node3D
	add_child(_player)
	_player.global_position = Vector3(-3.0, 0.1, 0.0)
	_player.set("_facing", 1)
	_player.set_process_unhandled_input(false)
	_action = _player.get_node(^"PlayerAction")

	var enemy := ENEMY.instantiate() as Node3D
	add_child(enemy)
	enemy.global_position = Vector3(1.35, 0.1, 0.0)
	enemy.rotation.y = PI * 0.5
	if "knockback_speed" in enemy:
		enemy.set("knockback_speed", 0.0)
	enemy.set_physics_process(false)
	var health := enemy.get_node_or_null(^"Health") as Health
	if health != null:
		health.max_hp = 1000.0
		health.revive()

	var camera := Camera3D.new()
	camera.position = Vector3(0.1, 1.72, 6.25)
	camera.fov = 48.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.08, 0.0), Vector3.UP)
	camera.make_current()

	var vfx := _player.get_node(^"DropkickVfx3D")
	vfx.connect("impact_spawned", func(center: Vector3, radius: float) -> void:
		print("[dropkick-impact] frame=%d center=%s damage_radius=%.2f" % [
			_frames, str(center), radius]))


func _physics_process(_delta: float) -> void:
	_frames += 1
	if not _started and _frames >= 60:
		_started = true
		# Movie Maker 中にデスクトップ側の入力状態が混ざっても、比較撮影は
		# 常に参照と同じ右向きで開始する。
		_player.set("_facing", 1)
		_action.call("_try_special")
		print("[dropkick-start] frame=%d" % _frames)
	if _frames >= 210:
		get_tree().quit()
