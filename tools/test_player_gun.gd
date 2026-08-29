extends Node

## プレイヤー銃の命中、残弾、空撃ち、リロード、持ち替え時の残弾保持と、
## 構えたときの銃身の傾きを検証する。

const STAGE_PATH: String = "res://levels/belt_test.tscn"
const ENEMY_PATH: String = "res://actors/enemy/enemy.tscn"
const INITIAL_SETTLE_FRAMES: int = 6
const SHOT_OBSERVE_FRAMES: int = 4
const INPUT_OBSERVE_FRAMES: int = 2
const EMPTY_OBSERVE_FRAMES: int = 6
const RELOAD_SETTLE_FRAMES: int = 3
const PLAYER_POSITION: Vector3 = Vector3(4.0, 0.2, 0.0)
const NEAR_POSITION: Vector3 = Vector3(8.0, 0.2, 0.0)
const FAR_POSITION: Vector3 = Vector3(8.0, 0.2, 1.3)
const HIDDEN_DUMMY_POSITION: Vector3 = Vector3(60.0, 0.2, 0.0)
## 銃身（モデルの +X）をこの角度へ向けると、描画された銃身が水平に見える。
## 見た目の銃身はモデル軸より 3 度上に出るため（qc_gunpitch_*.png の画素計測）、
## モデル軸は 3 度下を向かせる。
const BARREL_MODEL_PITCH_TARGET_DEG: float = -3.0
## 構えで許す誤差（度）。
const BARREL_PITCH_TOLERANCE_DEG: float = 2.0
## 歩行で許す誤差（度）。歩行クリップは1周期のなかで上下に振れる。
const BARREL_WALK_TOLERANCE_DEG: float = 3.0
## 歩行の平均を取るフレーム数。
const BARREL_WALK_SAMPLE_FRAMES: int = 60
## 発砲の重なりが抜けるまで待つフレーム数。
const BARREL_SETTLE_FRAMES: int = 80

