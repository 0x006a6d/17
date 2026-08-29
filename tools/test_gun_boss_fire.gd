extends Node

## 3面ボスが撃つときに発砲モーションを出すことの検証。
##   godot --path . --headless res://tools/test_gun_boss_fire.tscn
##
## 経緯: ライフルに差し替えるまで、`GunBoss` は `HitscanGun.fire_at()` を呼ぶだけで
## 撃つ絵を出していなかった。移動のクリップは `drive_locomotion()` が毎物理フレーム
## 指定し直すので、素直に `play()` すると次のフレームで潰される。ステートを変えずに
## 割り込む `play_one_shot()` を使っているか、実際に割り込めているかを見る。
##
## 検証項目:
##   (1) 発砲クリップが登録されている（素材の差し忘れ検出）
##   (2) 撃つと単発再生が始まる
##   (3) 単発再生の間は drive_locomotion() が上書きしない
##   (4) 差し込む秒数が発射間隔を超えない（撃ち続けても移動の絵に戻れる）
##   (5) 撃つと銃口炎などの表示と発砲音が出る（HitscanGun.shot_fired を購読しているか）
##   (6) 銃口が武器モデルに追従する（本体からの固定オフセットだと、腕が動く場面で
##       銃口炎が銃の先から離れる）
##   (7) 銃口炎が撃った向きへ傾く（元の PlayerGunFx は水平固定で、弾道と食い違う）

const BOSS_SCENE: String = "res://actors/enemy/bosses/stage_3_boss.tscn"
## 走りに入る速度。run_speed_threshold（2.6）より速くする。
const RUN_SPEED: float = 3.2
## 銃口炎・煙・薬莢が消えるまでの待ちフレーム数（60Hz で 1.0 秒）。
const FX_SETTLE_FRAMES: int = 60
## 待機と発砲で銃口がこれ以上動いていれば、姿勢に追従しているとみなす（m）。
## 本体からの固定オフセットなら、姿勢を変えても 1 mm も動かない。
const MUZZLE_MOVE_MIN: float = 0.01
## 銃口が武器モデルの上にあるとみなす余裕（m）。
const MUZZLE_ON_WEAPON_MARGIN: float = 0.02
## 銃口炎が傾いているとみなす角度（ラジアン。約 1.7 度）。
const FLASH_TILT_MIN: float = 0.03

var _failures: int = 0


func _ready() -> void:
	print("=== 3面ボスの発砲モーション 検証 ===")
	var boss := (load(BOSS_SCENE) as PackedScene).instantiate() as CharacterBody3D
	add_child(boss)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var animator := boss.get_node_or_null("Animator") as NpcAnimator
	if animator == null or not animator.is_active():
		_check(false, "Animator が立ち上がっている")
		_finish()
		return
	_check(true, "Animator が立ち上がっている")
	_check(animator.has_clip(NpcAnimator.Clip.FIRE), "発砲クリップが登録されている")
	_check(animator.has_clip(NpcAnimator.Clip.IDLE), "待機クリップが登録されている（前提）")

	var interval: float = float(boss.get("gun_fire_interval"))
	var duration: float = float(boss.get("fire_reaction_duration"))
	_check(duration > 0.0 and duration <= interval,
		"差し込む秒数 %.2fs が発射間隔 %.2fs 以内" % [duration, interval])

	# 実戦と同じ入口を通す。撃つ条件（距離・向き・射線）を作らずに済むよう、
	# 発砲時に呼ばれる差し込みだけを直接叩く。
	animator.drive_locomotion(RUN_SPEED)
	_check(not animator.is_one_shot_active(), "撃つ前は単発再生していない")
	boss.call("_play_fire_reaction")
	_check(animator.is_one_shot_active(), "撃つと単発再生が始まる")

	# 走り続けていても、差し込んだ絵が次のフレームで潰されないこと。
	animator.drive_locomotion(RUN_SPEED)
	_check(animator.is_one_shot_active(), "移動中でも発砲の絵が潰されない")

	await _check_shot_feedback(boss)
	await _check_muzzle_follows_weapon(boss, animator)
	await _check_flash_tilt(boss)
	_finish()


