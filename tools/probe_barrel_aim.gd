extends Node

## 銃身の向きに沿って撃ったら本当に当たらないのか、実際のレイで確かめる。
##   godot --path . --headless res://tools/probe_barrel_aim.tscn
##
## 経緯: 「銃身が +6 度上を向いているので、そのまま撃つと当たらない」と三角比だけで
## 言ったが、裏を取っていなかった。当たり判定はカプセルで太さがあり、ボスは距離を
## 保って動くので、机上の計算と実物は食い違いうる。
##
## 測り方: 実戦と同じ距離（gun_retreat_distance 〜 gun_preferred_distance）にボスを
## 置き、武器モデルの実際の銃口と銃身の向きからレイを飛ばして、何に当たるかを見る。
## 比較のため、いまの実装（水平に狙う）でも同じことをする。

const STAGE_PATH: String = "res://levels/belt_test.tscn"
const BOSS_PATH: String = "res://actors/enemy/bosses/stage_3_boss.tscn"
const DUMMY_NAMES: Array[String] = ["Dummy1", "Dummy2", "Dummy3"]
## 試す距離（m）。retreat 3.0 〜 preferred 4.5 の範囲と、その外側も少し見る。
const DISTANCES: Array[float] = [2.5, 3.0, 3.75, 4.5, 5.5]
const RAY_LENGTH: float = 20.0


func _ready() -> void:
	RunState.reset()
	var stage := (load(STAGE_PATH) as PackedScene).instantiate()
	add_child(stage)
	for dummy_name: String in DUMMY_NAMES:
		var dummy := stage.get_node_or_null(dummy_name)
		if dummy != null:
			dummy.queue_free()
	var player := stage.get_node_or_null("Player") as Node3D
	if player == null:
		print("[aim] Player が無い")
		get_tree().quit(1)
		return
	player.position = Vector3.ZERO

	var boss := (load(BOSS_PATH) as PackedScene).instantiate() as Node3D
	stage.add_child(boss)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var animator := boss.get_node_or_null("Animator") as NpcAnimator
	var loadout := boss.get_node_or_null("WeaponLoadout") as WeaponLoadout
	if animator == null or loadout == null or not loadout.has_weapon():
		print("[aim] ボスの部品が揃っていない")
		get_tree().quit(1)
		return

	_report_player_box(player)
	for clip_entry: Array in [["待機", NpcAnimator.Clip.IDLE, 0.0],
			["発砲", NpcAnimator.Clip.FIRE, 0.35]]:
		animator.play(int(clip_entry[1]), 0.0, 1.0, true, float(clip_entry[2]))
		for frame: int in 4:
			await get_tree().physics_frame
		print("[aim] === %s の姿勢 ===" % clip_entry[0])
		for distance: float in DISTANCES:
			# ボスはプレイヤーの +X 側に立ち、-X を向く（実戦と同じ横並び）。
			boss.position = Vector3(distance, 0.2, 0.0)
			boss.rotation_degrees = Vector3(0.0, -90.0, 0.0)
			for frame: int in 2:
				await get_tree().physics_frame
			_probe(boss, loadout, player, distance)
	get_tree().quit()


## プレイヤーの当たり判定の実寸。高さの上限がどこかを先に出す。
func _report_player_box(player: Node3D) -> void:
	var hurtbox := player.get_node_or_null("Hurtbox") as Area3D
	if hurtbox == null:
		return
	for child: Node in hurtbox.get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.shape == null:
			continue
		var capsule := collision.shape as CapsuleShape3D
		if capsule == null:
			continue
		var center: float = collision.global_position.y
		print("[aim] プレイヤーの当たり判定: 中心 %.2f m / 高さ %.2f m / 半径 %.2f m → %.2f 〜 %.2f m"
			% [center, capsule.height, capsule.radius,
				center - capsule.height * 0.5, center + capsule.height * 0.5])


func _probe(boss: Node3D, loadout: WeaponLoadout, player: Node3D,
		distance: float) -> void:
	var weapon: Node3D = loadout.current_weapon()
	var muzzle: Vector3 = _muzzle_world(weapon, boss)
	var grip: Vector3 = _grip_world(weapon)
	var barrel: Vector3 = (muzzle - grip).normalized()
	var tilt: float = rad_to_deg(asin(clampf(barrel.y, -1.0, 1.0)))

	# 銃身に沿って撃った場合。
	var along_barrel: Dictionary = _cast(boss, muzzle, muzzle + barrel * RAY_LENGTH)
	# いまの実装（水平の狙い点へ撃つ）。
	var target := Vector3(player.global_position.x, boss.global_position.y
		+ float(boss.get("gun_muzzle_height")), player.global_position.z)
	var horizontal: Dictionary = _cast(boss, muzzle, target)

	# プレイヤーの真上を通る高さ（外れる場合にどれだけ上か）。
	var dx: float = absf(muzzle.x - player.global_position.x)
	var height_at_player: float = muzzle.y + barrel.y / maxf(absf(barrel.x), 0.0001) * dx

	print("[aim] 距離 %.2f m  銃口 %.2f m  傾き %+.1f 度  プレイヤー位置での高さ %.2f m"
		% [distance, muzzle.y, tilt, height_at_player])
	print("[aim]   銃身なり: %s / 水平狙い: %s"
		% [_describe(along_barrel), _describe(horizontal)])


func _describe(hit: Dictionary) -> String:
	if hit.is_empty():
		return "何にも当たらない"
	var collider: Object = hit.get("collider")
	var name: String = "?"
	var node := collider as Node
	if node != null:
		name = node.name
		var owner_body := node.get_parent()
		if owner_body != null:
			name = "%s/%s" % [owner_body.name, node.name]
	return "%s に命中（%.2f m の高さ）" % [name, (hit["position"] as Vector3).y]


func _cast(boss: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var space := boss.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	# 敵の当たり判定は Hurtbox（layer 7 = mask 1<<6）。自分は除く。
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1 << 6
	var exclude: Array[RID] = []
	for node: Node in boss.find_children("*", "Area3D", true, false):
		exclude.append((node as Area3D).get_rid())
	query.exclude = exclude
	return space.intersect_ray(query)


func _muzzle_world(weapon: Node3D, boss: Node3D) -> Vector3:
	var forward: Vector3 = -boss.global_transform.basis.z
	forward.y = 0.0
	var local_forward: Vector3 = (weapon.global_transform.basis.orthonormalized().inverse()
		* forward.normalized())
	var best := Vector3.ZERO
	var best_distance: float = -INF
	for node: Node in weapon.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var verts: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(
				surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in verts:
				var local: Vector3 = mesh_instance.transform * vertex
				var along: float = local.dot(local_forward)
				if along > best_distance:
					best_distance = along
					best = local
	return weapon.global_transform * best


## 握り（受けの下、X -0.6..0.4 の Y<0）の重心。銃身の向きの基準にする。
func _grip_world(weapon: Node3D) -> Vector3:
	var sum := Vector3.ZERO
	var count: int = 0
	for node: Node in weapon.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var verts: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(
				surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in verts:
				var local: Vector3 = mesh_instance.transform * vertex
				if local.x < -0.6 or local.x > 0.4 or local.y > 0.0:
					continue
				sum += local
				count += 1
	if count == 0:
		return weapon.global_position
	return weapon.global_transform * (sum / float(count))
