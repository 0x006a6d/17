extends "res://tools/capture_combo.gd"

## 現行ベルト方向（攻撃 +X）を真横（カメラ -Z）から撮る蹴りVFX専用QC。
## 右膝→右ミドル→右MMAハイを60fpsで収録し、足追従とhit-onlyを確認する。

const ENEMY_SCENE: PackedScene = preload("res://actors/enemy/enemy.tscn")

@export var capture_name: String = "kick_side"
@export_range(0.8, 3.0, 0.05) var target_x: float = 1.0


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	scenario = capture_name
	_build_stage()
	_key = KEY_K
	_press_times = [1.0, 1.35, 1.70]
	_end_time = 3.35
	_pressed = [false, false, false]
	_csv.append("frame,time,state,node,pos,hitbox_monitoring")


func _build_stage() -> void:
	super._build_stage()
	_player.position = Vector3(0.0, 0.1, 0.0)

	# Hit confirmation stays on the stable dummy Hurtbox.  Disabling the full
	# Enemy tree also disables its Area3D participation, which made the first
	# side capture an accidental all-miss recording.  The capsule mesh is hidden
	# and a non-colliding Enemy is kept only as the visual comparison target.
	var old_target := _dummy_hurtbox.get_parent() as Node3D
	old_target.position = Vector3(target_x, 0.1, 0.0)
	old_target.set("knockback_speed", 0.0)
	var dummy_health := old_target.get_node_or_null(^"Health") as Health
	if dummy_health != null:
		# Visual QC must survive all three current damage-scaled kick stages.
		dummy_health.max_hp = 1000000.0
		dummy_health.revive()
	var dummy_mesh := old_target.get_node_or_null(^"Mesh") as MeshInstance3D
	if dummy_mesh != null:
		dummy_mesh.visible = false
	var enemy := ENEMY_SCENE.instantiate() as Node3D
	add_child(enemy)
	enemy.position = Vector3(target_x, 0.1, 0.0)
	enemy.rotation.y = PI * 0.5
	if enemy is CollisionObject3D:
		(enemy as CollisionObject3D).collision_layer = 0
		(enemy as CollisionObject3D).collision_mask = 0
	enemy.set_physics_process(false)
	var visual_hurtbox := enemy.get_node(^"Hurtbox") as Area3D
	visual_hurtbox.collision_layer = 0
	visual_hurtbox.collision_mask = 0
	visual_hurtbox.monitoring = false
	visual_hurtbox.monitorable = false
	var visual_hitbox := enemy.get_node(^"MeleeHitbox") as Area3D
	visual_hitbox.collision_layer = 0
	visual_hitbox.collision_mask = 0
	visual_hitbox.monitoring = false
	visual_hitbox.monitorable = false
	var animator := enemy.get_node_or_null(^"Animator") as NpcAnimator
	if animator != null:
		animator.play(NpcAnimator.Clip.IDLE, 0.0, 1.0, true)

	var camera: Camera3D = null
	for child: Node in get_children():
		if child is Camera3D:
			camera = child as Camera3D
			break
	if camera != null:
		var camera_center_x := target_x * 0.5
		camera.position = Vector3(camera_center_x, 1.35, 3.2)
		camera.fov = 50.0
		camera.look_at(Vector3(camera_center_x, 1.05, 0.0), Vector3.UP)
		camera.make_current()

	_hitbox.impact_landed.connect(func(_target: Node3D,
			impact_position: Vector3) -> void:
		print("[kick-side-hit] frame=%d state=%s position=%s" % [
			_frames, str(_melee.get("_state")), str(impact_position)]))
	var slash := _player.get_node_or_null(^"ImpactSlash3D")
	if slash != null and slash.has_signal("phase_spawned"):
		slash.connect("phase_spawned", func(technique: StringName,
				phase: StringName) -> void:
			print("[kick-side-phase] frame=%d technique=%s phase=%s" % [
				_frames, str(technique), str(phase)]))
