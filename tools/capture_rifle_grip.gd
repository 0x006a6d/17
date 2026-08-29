extends Node3D

## 3面ボスにライフルを持たせた手元の確認。握りの数値を詰めるための撮影で、
## 描画結果が要るので --headless では実行しない。
##
## 実行: godot --path . tools/capture_rifle_grip.tscn
##
## 待機クリップ（rifle aiming idle）を再生した状態で、正面・斜め・真横の3方向から
## 上半身を撮る。手とライフルの位置関係だけを見るため、床も背景も置かない。

const BOSS_PATH: String = "res://actors/enemy/bosses/stage_3_boss.tscn"
const OUTPUT_PREFIX: String = "res://docs/img/qc_rifle_grip"
const CAPTURE_SIZE: Vector2i = Vector2i(900, 900)
## モデル差し込みが deferred なので、待機に入るまで余裕を持って待つ。
const SETTLE_FRAMES: int = 90
## 撮ってから次の向きへ移るまでの待ち。
const SHOT_FRAMES: int = 6
## 上半身の中心（足元からの高さ）。
const FOCUS_HEIGHT: float = 1.25
const DISTANCE: float = 1.5
## [名前, 水平角（度。0 が正面＝キャラクターの向いている側）]
## キャラクターは -Z を向くので、正面はカメラを -Z 側へ置く。
const SHOTS: Array = [
	["front", 180.0],
	["quarter", 220.0],
	["side", 270.0],
]
## 発砲クリップの、撃った瞬間に近い位置（秒）。
const FIRE_SAMPLE_TIME: float = 0.35
## 握り（右手が持つ位置）を探すモデル座標の X 範囲。受けの下の後ろ寄り。
const GRIP_X_RANGE := Vector2(-0.6, 0.4)
## handguard（左手を添える位置）は木部で決める。範囲を座標で切ると、ローポリでは
## 頂点が角にしか無いため「面はあるのに頂点が無い帯」を空と誤判定する。
## マテリアル名で取れば、木がどこにあるかをモデル自身に答えさせられる。
const FORE_MATERIAL: String = "Wood"
## 木部は銃床（後ろ）と handguard（前）に分かれている。受けより前だけを見る。
const FORE_X_MIN: float = 1.0

var _boss: Node3D = null


func _ready() -> void:
	get_window().size = CAPTURE_SIZE
	RunState.reset()
	_add_lights()
	_boss = (load(BOSS_PATH) as PackedScene).instantiate() as Node3D
	add_child(_boss)
	# 物理で落ちないよう固定する。見るのは上半身だけ。
	if _boss is CharacterBody3D:
		(_boss as CharacterBody3D).set_physics_process(false)
	_boss.position = Vector3.ZERO
	await _capture_all()
	get_tree().quit()


func _add_lights() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30.0, -35.0, 0.0)
	key.light_energy = 1.6
	add_child(key)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.ambient_light_energy = 1.0
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _capture_all() -> void:
	for frame: int in SETTLE_FRAMES:
		await get_tree().process_frame
	_play_idle()
	for frame: int in SETTLE_FRAMES:
		await get_tree().process_frame
	_report_geometry()
	var animator: NpcAnimator = _find_animator()
	var skeletons: Array[Node] = _boss.find_children("*", "Skeleton3D", true, false)
	if animator != null and not skeletons.is_empty():
		await report_clip_hands(animator, skeletons[0] as Skeleton3D)
		var loadout := _boss.get_node_or_null("WeaponLoadout") as WeaponLoadout
		if loadout != null and loadout.has_weapon():
			await report_barrel_tilt(animator, loadout.current_weapon())
			report_fore_profile(loadout.current_weapon())
		animator.play(NpcAnimator.Clip.IDLE, 0.0, 1.0, true)
		for frame: int in 8:
			await get_tree().process_frame

	var camera := Camera3D.new()
	camera.fov = 45.0
	add_child(camera)
	camera.make_current()
	var focus := Vector3(0.0, FOCUS_HEIGHT, 0.0)
	for shot: Array in SHOTS:
		var angle: float = deg_to_rad(float(shot[1]))
		camera.position = focus + Vector3(sin(angle), 0.12, cos(angle)) * DISTANCE
		camera.look_at(focus, Vector3.UP)
		for frame: int in SHOT_FRAMES:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = "%s_%s.png" % [OUTPUT_PREFIX, String(shot[0])]
		var err: int = get_viewport().get_texture().get_image().save_png(path)
		print("[grip] %s (%d)" % [path, err])

	# 発砲の姿勢も1枚撮る。撃つ絵は待機とは腕の角度が違うので別に見る。
	await _capture_fire(camera, focus)
	# ゲームと同じ見え方（ベルトスクロールの真横）でも撮る。孤立した確認用の画だけ
	# だと、実際の画面で銃がどう見えるかを取り違える。
	await _capture_gameplay_view(camera, focus)
	# 銃口炎も1枚。出ているかどうかは絵で見るしかない。
	await _capture_muzzle(camera, focus)


