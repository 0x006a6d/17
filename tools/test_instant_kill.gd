extends Node

## 一撃即死（刀・銃のヘッドショット）の検証。
##   godot --path . --headless res://tools/test_instant_kill.tscn
##
##   (1) 確率 1.0 なら、刀の命中1発で雑魚が倒れる
##   (2) 確率 0.0 なら起きない
##   (3) ボスには起きない
##   (4) 4面では起きない
##   (5) 銃の命中でも同じ規則で起きる

const STAGE_PATH: String = "res://levels/belt_test.tscn"
const ENEMY_PATH: String = "res://actors/enemy/enemy.tscn"
const STAGE_4_BOSS_PATH: String = "res://actors/enemy/bosses/stage_4_boss.tscn"
const SETTLE_FRAMES: int = 4

var _pass: int = 0
var _fail: int = 0
var _stage: Node3D = null
var _hitbox: Hitbox = null
var _weapon: PlayerWeapon = null
var _instant_kill: PlayerInstantKill = null


func _ready() -> void:
	print("=== 一撃即死 検証開始 ===")
	_run()


func _run() -> void:
	RunState.reset()
	_stage = (load(STAGE_PATH) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	for dummy_name: String in ["Dummy1", "Dummy2", "Dummy3"]:
		var dummy := _stage.get_node_or_null(NodePath(dummy_name)) as Node3D
		if dummy != null:
			dummy.global_position = Vector3(60.0, 0.2, 0.0)
	var player := _stage.get_node(^"Player") as Node3D
	_hitbox = player.get_node(^"Model/KatanaHitbox") as Hitbox
	_weapon = player.get_node(^"PlayerWeapon") as PlayerWeapon
	_instant_kill = player.get_node(^"PlayerInstantKill") as PlayerInstantKill
	await _wait_frames(SETTLE_FRAMES)

	RunState.set_stage(GameTypes.Stage.STAGE_1)
	_instant_kill.katana_chance = 1.0
	var grunt := _spawn(ENEMY_PATH)
	var grunt_health := grunt.get_node(^"Health") as Health
	var full_hp: float = grunt_health.current_hp()
	_hitbox.hit_landed.emit(grunt)
	_assert("(1) 確率1.0なら刀の1発で雑魚が倒れる (HP=%.0f→%.0f)" % [
		full_hp, grunt_health.current_hp()], grunt_health.is_downed())

	_instant_kill.katana_chance = 0.0
	var survivor := _spawn(ENEMY_PATH)
	var survivor_health := survivor.get_node(^"Health") as Health
	_hitbox.hit_landed.emit(survivor)
	_assert("(2) 確率0.0なら起きない (HP=%.0f)" % survivor_health.current_hp(),
		not survivor_health.is_downed()
		and is_equal_approx(survivor_health.current_hp(), survivor_health.max_hp))

	_instant_kill.katana_chance = 1.0
	var boss := _spawn(STAGE_4_BOSS_PATH)
	var boss_health := boss.get_node(^"Health") as Health
	_assert("(3) ボスは対象外だと判定する", not _instant_kill.can_instant_kill(boss))
	_hitbox.hit_landed.emit(boss)
	_assert("(3) ボスは一撃即死しない (HP=%.0f)" % boss_health.current_hp(),
		not boss_health.is_downed())

	RunState.set_stage(GameTypes.Stage.STAGE_4)
	var zombie := _spawn(ENEMY_PATH)
	var zombie_health := zombie.get_node(^"Health") as Health
	_assert("(4) 4面は対象外だと判定する", not _instant_kill.can_instant_kill(zombie))
	_hitbox.hit_landed.emit(zombie)
	_assert("(4) 4面では一撃即死しない (HP=%.0f)" % zombie_health.current_hp(),
		not zombie_health.is_downed())

	RunState.set_stage(GameTypes.Stage.STAGE_1)
	_instant_kill.gun_chance = 1.0
	var shot := _spawn(ENEMY_PATH)
	var shot_health := shot.get_node(^"Health") as Health
	_weapon.shot_hit.emit(shot)
	_assert("(5) 確率1.0なら銃の1発で雑魚が倒れる (HP=%.0f)" % shot_health.current_hp(),
		shot_health.is_downed())

	_instant_kill.gun_chance = 0.0
	var shot_survivor := _spawn(ENEMY_PATH)
	var shot_survivor_health := shot_survivor.get_node(^"Health") as Health
	_weapon.shot_hit.emit(shot_survivor)
	_assert("(5) 銃も確率0.0なら起きない (HP=%.0f)" % shot_survivor_health.current_hp(),
		not shot_survivor_health.is_downed())

	RunState.set_stage(GameTypes.Stage.STAGE_4)
	_instant_kill.gun_chance = 1.0
	var shot_zombie := _spawn(ENEMY_PATH)
	var shot_zombie_health := shot_zombie.get_node(^"Health") as Health
	_weapon.shot_hit.emit(shot_zombie)
	_assert("(5) 銃も4面では起きない (HP=%.0f)" % shot_zombie_health.current_hp(),
		not shot_zombie_health.is_downed())

	RunState.set_stage(GameTypes.Stage.STAGE_1)
	_finish()


func _spawn(path: String) -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	_stage.add_child(node)
	node.global_position = Vector3(40.0, 0.2, 0.0)
	node.set_physics_process(false)
	return node


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


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
