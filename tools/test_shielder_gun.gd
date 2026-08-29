extends Node

## 4面ボスが「盾を構えたまま撃つ」ことの検証。
##   godot --path . --headless res://tools/test_shielder_gun.tscn
##
##   (1) 開始時から人質を保持し、SHIELD にいる
##   (2) 構えた瞬間には撃たない（shield_fire_interval ぶん置く）
##   (3) 盾を保持したまま繰り返し撃つ
##   (4) 発砲間隔は shield_fire_interval であって、解除後の gun_fire_interval ではない
##   (5) 撃っている間も人質を放さず SHIELD のまま
##   (6) 弾はプレイヤーに当たる（人質は射線を遮らない）

const STAGE := "res://levels/belt_test.tscn"
const BOSS := "res://actors/enemy/bosses/stage_4_boss.tscn"
const HOSTAGE := "res://actors/hostage/hostage.tscn"
const MAX_FRAMES := 1500
## 数える発砲の数。
const SHOTS_WANTED := 4
## 発砲間隔の許容（フレーム）。
const INTERVAL_TOLERANCE := 9
## StateMachine が動き出すまでの待ち（フレーム）。
const START_FRAME := 10

var _pass: int = 0
var _fail: int = 0
var _stage: Node3D = null
var _player: Node3D = null
var _player_health: Health = null
var _boss: Node3D = null
var _hostage: Node3D = null
var _frames: int = 0
var _shot_frames: Array[int] = []
var _left_shield: bool = false
var _player_hp_start: float = 0.0
var _checked_early: bool = false
var _fps: float = 60.0


func _ready() -> void:
	print("=== 4面ボス 盾のままの射撃 検証開始 ===")
	RunState.reset()
	_fps = float(Engine.physics_ticks_per_second)
	_stage = (load(STAGE) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node_or_null("Player") as Node3D
	for n in ["Dummy1", "Dummy2", "Dummy3"]:
		var d := _stage.get_node_or_null(n) as Node3D
		if d != null:
			d.global_position = Vector3(50.0, 0.2, 0.0)
	var camera := _stage.get_node_or_null("BeltCamera")
	if camera != null:
		camera.call("lock_at", 9.0)
	_hostage = (load(HOSTAGE) as PackedScene).instantiate() as Node3D
	_stage.add_child(_hostage)
	_hostage.global_position = Vector3(11.0, 0.2, 0.0)
	_boss = (load(BOSS) as PackedScene).instantiate() as Node3D
	_stage.add_child(_boss)
	_boss.global_position = Vector3(12.0, 0.2, 0.0)
	# 正面を -X（プレイヤー側）へ向ける。前方は -Z なので Y 回転 +90°。
	_boss.rotation.y = PI * 0.5
	# 盾の正面扇形の外、拳銃の射程内。近接では届かない距離に置く。
	_player.global_position = Vector3(6.0, 0.2, 0.0)
	_player_health = _player.get_node_or_null("Health") as Health
	_player_hp_start = _player_health.current_hp()
	var gun := _boss.get_node_or_null("HitscanGun") as HitscanGun
	gun.shot_fired.connect(func(_f: Vector3, _t: Vector3, _b: Node3D) -> void:
		_shot_frames.append(_frames))


func _physics_process(_delta: float) -> void:
	_frames += 1
	# 撃たれてのけぞっても間合いを変えない。
	_player.global_position = Vector3(6.0, 0.2, 0.0)
	# StateMachine が動き出すまで数フレーム待つ（開始直後は current_state() が -1）。
	if _frames < START_FRAME:
		return
	if int(_boss.call("current_state")) != Shielder.SHIELD:
		_left_shield = true

	if _frames == START_FRAME:
		_assert("(1) 開始時から人質を保持している",
			bool(_hostage.call("is_shielded")))
		_assert("(1) ボスが SHIELD にいる (state=%d)" % int(_boss.call("current_state")),
			int(_boss.call("current_state")) == Shielder.SHIELD)

	# 構えてから shield_fire_interval に満たないうちは撃っていない。
	var wait_frames: int = int(float(_boss.get("shield_fire_interval")) * _fps)
	if not _checked_early and _frames >= wait_frames - INTERVAL_TOLERANCE:
		_checked_early = true
		_assert("(2) 構えた直後の %.1f 秒は撃たない (発砲 %d)" %
			[float(wait_frames - INTERVAL_TOLERANCE) / _fps, _shot_frames.size()],
			_shot_frames.is_empty())

	if _shot_frames.size() >= SHOTS_WANTED:
		_finish_checks(wait_frames)
		return
	if _frames > MAX_FRAMES:
		_assert("(3) %d 発撃つまでに MAX_FRAMES を超えない (実際 %d 発)" %
			[SHOTS_WANTED, _shot_frames.size()], false)
		_finish()


func _finish_checks(wait_frames: int) -> void:
	_assert("(3) 盾のまま %d 発撃った" % SHOTS_WANTED, _shot_frames.size() >= SHOTS_WANTED)
	_assert("(5) 撃っている間ずっと SHIELD のまま", not _left_shield)
	_assert("(5) 撃っている間も人質を保持している", bool(_hostage.call("is_shielded")))

	var gaps: Array[int] = []
	for i: int in range(1, _shot_frames.size()):
		gaps.append(_shot_frames[i] - _shot_frames[i - 1])
	var gun_frames: int = int(float(_boss.get("gun_fire_interval")) * _fps)
	var ok := not gaps.is_empty()
	for gap: int in gaps:
		if absi(gap - wait_frames) > INTERVAL_TOLERANCE:
			ok = false
	_assert("(4) 発砲間隔は shield_fire_interval の %d フレーム (実際 %s)" %
		[wait_frames, str(gaps)], ok)
	var differs := true
	for gap: int in gaps:
		if absi(gap - gun_frames) <= INTERVAL_TOLERANCE:
			differs = false
	_assert("(4) 解除後の gun_fire_interval（%d フレーム）ではない" % gun_frames, differs)

	_assert("(6) 弾がプレイヤーに当たっている (HP %.0f → %.0f)" %
		[_player_hp_start, _player_health.current_hp()],
		_player_health.current_hp() < _player_hp_start)
	_finish()


func _assert(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[PASS] " + label)
	else:
		_fail += 1
		print("[FAIL] " + label)


func _finish() -> void:
	set_physics_process(false)
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)