## 実際に撃たせて、銃口炎が出た瞬間を撮る。
func _capture_muzzle(camera: Camera3D, focus: Vector3) -> void:
	var gun := _boss.get_node_or_null("HitscanGun") as HitscanGun
	if gun == null:
		print("[grip] HitscanGun が無いので銃口炎は撮らない")
		return
	_boss.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	camera.position = focus + Vector3(0.0, 0.0, 1.0) * DISTANCE * 1.6
	camera.look_at(focus, Vector3.UP)
	for frame: int in SHOT_FRAMES * 3:
		await get_tree().process_frame
	# 銃口の置き方は本体に任せる。ここで独自に計算すると、実機でのズレを見逃す。
	# 撃つ姿勢で撮る（腕が動くこの姿勢が、いちばんズレの出やすい場面）。
	var animator: NpcAnimator = _find_animator()
	if animator != null and animator.has_clip(NpcAnimator.Clip.FIRE):
		animator.play(NpcAnimator.Clip.FIRE, 0.0, 1.0, true, FIRE_SAMPLE_TIME)
		await get_tree().process_frame
	_boss.call("_update_muzzle_position")
	var forward: Vector3 = -_boss.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	# 実戦と同じ狙い点（相手の胸の高さ）へ撃つ。水平に撃つと傾きが出ず、
	# 銃口炎の向きが合っているかを確かめられない。
	var aim_height: float = float(_boss.get("gun_muzzle_height"))
	var target: Vector3 = _boss.global_position + forward * 4.0
	target.y = _boss.global_position.y + aim_height
	gun.fire_at(target)
	await RenderingServer.frame_post_draw
	var path: String = "%s_muzzle.png" % OUTPUT_PREFIX
	print("[grip] %s (%d)" % [path,
		get_viewport().get_texture().get_image().save_png(path)])


## ベルトスクロールの画に合わせる。敵は X 方向を向き、カメラは +Z から真横に見る。
func _capture_gameplay_view(camera: Camera3D, focus: Vector3) -> void:
	var animator: NpcAnimator = _find_animator()
	if animator != null:
		animator.play(NpcAnimator.Clip.IDLE, 0.0, 1.0, true)
	for facing: Array in [["left", 90.0], ["right", -90.0]]:
		_boss.rotation_degrees = Vector3(0.0, float(facing[1]), 0.0)
		camera.position = focus + Vector3(0.0, 0.0, 1.0) * DISTANCE
		camera.look_at(focus, Vector3.UP)
		for frame: int in SHOT_FRAMES * 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = "%s_game_%s.png" % [OUTPUT_PREFIX, String(facing[0])]
		print("[grip] %s (%d)" % [path,
			get_viewport().get_texture().get_image().save_png(path)])