var _pass: int = 0
var _fail: int = 0
var _stage: Node3D = null
var _player: Node3D = null
var _weapon: PlayerWeapon = null
var _gun_fx: PlayerGunFx = null
var _hud: Hud = null
var _near: Node3D = null
var _far: Node3D = null
var _near_health: Health = null
var _far_health: Health = null
var _dry_fire_count: int = 0
var _shot_feedback_count: int = 0
var _spawned_muzzle_stack: bool = false
var _spawned_casing_tracer: bool = false
var _spawned_impact_stack: bool = false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	RunState.reset()
	_stage = (load(STAGE_PATH) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node(^"Player") as Node3D
	_weapon = _player.get_node(^"PlayerWeapon") as PlayerWeapon
	_gun_fx = _player.get_node(^"PlayerGunFx") as PlayerGunFx
	_gun_fx.feedback_spawned.connect(_on_gun_feedback_spawned)
	_hud = _stage.get_node(^"Hud") as Hud
	_weapon.dry_fired.connect(_on_dry_fired)
	for dummy_name: String in ["Dummy1", "Dummy2", "Dummy3"]:
		(_stage.get_node(NodePath(dummy_name)) as Node3D).global_position = \
			HIDDEN_DUMMY_POSITION
	_near = _spawn_enemy(NEAR_POSITION)
	_far = _spawn_enemy(FAR_POSITION)
	_near_health = _near.get_node(^"Health") as Health
	_far_health = _far.get_node(^"Health") as Health
	_player.global_position = PLAYER_POSITION
	_player.set("_facing", 1)
	# 開始は素手なので、銃の検証をする前に銃へ持ち替える（順は 素手 → 刀 → 銃）。
	_weapon.equip_gun()
	await _wait_frames(INITIAL_SETTLE_FRAMES)

	var holder := _player.get_node(^"WeaponHolder") as WeaponHolder
	_assert("(4) 銃モデルが装着されている", holder.has_weapon())
	var initial_ammo: int = _weapon.ammo()
	var maximum_ammo: int = _weapon.max_ammo()
	_assert("(4) 初期弾数が最大値 (%d/%d)" % [initial_ammo, maximum_ammo],
		initial_ammo > 0 and initial_ammo == maximum_ammo)
	_assert("(5) 銃装備中は HUD に残弾を表示",
		_hud.ammo_label_visible()
		and _hud.ammo_display_text() == _ammo_text(initial_ammo))

	_act(&"fire")
	await _wait_frames(1)
	_assert("(8) 発射直後に短い銃口炎・瞬間照明・煙を重ねる",
		_shot_feedback_count == 1 and _spawned_muzzle_stack)
	_assert("(8) 薬莢を排出し、全射程レーザーではない短い弾道を描く",
		_spawned_casing_tracer)
	_assert("(8) 命中点に小光と短命な火花を出す",
		_spawned_impact_stack)
	await _wait_frames(SHOT_OBSERVE_FRAMES - 1)
	_assert("(1) 正面同一段の敵に命中 (HP=%.0f)" % _near_health.current_hp(),
		_near_health.current_hp() < _near_health.max_hp)
	_assert("(1) 弾数が1減った (%d→%d)" % [initial_ammo, _weapon.ammo()],
		_weapon.ammo() == initial_ammo - 1)
	_assert("(2) 段がずれた敵には当たらない (HP=%.0f)" % _far_health.current_hp(),
		is_equal_approx(_far_health.current_hp(), _far_health.max_hp))
	var shot_blood := _near.get_node_or_null(
		^"Hurtbox/DirectionalBloodSpray3D") as DirectionalBloodSpray3D
	var shot_blood_direction: Vector3 = shot_blood.debug_last_flow_direction() \
		if shot_blood != null else Vector3.ZERO
	var shot_blood_position: Vector3 = shot_blood.debug_last_impact_position() \
		if shot_blood != null else Vector3.ZERO
	_assert("(9) 銃撃の血しぶきが弾道方向へ流れる",
		shot_blood != null
		and shot_blood.debug_last_kind() == DirectionalBloodSpray3D.AttackKind.SHOT
		and shot_blood_direction.dot(Vector3.RIGHT) > 0.99
		and shot_blood.active_burst_count() > 0)
	_assert("(9) 血しぶきの起点が敵中心ではなくレイ実交点",
		shot_blood != null and shot_blood_position.x < _near.global_position.x - 0.2)

	# 残弾だけを0へ置き、空撃ちが射撃せず HUD 表示を起こすことを確認する。
	_weapon.set("_ammo", 0)
	var hp_before_empty: float = _near_health.current_hp()
	var dry_fire_before: int = _dry_fire_count
	_act(&"fire")
	await _wait_frames(EMPTY_OBSERVE_FRAMES)
	_assert("(3) 弾切れでは撃てない（HP 不変）",
		is_equal_approx(_near_health.current_hp(), hp_before_empty))
	_assert("(3) 弾切れの fire が空撃ち通知を出す",
		_dry_fire_count == dry_fire_before + 1)
	_assert("(3) 空撃ちで HUD の残弾0表示が赤点滅する",
		_hud.ammo_display_text() == _ammo_text(0) and _hud.ammo_flash_active())

	_act(&"reload")
	await _wait_frames(INPUT_OBSERVE_FRAMES)
	_assert("(6) reload でリロードを開始する", _weapon.is_reloading())
	_assert("(6) リロード中は HUD に状態を表示",
		_hud.ammo_display_text() == _hud.reloading_text)
	var hp_before_reload_fire: float = _near_health.current_hp()
	var dry_fire_during_reload: int = _dry_fire_count
	_act(&"fire")
	await _wait_frames(INPUT_OBSERVE_FRAMES)
	_assert("(6) リロード中は射撃も空撃ちもしない",
		is_equal_approx(_near_health.current_hp(), hp_before_reload_fire)
		and _dry_fire_count == dry_fire_during_reload)
	var reload_frames: int = ceili(_weapon.reload_duration \
		* float(Engine.physics_ticks_per_second)) + RELOAD_SETTLE_FRAMES
	await _wait_frames(reload_frames)
	_assert("(6) リロード完了で満タンへ戻る",
		not _weapon.is_reloading() and _weapon.ammo() == maximum_ammo)
	_assert("(6) リロード完了後の HUD が満タン表示へ戻る",
		_hud.ammo_display_text() == _ammo_text(maximum_ammo))

	# 満タンから1発消費し、銃→素手→刀→銃を巡回しても補充されないことを確認する。
	_act(&"fire")
	await _wait_frames(SHOT_OBSERVE_FRAMES)
	var ammo_before_switch: int = _weapon.ammo()
	_assert("(7) 持ち替え前に1発消費した", ammo_before_switch == maximum_ammo - 1)
	_act(&"switch_weapon")
	await _wait_frames(INPUT_OBSERVE_FRAMES)
	_assert("(7) 素手では残弾 HUD を隠す",
		_weapon.kind() == PlayerWeapon.WeaponKind.NONE
		and not _hud.ammo_label_visible())
	_act(&"switch_weapon")
	await _wait_frames(INPUT_OBSERVE_FRAMES)
	_assert("(7) 素手の次は刀", _weapon.kind() == PlayerWeapon.WeaponKind.KATANA)
	_act(&"switch_weapon")
	await _wait_frames(INPUT_OBSERVE_FRAMES)
	_assert("(7) 銃へ戻しても残弾を補充しない",
		_weapon.kind() == PlayerWeapon.WeaponKind.GUN
		and _weapon.ammo() == ammo_before_switch)
	_assert("(7) 銃へ戻すと保持した残弾を HUD に再表示",
		_hud.ammo_label_visible()
		and _hud.ammo_display_text() == _ammo_text(ammo_before_switch))
	await _check_barrel_level()
	_finish()


func _spawn_enemy(position: Vector3) -> Node3D:
	var enemy := (load(ENEMY_PATH) as PackedScene).instantiate() as Node3D
	_stage.add_child(enemy)
	enemy.global_position = position
	enemy.set_physics_process(false)
	return enemy


func _act(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	# headless 起動直後は複数の physics_frame が1描画フレーム内で処理されることがある。
	# 描画フレーム待ちに依存せず、この押下を検証対象へ届けてから先へ進む。
	Input.flush_buffered_events()
	var release := event.duplicate() as InputEventAction
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _wait_frames(frame_count: int) -> void:
	for _frame: int in frame_count:
		_prepare_targets()
		await get_tree().physics_frame


func _prepare_targets() -> void:
	for enemy: Node3D in [_near, _far]:
		if enemy == null:
			continue
		var hurtbox := enemy.get_node_or_null(^"Hurtbox") as Area3D
		if hurtbox != null:
			hurtbox.monitorable = true


func _ammo_text(current_ammo: int) -> String:
	return _hud.ammo_format % [current_ammo, _weapon.max_ammo()]


func _has_fx_node(node_name: String) -> bool:
	return _gun_fx != null and _gun_fx.find_child(node_name, true, false) != null


func _tracer_is_short() -> bool:
	if _gun_fx == null:
		return false
	var visual := _gun_fx.find_child("TracerGlow", true, false) as MeshInstance3D
	if visual == null:
		return false
	var quad := visual.mesh as QuadMesh
	return quad != null and quad.size.x <= _gun_fx.tracer_max_length + 0.001


func _on_dry_fired() -> void:
	_dry_fire_count += 1


func _on_gun_feedback_spawned(_from: Vector3, _to: Vector3,
		_hit_body: Node3D) -> void:
	_shot_feedback_count += 1
	if _shot_feedback_count != 1:
		return
	# 0.028〜0.065秒の部品は、ヘッドレス実行で次の物理フレームを
	# 待つ間に解放されることがある。生成完了シグナル内で存在と寸法を記録する。
	_spawned_muzzle_stack = _has_fx_node("GunMuzzleFlash") \
		and _has_fx_node("GunMuzzleLight") \
		and _has_fx_node("GunMuzzleSmoke")
	_spawned_casing_tracer = _has_fx_node("GunCasing") and _tracer_is_short()
	_spawned_impact_stack = _has_fx_node("GunImpact") \
		and _has_fx_node("GunImpactSparks")


## 構えたときの銃身が水平か。射線は正面 ±X へ水平なので、絵もそこへ向いていないと
## 上を狙っているように見える（銃身はモデルの +X。asset-credits「武器の握り」）。
## 発砲中の跳ね上がりはモーションなので、静止した構えだけを見る。
func _check_barrel_level() -> void:
	# 直前の発砲が構えへ戻りきるまで待つ（発砲クリップは約1.04秒＝62フレーム）。
	await _wait_frames(BARREL_SETTLE_FRAMES)
	var holder := _player.get_node_or_null(^"WeaponHolder") as WeaponHolder
	var weapon: Node3D = holder.current_weapon() if holder != null else null
	if weapon == null:
		_assert("(8) 銃身の傾きを測れる", false)
		return
	var pitch: float = _barrel_pitch(weapon)
	_assert("(8) 構えの銃身が水平（モデル軸 %.1f 度）" % pitch,
		absf(pitch - BARREL_MODEL_PITCH_TARGET_DEG) <= BARREL_PITCH_TOLERANCE_DEG)
	# 歩行クリップは銃を下げて持つ姿勢なので、握りの角度を速度で混ぜて水平へ戻す。
	# 実際に歩かせないと PlayerWeapon が本体の速度を読めない。
	Input.action_press(&"move_right")
	await _wait_frames(BARREL_WALK_SAMPLE_FRAMES)
	var total: float = 0.0
	for _i: int in range(BARREL_WALK_SAMPLE_FRAMES):
		await _wait_frames(1)
		total += _barrel_pitch(weapon)
	Input.action_release(&"move_right")
	var walk_pitch: float = total / float(BARREL_WALK_SAMPLE_FRAMES)
	_assert("(8) 歩行中も銃身が水平（モデル軸の平均 %.1f 度）" % walk_pitch,
		absf(walk_pitch - BARREL_MODEL_PITCH_TARGET_DEG) <= BARREL_WALK_TOLERANCE_DEG)


## 銃身（モデルの +X）の仰角。+ が上向き。
func _barrel_pitch(weapon: Node3D) -> float:
	var barrel: Vector3 = weapon.global_transform.basis.x.normalized()
	return rad_to_deg(atan2(barrel.y, Vector2(barrel.x, barrel.z).length()))


func _assert(label: String, condition: bool) -> void:
	if condition:
		_pass += 1
		print("[PASS] " + label)
	else:
		_fail += 1
		print("[FAIL] " + label)


func _finish() -> void:
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)