## (7) 斜めに撃ったとき、銃口炎がその向きへ傾くか。
## 水平固定なら rotation.z は 0 か ±PI のままになる。
func _check_flash_tilt(boss: CharacterBody3D) -> void:
	var gun := boss.get_node_or_null("HitscanGun") as HitscanGun
	var gun_fx := boss.get_node_or_null("GunFx") as EnemyGunFx
	if gun == null or gun_fx == null:
		_check(false, "銃と表示部品がある（前提）")
		return
	for child: Node in gun_fx.get_children():
		child.free()
	gun.global_position = boss.global_position + Vector3.UP * 1.6
	# 斜め下へ撃つ（実戦の胸狙いと同じ向き）。
	gun.fire_at(boss.global_position + Vector3(4.0, 1.05, 0.0))
	await get_tree().process_frame
	var tilted: int = 0
	var flat: int = 0
	for child: Node in gun_fx.get_children():
		var anchor := child as Node3D
		if anchor == null or not anchor.name.begins_with("GunMuzzleFlash"):
			continue
		# 水平固定なら 0 か ±PI。そこから離れていれば傾いている。
		var offset: float = minf(absf(anchor.rotation.z),
			absf(absf(anchor.rotation.z) - PI))
		if offset > FLASH_TILT_MIN:
			tilted += 1
		else:
			flat += 1
	_check(tilted > 0 and flat == 0,
		"銃口炎が撃った向きへ傾く（傾き %d 個 / 水平のまま %d 個）" % [tilted, flat])


## (6) 銃口が武器モデルに追従するか。姿勢を変えて銃口が動くこと、そのとき銃口が
## 武器モデルの範囲に収まっていることを見る。
func _check_muzzle_follows_weapon(boss: CharacterBody3D, animator: NpcAnimator) -> void:
	var gun := boss.get_node_or_null("HitscanGun") as HitscanGun
	var loadout := boss.get_node_or_null("WeaponLoadout") as WeaponLoadout
	if gun == null or loadout == null or not loadout.has_weapon():
		_check(false, "銃と武器モデルがある（前提）")
		return
	var idle_position: Vector3 = await _muzzle_at(boss, animator, NpcAnimator.Clip.IDLE, 0.0)
	var fire_position: Vector3 = await _muzzle_at(boss, animator, NpcAnimator.Clip.FIRE, 0.35)
	_check(idle_position.distance_to(fire_position) > MUZZLE_MOVE_MIN,
		"銃口が姿勢に追従する（待機と発砲で %.3f m 動く）"
			% idle_position.distance_to(fire_position))

	var weapon: Node3D = loadout.current_weapon()
	var box := AABB()
	var first: bool = true
	for node: Node in weapon.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var world_box: AABB = mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		box = world_box if first else box.merge(world_box)
		first = false
	if first:
		_check(false, "武器モデルのメッシュがある（前提）")
		return
	_check(box.grow(MUZZLE_ON_WEAPON_MARGIN).has_point(fire_position),
		"銃口が武器モデルの範囲にある")


func _muzzle_at(boss: CharacterBody3D, animator: NpcAnimator, clip: int,
		start_time: float) -> Vector3:
	animator.play(clip, 0.0, 1.0, true, start_time)
	for frame: int in 3:
		await get_tree().process_frame
	boss.call("_update_muzzle_position")
	var gun := boss.get_node_or_null("HitscanGun") as HitscanGun
	return gun.global_position if gun != null else Vector3.ZERO


## (5) 表示と音。撃った事実（HitscanGun.shot_fired）を購読しているかを見る。
## 音そのものは耳で確かめるしかないので、鳴らす指示が出るところまでを確かめる。
func _check_shot_feedback(boss: CharacterBody3D) -> void:
	var gun := boss.get_node_or_null("HitscanGun") as HitscanGun
	var gun_fx := boss.get_node_or_null("GunFx") as EnemyGunFx
	_check(gun != null, "HitscanGun がある（前提）")
	_check(gun_fx != null, "銃口炎などの表示部品がある")
	if gun == null or gun_fx == null:
		return
	_check(gun.shot_fired.get_connections().size() > 0,
		"撃った通知を購読している")
	_check(StringName(boss.get("fire_sound")) != &"", "発砲音が設定されている")

	# 実際に撃たせて、表示が出るところまで通す（誰も居ない方向へ撃つ）。
	var fx_children_before: int = gun_fx.get_child_count()
	gun.global_position = boss.global_position + Vector3.UP
	gun.fire_at(boss.global_position + Vector3(10.0, 1.0, 0.0))
	await get_tree().process_frame
	_check(gun_fx.get_child_count() > fx_children_before,
		"撃つと表示が生成される（%d → %d）"
			% [fx_children_before, gun_fx.get_child_count()])
	# 銃口炎は Tween で消えるので、消え切るまで待ってから終わる。
	# 途中で quit すると、残った表示が終了時のリークとして報告される。
	for frame: int in FX_SETTLE_FRAMES:
		await get_tree().process_frame


func _finish() -> void:
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(_failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	_failures += 1
	print("FAIL: ", label)