## 発砲クリップを再生した状態で斜めから1枚。
func _capture_fire(camera: Camera3D, focus: Vector3) -> void:
	var animator: NpcAnimator = _find_animator()
	if animator == null or not animator.has_clip(NpcAnimator.Clip.FIRE):
		print("[grip] 発砲クリップが無いので撮らない")
		return
	# カメラを先に決めてから再生する。再生してから待つと、待った分だけクリップが
	# 進み、FIRE_SAMPLE_TIME ではなくその先の姿勢を撮ってしまう。
	var angle: float = deg_to_rad(220.0)
	camera.position = focus + Vector3(sin(angle), 0.12, cos(angle)) * DISTANCE
	camera.look_at(focus, Vector3.UP)
	for frame: int in SHOT_FRAMES:
		await get_tree().process_frame
	animator.play(NpcAnimator.Clip.FIRE, 0.0, 1.0, true, FIRE_SAMPLE_TIME)
	# seek(update=false) なので、姿勢が反映されるのは次の処理フレーム。1枚だけ待つ
	# （撮れるのは FIRE_SAMPLE_TIME + 1フレームぶんの姿勢）。
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = "%s_fire.png" % OUTPUT_PREFIX
	print("[grip] %s (%d)" % [path,
		get_viewport().get_texture().get_image().save_png(path)])


func _find_animator() -> NpcAnimator:
	for node: Node in _boss.find_children("*", "Node", true, false):
		var animator := node as NpcAnimator
		if animator != null:
			return animator
	return null


## 握りを数値で詰めるための実測。武器モデルのローカル範囲と、右手ボーンに対する
## 現在の武器の位置を出す。目分量で offset を動かさないための材料。
func _report_geometry() -> void:
	var loadout := _boss.get_node_or_null("WeaponLoadout") as WeaponLoadout
	if loadout == null or not loadout.has_weapon():
		print("[grip] 武器が装備されていない")
		return
	var weapon: Node3D = loadout.current_weapon()
	var aabb := AABB()
	var first: bool = true
	for node: Node in weapon.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var box: AABB = mesh_instance.transform * mesh_instance.mesh.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	print("[grip] 武器ローカル AABB  min=%v  max=%v  size=%v" % [aabb.position, aabb.end, aabb.size])
	print("[grip] 武器の原点は AABB 中心から %v ずれている" % (-aabb.get_center()))
	var skeletons: Array[Node] = _boss.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	for name: String in ["RightHand", "LeftHand"]:
		var index: int = skeleton.find_bone(name)
		if index < 0:
			continue
		var pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(index)
		print("[grip] %s ワールド位置 %v" % [name, pose.origin])
	print("[grip] 武器ワールド位置 %v" % weapon.global_position)
	_solve_grip(weapon, skeleton)


