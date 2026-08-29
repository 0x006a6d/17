extends Node

## 日本刀の装着、単発終了、3段先行入力、段別ダメージを検証する。
const STAGE: String = "res://levels/belt_test.tscn"
const ENEMY: String = "res://actors/enemy/enemy.tscn"
const INITIAL_SETTLE_FRAMES: int = 8
const INPUT_WINDOW_RATIO: float = 0.60
const LATE_INPUT_RATIO: float = 0.95
const ACTION_SETTLE_SECONDS: float = 0.10
const MAX_WAIT_FRAMES: int = 240
const DAMAGE_TOLERANCE: float = 0.01
const PLAYER_POSITION: Vector3 = Vector3(4.0, 0.2, 0.0)
const FIRST_STAGE: int = 1
const SECOND_STAGE: int = 2
const FINAL_STAGE: int = 3
const NONE_WEAPON_KIND: int = 0
const GUN_WEAPON_KIND: int = 1
const KATANA_WEAPON_KIND: int = 2
const BAREHAND_FIRST_STATE: StringName = &"melee_1"

var _pass: int = 0
var _fail: int = 0
var _stage: Node3D = null
var _player: Node3D = null
var _weapon: Node = null
var _katana: Node = null
var _katana_fx: Node = null
var _near: Node3D = null
var _far: Node3D = null
var _near_health: Health = null
var _far_health: Health = null
var _playback: AnimationNodeStateMachinePlayback = null
var _played_stages: Array[int] = []
var _stage_damages: Array[float] = []
var _tracking_damage: bool = false
var _tracked_stage: int = 0
var _hp_at_stage_start: float = 0.0
var _combo_completed: bool = false
var _last_katana_flow_at_damage: Vector3 = Vector3.ZERO


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	RunState.reset()
	_stage = (load(STAGE) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node(^"Player") as Node3D
	for dummy_name: String in ["Dummy1", "Dummy2", "Dummy3"]:
		(_stage.get_node(NodePath(dummy_name)) as Node3D).global_position = \
			Vector3(60.0, 0.2, 0.0)
	_weapon = _player.get_node(^"PlayerWeapon")
	_katana = _player.get_node(^"PlayerKatanaCombo")
	_katana_fx = _player.get_node(^"PlayerKatanaSwing3D")
	# 段ごとのダメージを測るテストなので、一撃即死は切る（別途 test_instant_kill.gd で検証）。
	var instant_kill := _player.get_node(^"PlayerInstantKill") as PlayerInstantKill
	instant_kill.katana_chance = 0.0
	var hud: Node = _stage.get_node(^"Hud")
	_katana.connect("stage_started", _on_stage_started)
	_katana.connect("combo_finished", _on_combo_finished)
	var melee := _player.get_node(^"PlayerMelee")
	var tree := melee.get_node(^"AnimationTree") as AnimationTree
	_playback = tree.get("parameters/main/playback") as AnimationNodeStateMachinePlayback
	_near = _spawn_enemy(Vector3(4.6, 0.2, 0.0))
	_far = _spawn_enemy(Vector3(4.6, 0.2, 1.3))
	_near_health = _near.get_node(^"Health") as Health
	_far_health = _far.get_node(^"Health") as Health
	# 厳密な数値を見るので、この検証では端数の揺らぎを切る。
	_near_health.damage_variance = 0.0
	_far_health.damage_variance = 0.0
	var near_hurtbox := _near.get_node(^"Hurtbox") as Hurtbox
	near_hurtbox.damage_applied.connect(_on_near_damage_applied)
	_player.global_position = PLAYER_POSITION
	_player.set("_facing", 1)
	await _wait_frames(INITIAL_SETTLE_FRAMES)

	_act(&"switch_weapon")
	await _wait_frames(INITIAL_SETTLE_FRAMES)
	_assert("(1) 刀に持ち替わった (kind=%d)" % int(_weapon.call("kind")),
		int(_weapon.call("kind")) == KATANA_WEAPON_KIND)
	var holder := _player.get_node(^"WeaponHolder")
	_assert("(1) 刀モデルが装着されている", bool(holder.call("has_weapon")))
	_assert("(1) HUD が日本刀を表示する", String(hud.call("weapon_display_text"))
		== String(hud.get("weapon_katana_text")))
	_assert("(1) 刀の軌道エフェクトが組み込まれている", _katana_fx != null)

	# 初段95%で遅延再押下する。従来4項目を保ち、受付窓外なら待機へ戻ることも見る。
	_played_stages.clear()
	var hp_before_single: float = _near_health.current_hp()
	_act(&"fire")
	await _wait_for_stage(FIRST_STAGE)
	await _wait_for_stage_ratio(FIRST_STAGE, LATE_INPUT_RATIO)
	_act(&"fire")
	await _wait_until_idle()
	await _wait_seconds(ACTION_SETTLE_SECONDS, true)
	var single_damage: float = hp_before_single - _near_health.current_hp()
	_assert("(2) 刀の斬りで正面の敵の HP が減る (HP=%.0f)" %
		_near_health.current_hp(), _near_health.current_hp() < hp_before_single)
	_assert("(3) 段がずれた敵には当たらない (HP=%.0f)" % _far_health.current_hp(),
		is_equal_approx(_far_health.current_hp(), _far_health.max_hp))
	_assert("(4) 受付窓を過ぎた再押下では繋がらず locomotion へ戻る",
		_played_stages == [FIRST_STAGE] and not bool(_katana.call("is_active"))
		and _playback.get_current_node() == &"locomotion")
	var slash_blood := _near.get_node_or_null(
		^"Hurtbox/DirectionalBloodSpray3D") as DirectionalBloodSpray3D
	var katana_hitbox := _player.get_node_or_null(^"Model/KatanaHitbox") as Hitbox
	var slash_flow: Vector3 = slash_blood.debug_last_flow_direction() \
		if slash_blood != null else Vector3.ZERO
	_assert("(12) 刀の血しぶきが実測した刃の進行方向へ流れる",
		slash_blood != null and katana_hitbox != null
		and slash_blood.debug_last_kind() == DirectionalBloodSpray3D.AttackKind.SLASH
		and not _last_katana_flow_at_damage.is_zero_approx()
		and slash_flow.dot(_last_katana_flow_at_damage) > 0.99)

	# 各段の60%地点で次入力を予約する。受付終端85%/90%より前で、デバウンス4f後になる。
	_played_stages.clear()
	_stage_damages.clear()
	_tracking_damage = true
	_tracked_stage = 0
	_hp_at_stage_start = _near_health.current_hp()
	_combo_completed = false
	_act(&"fire")
	await _wait_for_stage(FIRST_STAGE)
	await _wait_for_stage_ratio(FIRST_STAGE, 0.15)
	_assert("(5) 初段の構え中は円弧を出さない",
		not bool(_katana_fx.call("swing_arc_visible")))
	await _wait_for_stage_ratio(FIRST_STAGE, 0.40)
	_assert("(5) 初段の接触時だけ赤い円弧が出る",
		bool(_katana_fx.call("swing_arc_visible")))
	await _wait_for_stage_ratio(FIRST_STAGE, INPUT_WINDOW_RATIO)
	_assert("(5) 初段の振り抜きには円弧を残さない",
		not bool(_katana_fx.call("swing_arc_visible")))
	_act(&"fire")
	await _wait_for_stage(SECOND_STAGE)
	await _wait_for_stage_ratio(SECOND_STAGE, 0.10)
	_assert("(5) 二段目の構え中は円弧を出さない",
		not bool(_katana_fx.call("swing_arc_visible")))
	await _wait_for_stage_ratio(SECOND_STAGE, 0.333)
	_assert("(5) 二段目の接触時だけ赤い円弧が出る",
		bool(_katana_fx.call("swing_arc_visible")))
	await _wait_for_stage_ratio(SECOND_STAGE, INPUT_WINDOW_RATIO)
	_assert("(5) 二段目の振り抜きには円弧を残さない",
		not bool(_katana_fx.call("swing_arc_visible")))
	_act(&"fire")
	await _wait_for_stage(FINAL_STAGE)
	await _wait_for_stage_ratio(FINAL_STAGE, 0.15)
	_assert("(5) 三段目の構え中はフィニッシュ円弧を出さない",
		not bool(_katana_fx.call("final_arc_visible")))
	await _wait_for_stage_ratio(FINAL_STAGE, 0.40)
	_assert("(5) 三段目の接触時に赤いフィニッシュ円弧が出る",
		bool(_katana_fx.call("final_arc_visible")))
	await _wait_for_stage_ratio(FINAL_STAGE, 0.60)
	_assert("(5) 三段目の振り抜きにはフィニッシュ円弧を残さない",
		not bool(_katana_fx.call("final_arc_visible")))
	await _wait_until_idle()

	_assert("(5) 受付窓内の再押下で初段→二段→三段へ繋がる",
		_played_stages == [FIRST_STAGE, SECOND_STAGE, FINAL_STAGE] and _combo_completed)
	var expected_stage_1: float = float(_katana.call("stage_damage", FIRST_STAGE))
	var expected_stage_2: float = float(_katana.call("stage_damage", SECOND_STAGE))
	var expected_stage_3: float = float(_katana.call("stage_damage", FINAL_STAGE))
	var stage_1_reach: float = float(_katana.call("stage_reach", FIRST_STAGE))
	var stage_2_reach: float = float(_katana.call("stage_reach", SECOND_STAGE))
	var stage_3_reach: float = float(_katana.call("stage_reach", FINAL_STAGE))
	var damage_values_ok: bool = _stage_damages.size() == FINAL_STAGE
	if damage_values_ok:
		damage_values_ok = absf(_stage_damages[0] - expected_stage_1) <= DAMAGE_TOLERANCE \
			and absf(_stage_damages[1] - expected_stage_2) <= DAMAGE_TOLERANCE \
			and absf(_stage_damages[2] - expected_stage_3) <= DAMAGE_TOLERANCE
	_assert("(6) 各段が設定どおり40/50/70ダメージを与える (%s)" %
		str(_stage_damages), damage_values_ok)
	_assert("(7) フィニッシュは初段・二段より高威力かつ長リーチ",
		_stage_damages.size() == FINAL_STAGE and _stage_damages[2] > _stage_damages[1]
		and _stage_damages[1] > single_damage and stage_3_reach > stage_2_reach
		and stage_2_reach > stage_1_reach)

	# 刀の次は銃、その次が素手（順は 素手 → 刀 → 銃）。
	await _wait_seconds(ACTION_SETTLE_SECONDS, true)
	_act(&"switch_weapon")
	await _wait_frames(INITIAL_SETTLE_FRAMES, true)
	_assert("(8) 刀の次は銃になる",
		int(_weapon.call("kind")) == GUN_WEAPON_KIND and bool(holder.call("has_weapon")))
	_assert("(8) HUD が銃を表示する", String(hud.call("weapon_display_text"))
		== String(hud.get("weapon_gun_text")))
	_act(&"switch_weapon")
	await _wait_frames(INITIAL_SETTLE_FRAMES, true)
	_assert("(9) 銃の次は素手になり武器モデルが外れる",
		int(_weapon.call("kind")) == NONE_WEAPON_KIND and not bool(holder.call("has_weapon")))
	_assert("(9) HUD が素手を表示する", String(hud.call("weapon_display_text"))
		== String(hud.get("weapon_none_text")))
	var ammo_before_unarmed: int = int(_weapon.call("ammo"))
	_act(&"fire")
	await _wait_frames(INITIAL_SETTLE_FRAMES, true)
	_assert("(9) 素手の fire は何もせず locomotion を保つ",
		int(_weapon.call("kind")) == NONE_WEAPON_KIND
		and int(_weapon.call("ammo")) == ammo_before_unarmed
		and _playback.get_current_node() == &"locomotion")
	_act(&"attack")
	var barehand_started: bool = await _wait_for_playback_state(BAREHAND_FIRST_STATE)
	_assert("(10) 素手で既存の attack コンボ初段が出る", barehand_started)
	await _wait_for_playback_state(&"locomotion")
	_act(&"switch_weapon")
	await _wait_frames(INITIAL_SETTLE_FRAMES, true)
	_assert("(11) 素手の次は刀へ戻る",
		int(_weapon.call("kind")) == KATANA_WEAPON_KIND and bool(holder.call("has_weapon")))
	_assert("(11) HUD が日本刀を表示する", String(hud.call("weapon_display_text"))
		== String(hud.get("weapon_katana_text")))
	_finish()


func _spawn_enemy(position: Vector3) -> Node3D:
	var enemy := (load(ENEMY) as PackedScene).instantiate() as Node3D
	_stage.add_child(enemy)
	enemy.global_position = position
	enemy.set_physics_process(false)
	var hurtbox := enemy.get_node_or_null(^"Hurtbox") as Area3D
	if hurtbox != null:
		hurtbox.monitorable = true
	return enemy


func _on_near_damage_applied(_amount: float, _impact_position: Vector3) -> void:
	var katana_hitbox := _player.get_node_or_null(^"Model/KatanaHitbox") as Hitbox
	if katana_hitbox != null:
		_last_katana_flow_at_damage = katana_hitbox.impact_flow_direction()


func _act(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	# 実キーと同じく離上は別イベントとして後から届かせる。ここで同期 flush すると、
	# headless の物理フレーム途中で刀コンボだけ配送順が変わってしまう。
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event.call_deferred(release)


func _wait_frames(frame_count: int, pin_player: bool = false) -> void:
	for _frame: int in frame_count:
		_prepare_test_frame(pin_player)
		await get_tree().physics_frame


func _wait_seconds(seconds: float, pin_player: bool = false) -> void:
	var frames: int = ceili(seconds * float(Engine.physics_ticks_per_second))
	await _wait_frames(frames, pin_player)


func _wait_for_stage(expected_stage: int) -> bool:
	for _frame: int in MAX_WAIT_FRAMES:
		if int(_katana.call("current_stage")) == expected_stage:
			return true
		_prepare_test_frame(true)
		await get_tree().physics_frame
	return false


func _wait_for_stage_ratio(stage_number: int, ratio: float) -> bool:
	for _frame: int in MAX_WAIT_FRAMES:
		if int(_katana.call("current_stage")) != stage_number:
			return false
		if float(_katana.call("stage_progress")) >= ratio:
			return true
		_prepare_test_frame(true)
		await get_tree().physics_frame
	return false


func _wait_until_idle() -> bool:
	for _frame: int in MAX_WAIT_FRAMES:
		if not bool(_katana.call("is_active")):
			return true
		_prepare_test_frame(true)
		await get_tree().physics_frame
	return false


func _wait_for_playback_state(expected_state: StringName) -> bool:
	for _frame: int in MAX_WAIT_FRAMES:
		if _playback.get_current_node() == expected_state:
			return true
		_prepare_test_frame(true)
		await get_tree().physics_frame
	return false


## Enemy は遅延開始した SPAWN で Hurtbox を無効化する。物理処理を止めたテスト敵は
## SPAWN を抜けないため、旧テストと同じく各物理フレームで通常敵の被弾状態を維持する。
func _prepare_test_frame(pin_player: bool) -> void:
	if pin_player:
		_player.global_position = PLAYER_POSITION
	for enemy: Node3D in [_near, _far]:
		if enemy == null:
			continue
		var hurtbox := enemy.get_node_or_null(^"Hurtbox") as Area3D
		if hurtbox != null:
			hurtbox.monitorable = true


func _on_stage_started(stage_number: int) -> void:
	_played_stages.append(stage_number)
	if not _tracking_damage:
		return
	if _tracked_stage > 0:
		_stage_damages.append(_hp_at_stage_start - _near_health.current_hp())
	_tracked_stage = stage_number
	_hp_at_stage_start = _near_health.current_hp()


func _on_combo_finished(completed: bool) -> void:
	if not _tracking_damage:
		return
	if _tracked_stage > 0:
		_stage_damages.append(_hp_at_stage_start - _near_health.current_hp())
	_tracking_damage = false
	_combo_completed = completed


func _assert(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[PASS] " + label)
	else:
		_fail += 1
		print("[FAIL] " + label)


func _finish() -> void:
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)