## 構えの姿勢から grip_rotation / grip_offset / grip_scale をまとめて逆算する。
##
## 銃の握り（右手が持つ位置）と handguard（左手が添える位置）の2点を、構えの
## 右手・左手の位置へ重ねる。向きだけを合わせても、原点が握りの位置にあるとは
## 限らないので銃が手からずれる。2点で合わせると位置・向き・大きさが同時に決まる。
##
## 2点のモデル座標は tools/ の占有マップで実測した X の範囲から重心で取る。
## AK 型のこのモデルでは、握りは受け（レシーバー）の下の後ろ寄り、handguard は
## 銃身側の上面にある。
func _solve_grip(weapon: Node3D, skeleton: Skeleton3D) -> void:
	# 合わせ先は手首ボーンではなく拳の中心。手首に合わせると銃が後ろへずれる。
	var right_hand: Vector3 = _hand_center(skeleton, "Right")
	var left_hand: Vector3 = _hand_center(skeleton, "Left")
	if right_hand.is_equal_approx(Vector3.ZERO) or left_hand.is_equal_approx(Vector3.ZERO):
		print("[grip] 手のボーンが見つからない")
		return

	var grip_result: Dictionary = _centroid(weapon, GRIP_X_RANGE, -INF, 0.0)
	# handguard は頂点の重心ではなく範囲の中央を取る。重心は分割の粗密に引っ張られ、
	# このモデルでは後ろ側に頂点が多いため（X 1.5..2.0 に 130 点、2.0..2.5 に 40 点）
	# 手が木部の後端へ寄る。手を置くべきなのは木部の真ん中。
	var fore_result: Dictionary = _extent_center(weapon,
		Vector2(FORE_X_MIN, INF), FORE_MATERIAL)
	var grip_count: int = int(grip_result["count"])
	var fore_count: int = int(fore_result["count"])
	# 片方でも頂点が取れなければ止める。重心が偶然 Vector3.ZERO になる場合と
	# 「1点も入らなかった」場合を取り違えないよう、点数で判定する。
	if grip_count == 0 or fore_count == 0:
		print("[grip] 握り／handguard の頂点が取れない（握り %d 点 / handguard %d 点）。"
			% [grip_count, fore_count]
			+ "GRIP_X_RANGE / FORE_X_RANGE をモデルに合わせて見直すこと")
		return
	var grip: Vector3 = grip_result["point"]
	var fore: Vector3 = fore_result["point"]
	print("[grip] モデル座標の握り %v（重心）/ handguard %v（範囲の中央、広さ %v）"
		% [grip, fore, fore_result.get("size", Vector3.ZERO)])
	print("[grip] 握り→handguard %.2f ユニット" % grip.distance_to(fore))

	var hand_span: float = right_hand.distance_to(left_hand)
	var model_span: float = grip.distance_to(fore)
	if model_span <= 0.0:
		return
	# BoneAttachment はスケルトンから拡縮を受け継ぐ（このモデルでは 1.15 倍）。
	# .tscn に書く値はその内側なので、割っておかないと銃がその分だけ大きくなる。
	var attach_node := weapon.get_parent() as Node3D
	var attach_scale: float = 1.0
	if attach_node != null:
		attach_scale = maxf(attach_node.global_transform.basis.get_scale().x, 0.0001)
	var scale: float = hand_span / model_span / attach_scale
	var barrel: Vector3 = (left_hand - right_hand).normalized()
	var model_axis: Vector3 = (fore - grip).normalized()

	# モデル軸を銃身の向きへ回し、銃身まわりの回りは「銃の上が世界の上を向く」方で決める。
	var swing := Basis(model_axis.cross(barrel).normalized(),
		acos(clampf(model_axis.dot(barrel), -1.0, 1.0))) if not model_axis.is_equal_approx(barrel) else Basis()
	var best := swing
	var best_up: float = -INF
	for step: int in 72:
		var roll := Basis(barrel, TAU * float(step) / 72.0) * swing
		var up: float = (roll * Vector3.UP).dot(Vector3.UP)
		if up > best_up:
			best_up = up
			best = roll
	var attach := weapon.get_parent() as Node3D
	if attach == null:
		return
	var attach_basis: Basis = attach.global_transform.basis.orthonormalized()
	var local := Basis(attach_basis.inverse() * best)
	var euler: Vector3 = local.get_euler() * 180.0 / PI
	# 握りが右手（拳の中心）へ来るよう原点をずらす。BoneAttachment の原点は手首に
	# あるので、手首から拳の中心までのぶんも足す。これを忘れると、狙いを拳の中心に
	# しても銃は手首へ吸い寄せられたままになる（実測で 6cm ずれた）。
	var wrist_to_hand: Vector3 = attach_basis.inverse() \
		* (right_hand - attach.global_transform.origin) / attach_scale
	var offset: Vector3 = wrist_to_hand - local * (grip * scale)
	print("[grip] grip_rotation = Vector3(%.1f, %.1f, %.1f)" % [euler.x, euler.y, euler.z])
	print("[grip] grip_offset   = Vector3(%.4f, %.4f, %.4f)" % [offset.x, offset.y, offset.z])
	print("[grip] grip_scale    = %.4f（両手 %.3f m ÷ モデル %.2f ユニット ÷ 拡縮 %.2f）"
		% [scale, hand_span, model_span, attach_scale])
	_verify_grip(weapon, grip, fore, right_hand, left_hand)
	_report_muzzle(weapon)
	_report_fore_axis(weapon)
	_report_hand_centers(skeleton)
	_report_grip_axis(weapon)


## クリップごとの両手の位置を測る。握りは1つの姿勢からしか解けないので、
## クリップ間で両手の間隔や向きが違うと、解いていないクリップでは銃が手からずれる。
## 待機で合わせても歩き・走りでずれていないかを、ここで数字にする。
func report_clip_hands(animator: NpcAnimator, skeleton: Skeleton3D) -> void:
	print("[grip] --- クリップごとの両手 ---")
	for entry: Array in [
			["待機", NpcAnimator.Clip.IDLE],
			["歩き", NpcAnimator.Clip.WALK],
			["走り", NpcAnimator.Clip.RUN],
			["発砲", NpcAnimator.Clip.FIRE]]:
		var clip: int = int(entry[1])
		if not animator.has_clip(clip):
			print("[grip] %s: クリップ無し" % entry[0])
			continue
		animator.play(clip, 0.0, 1.0, true)
		for frame: int in 4:
			await get_tree().process_frame
		# 解く側と同じ点（拳の中心）で測る。手首で測ると、クリップ差を判断する
		# 数字と、実際に銃を合わせている数字が別物になる。
		var right_position: Vector3 = _hand_center(skeleton, "Right")
		var left_position: Vector3 = _hand_center(skeleton, "Left")
		if right_position.is_equal_approx(Vector3.ZERO) \
				or left_position.is_equal_approx(Vector3.ZERO):
			continue
		var span: float = right_position.distance_to(left_position)
		var direction: Vector3 = (left_position - right_position).normalized()
		print("[grip] %-4s 右 %v 左 %v  間隔 %.3f m  向き %v"
			% [entry[0], right_position, left_position, span, direction])


## 実際に物を握る位置（拳の中心）。手首ボーンと指の付け根の中点とみなす。
## 手首に合わせると、この差（実測 6cm 前後）だけ銃が後ろへずれる。
## 指ボーンが無いモデルでは手首をそのまま返す。
func _hand_center(skeleton: Skeleton3D, side: String) -> Vector3:
	var wrist: int = skeleton.find_bone(side + "Hand")
	if wrist < 0:
		return Vector3.ZERO
	var wrist_position: Vector3 = (skeleton.global_transform
		* skeleton.get_bone_global_pose(wrist)).origin
	var knuckles := Vector3.ZERO
	var found: int = 0
	for finger: String in ["IndexProximal", "MiddleProximal",
			"RingProximal", "LittleProximal"]:
		var index: int = skeleton.find_bone(side + finger)
		if index < 0:
			continue
		knuckles += (skeleton.global_transform
			* skeleton.get_bone_global_pose(index)).origin
		found += 1
	if found == 0:
		return wrist_position
	return wrist_position.lerp(knuckles / float(found), 0.5)


## 手首ボーンと、実際に物を握る位置（拳の中心）の差を測る。
## 合わせ先を手首にすると、その差のぶんだけ銃が手からずれる。
## 拳の中心は、手首と指の付け根（Index1/Middle1/Ring1/Pinky1 の重心）の中点とみなす。
func _report_hand_centers(skeleton: Skeleton3D) -> void:
	for side: String in ["Right", "Left"]:
		var wrist: int = skeleton.find_bone(side + "Hand")
		if wrist < 0:
			continue
		var wrist_position: Vector3 = (skeleton.global_transform
			* skeleton.get_bone_global_pose(wrist)).origin
		var knuckles := Vector3.ZERO
		var found: int = 0
		for finger: String in ["IndexProximal", "MiddleProximal",
				"RingProximal", "LittleProximal"]:
			var index: int = skeleton.find_bone(side + finger)
			if index < 0:
				continue
			knuckles += (skeleton.global_transform
				* skeleton.get_bone_global_pose(index)).origin
			found += 1
		if found == 0:
			print("[grip] %sHand の指ボーンが見つからない" % side)
			continue
		knuckles /= float(found)
		var center: Vector3 = wrist_position.lerp(knuckles, 0.5)
		print("[grip] %s 手首 %v / 指の付け根 %v / 拳の中心 %v（手首から %.3f m）"
			% [side, wrist_position, knuckles, center,
				wrist_position.distance_to(center)])


## ライフルの握り（下へ伸びるピストルグリップ）の線分と太さをメッシュから実測する。
## `WeaponLoadout.grip_axis_start / grip_axis_end / grip_model_radius` に入れる値で、
## 指を曲げる先を決める。ピストルの値のままだと指が見当違いの場所へ閉じる。
func _report_grip_axis(weapon: Node3D) -> void:
	var points := PackedVector3Array()
	for node: Node in weapon.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var verts: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(
				surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in verts:
				var local: Vector3 = mesh_instance.transform * vertex
				if local.x < GRIP_X_RANGE.x or local.x > GRIP_X_RANGE.y:
					continue
				if local.y > 0.0:
					continue
				points.append(local)
	if points.size() < 4:
		print("[grip] 握りの頂点が足りない（%d 点）" % points.size())
		return
	var y_min: float = INF
	var y_max: float = -INF
	for point: Vector3 in points:
		y_min = minf(y_min, point.y)
		y_max = maxf(y_max, point.y)
	# 上端・下端それぞれ 25% の帯の重心を線分の端にする。
	var band: float = (y_max - y_min) * 0.25
	var top := Vector3.ZERO
	var bottom := Vector3.ZERO
	var top_count: int = 0
	var bottom_count: int = 0
	for point: Vector3 in points:
		if point.y >= y_max - band:
			top += point
			top_count += 1
		if point.y <= y_min + band:
			bottom += point
			bottom_count += 1
	if top_count == 0 or bottom_count == 0:
		return
	top /= float(top_count)
	bottom /= float(bottom_count)
	# 太さは線分からの距離の平均。指を回す半径として使う。
	var radius_sum: float = 0.0
	for point: Vector3 in points:
		var along: Vector3 = bottom - top
		var t: float = clampf((point - top).dot(along) / along.length_squared(), 0.0, 1.0)
		radius_sum += point.distance_to(top + along * t)
	var radius: float = radius_sum / float(points.size())
	print("[grip] 握りの線分 %d 点  上 %v / 下 %v  長さ %.3f  太さ %.4f"
		% [points.size(), top, bottom, top.distance_to(bottom), radius])
	print("[grip] → grip_axis_start = Vector3(%.4f, %.4f, %.4f)" % [top.x, top.y, top.z])
	print("[grip] → grip_axis_end   = Vector3(%.4f, %.4f, %.4f)" % [bottom.x, bottom.y, bottom.z])
	print("[grip] → grip_model_radius = %.4f" % radius)


## いま .tscn に入っている値で、握りと handguard が本当に両手へ来ているかを測る。
## 解いた値と適用した値は別物なので、見た目で判断せずここで突き合わせる。
func _verify_grip(weapon: Node3D, grip: Vector3, fore: Vector3,
		right_hand: Vector3, left_hand: Vector3) -> void:
	var grip_world: Vector3 = weapon.global_transform * grip
	var fore_world: Vector3 = weapon.global_transform * fore
	print("[grip] 検証: 握り→右手 %.4f m / handguard→左手 %.4f m"
		% [grip_world.distance_to(right_hand), fore_world.distance_to(left_hand)])
	# 残差が「向き」由来か「長さ」由来かを分ける。両方 0 に近ければ2点は一致する。
	var model_vector: Vector3 = fore_world - grip_world
	var hand_vector: Vector3 = left_hand - right_hand
	var angle: float = rad_to_deg(model_vector.angle_to(hand_vector))
	print("[grip] 検証: 銃の 握り→handguard %.4f m / 両手 %.4f m（差 %+.4f m）  角度差 %.2f 度"
		% [model_vector.length(), hand_vector.length(),
			model_vector.length() - hand_vector.length(), angle])
	var attach := weapon.get_parent() as Node3D
	if attach != null:
		print("[grip] 検証: BoneAttachment の拡縮 %v（1 でなければ式に効く）"
			% attach.global_transform.basis.get_scale())


## 銃身の傾きと、handguard の高さの分布。銃口炎は水平固定なので、銃身が傾いて
## いるほど絵が合わない。左手を置く位置が妥当かの判断材料にもする。
func report_barrel_tilt(animator: NpcAnimator, weapon: Node3D) -> void:
	print("[grip] --- 銃身の傾き ---")
	for entry: Array in [["待機", NpcAnimator.Clip.IDLE, 0.0],
			["発砲", NpcAnimator.Clip.FIRE, FIRE_SAMPLE_TIME],
			["歩き", NpcAnimator.Clip.WALK, 0.0],
			["走り", NpcAnimator.Clip.RUN, 0.0]]:
		if not animator.has_clip(int(entry[1])):
			continue
		animator.play(int(entry[1]), 0.0, 1.0, true, float(entry[2]))
		for frame: int in 3:
			await get_tree().process_frame
		var grip_local: Dictionary = _centroid(weapon, GRIP_X_RANGE, -INF, 0.0)
		var tip := Vector3(-INF, 0.0, 0.0)
		for node: Node in weapon.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			for surface: int in mesh_instance.mesh.get_surface_count():
				var verts: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(
					surface)[Mesh.ARRAY_VERTEX]
				for vertex: Vector3 in verts:
					var local: Vector3 = mesh_instance.transform * vertex
					if local.x > tip.x:
						tip = local
		var muzzle: Vector3 = weapon.global_transform * tip
		var grip: Vector3 = weapon.global_transform * (grip_local["point"] as Vector3)
		var barrel: Vector3 = (muzzle - grip).normalized()
		var horizontal := Vector3(barrel.x, 0.0, barrel.z)
		var tilt: float = 0.0
		if not horizontal.is_zero_approx():
			tilt = rad_to_deg(asin(clampf(barrel.y, -1.0, 1.0)))
		print("[grip] %-4s 銃身の向き %v  水平からの傾き %+.1f 度" % [entry[0], barrel, tilt])


## 木部がどこに分かれて存在するかを X 刻みで出す。左手を置く位置の判断材料。
func report_fore_profile(weapon: Node3D) -> void:
	print("[grip] --- 木部（%s）の分布 ---" % FORE_MATERIAL)
	for step: int in 10:
		var lo: float = -2.0 + float(step) * 0.5
		var result: Dictionary = _centroid(weapon, Vector2(lo, lo + 0.5),
			-INF, INF, FORE_MATERIAL)
		if int(result["count"]) == 0:
			continue
		print("[grip] X %+.1f..%+.1f : %3d 点  重心 %v"
			% [lo, lo + 0.5, int(result["count"]), result["point"]])


## 左手が握る木部の軸と太さ。右手の握りと同じ形式（線分＋半径）で、
## 左手用の指ソルバへ渡す値になる。
func _report_fore_axis(weapon: Node3D) -> void:
	var result: Dictionary = _extent_center(weapon,
		Vector2(FORE_X_MIN, INF), FORE_MATERIAL)
	if int(result["count"]) == 0:
		return
	var center: Vector3 = result["point"]
	var size: Vector3 = result["size"]
	var start := Vector3(center.x - size.x * 0.5, center.y, center.z)
	var end := Vector3(center.x + size.x * 0.5, center.y, center.z)
	# 断面は長方形なので、直交2方向の半分の平均を円の半径とみなす。
	var radius: float = (size.y + size.z) * 0.25
	print("[grip] → fore_axis_start = Vector3(%.4f, %.4f, %.4f)" % [start.x, start.y, start.z])
	print("[grip] → fore_axis_end   = Vector3(%.4f, %.4f, %.4f)" % [end.x, end.y, end.z])
	print("[grip] → fore_model_radius = %.4f（断面 %.3f x %.3f）" % [radius, size.y, size.z])


## 銃口の実位置。HitscanGun は本体からの高さ・前方距離で置かれるので、
## 銃口炎が銃の先から出るようにその2つを実測して出す。
func _report_muzzle(weapon: Node3D) -> void:
	var tip := Vector3(-INF, 0.0, 0.0)
	for node: Node in weapon.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var verts: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(
				surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in verts:
				var local: Vector3 = mesh_instance.transform * vertex
				if local.x > tip.x:
					tip = local
	if tip.x == -INF:
		return
	var world: Vector3 = weapon.global_transform * tip
	var body: Vector3 = _boss.global_position
	var forward: Vector3 = -_boss.global_transform.basis.z
	forward.y = 0.0
	var offset: Vector3 = world - body
	print("[grip] 銃口の実位置 %v（本体から 高さ %.3f m / 前方 %.3f m）"
		% [world, offset.y, offset.dot(forward.normalized())])
	print("[grip] → gun_muzzle_height = %.2f / gun_muzzle_forward_offset = %.2f"
		% [offset.y, maxf(offset.dot(forward.normalized()), 0.0)])


## 指定したマテリアルの、X 範囲に入る頂点が占める範囲の中央（モデルのローカル座標）。
## 重心（_centroid）と違い、頂点がどこに多いかに左右されない。長い部品のどこを
## 握るかを決めるのはこちらが適している。
func _extent_center(weapon: Node3D, x_range: Vector2,
		material_name: String) -> Dictionary:
	var box := AABB()
	var count: int = 0
	for node: Node in weapon.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(
				surface) as StandardMaterial3D
			if material == null or material.resource_name != material_name:
				continue
			var verts: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(
				surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in verts:
				var local: Vector3 = mesh_instance.transform * vertex
				if local.x < x_range.x or local.x > x_range.y:
					continue
				box = AABB(local, Vector3.ZERO) if count == 0 else box.expand(local)
				count += 1
	return {
		"point": box.get_center() if count > 0 else Vector3.ZERO,
		"count": count,
		"size": box.size,
	}


## 指定した X 範囲・Y 範囲に入る頂点の重心（モデルのローカル座標）と、その点数。
## 点数を返すのは、重心が Vector3.ZERO になったのか、そもそも1点も入らなかったのかを
## 呼び出し側が区別できるようにするため。
func _centroid(weapon: Node3D, x_range: Vector2, y_min: float, y_max: float,
		material_name: String = "") -> Dictionary:
	var sum := Vector3.ZERO
	var count: int = 0
	for node: Node in weapon.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			if material_name != "":
				# 名前は完全一致で見る。contains だと DarkWood（上部カバー）も拾う。
				var material := mesh_instance.mesh.surface_get_material(
					surface) as StandardMaterial3D
				if material == null or material.resource_name != material_name:
					continue
			var verts: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(
				surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in verts:
				var local: Vector3 = mesh_instance.transform * vertex
				if local.x < x_range.x or local.x > x_range.y:
					continue
				if local.y < y_min or local.y > y_max:
					continue
				sum += local
				count += 1
	return {
		"point": sum / float(count) if count > 0 else Vector3.ZERO,
		"count": count,
	}


## 待機クリップを鳴らす。Animator はモデル差し込みのあとに立ち上がる。
func _play_idle() -> void:
	var animators: Array[Node] = _boss.find_children("*", "Node", true, false)
	for node: Node in animators:
		var animator := node as NpcAnimator
		if animator == null:
			continue
		print("[grip] Animator active=%s has_idle=%s"
			% [animator.is_active(), animator.has_clip(NpcAnimator.Clip.IDLE)])
		if animator.is_active():
			animator.play(NpcAnimator.Clip.IDLE)
		return
	print("[grip] Animator が見つからない")
