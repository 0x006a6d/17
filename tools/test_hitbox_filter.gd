extends Node

## Hitbox の陣営フィルタ（ignore_groups）の検証。
##   godot --path . --headless res://tools/test_hitbox_filter.tscn
##
## 検証項目:
##   (1) 敵の判定は同じ enemy グループの敵に当たらない
##   (2) 同じ判定がプレイヤーには当たる（フィルタが効きすぎていない）
##
## AI のタイミングに依存しないよう、判定は _open_hitbox() を直接叩いて開く。
## 敵 AI は止める（段追従で動かれると位置がずれる）。

const STAGE := "res://levels/belt_test.tscn"
const ENEMY := "res://actors/enemy/enemy.tscn"
const SETTLE_FRAMES := 12

var _pass: int = 0
var _fail: int = 0
var _stage: Node3D = null
var _player: Node3D = null
var _player_health: Health = null
var _attacker: Node3D = null
var _victim: Node3D = null
var _victim_health: Health = null
var _victim_hp_after: float = -1.0
var _player_hp_after: float = -1.0
var _frames: int = 0
var _phase: int = 0
var _phase_started: int = 0


func _ready() -> void:
	print("=== Hitbox 陣営フィルタ 検証開始 ===")
	RunState.reset()
	var packed := load(STAGE) as PackedScene
	if packed == null:
		_fatal("belt_test load 失敗")
		return
	_stage = packed.instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node_or_null("Player") as Node3D
	_player_health = _player.get_node_or_null("Health") as Health if _player != null else null
	var enemy_packed := load(ENEMY) as PackedScene
	_attacker = enemy_packed.instantiate() as Node3D
	_victim = enemy_packed.instantiate() as Node3D
	_stage.add_child(_attacker)
	_stage.add_child(_victim)
	_attacker.set_physics_process(false)
	_victim.set_physics_process(false)
	_victim_health = _victim.get_node_or_null("Health") as Health
	if _player == null or _player_health == null or _victim_health == null:
		_fatal("Player / Enemy の初期化に失敗")


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 6:
		return
	match _phase:
		0:
			# 攻撃側を x=10 に置き、被害側の敵を判定球の中へ、プレイヤーは画面内の遠くへ。
			# カメラは x=10 に固定する（追従待ちの間、画面端 clamp でプレイヤーが押し戻される
			# のを避ける。検証したいのは陣営フィルタであって画面端ではない）。
			var camera := _stage.get_node_or_null("BeltCamera")
			if camera != null:
				camera.call("lock_at", 10.0)
			_attacker.global_position = Vector3(10.0, 0.2, 0.0)
			_player.global_position = Vector3(13.5, 0.2, 0.0)
			_victim.global_position = _hitbox_center()
			_advance(1)
		1:
			_player.global_position = Vector3(13.5, 0.2, 0.0)
			_victim.global_position = _hitbox_center()
			if _frames - _phase_started == 1:
				_attacker.call("_open_hitbox")
			if _frames - _phase_started >= SETTLE_FRAMES:
				_victim_hp_after = _victim_health.current_hp()
				print("[enemy→enemy] 敵2の HP=%.1f（判定を %d フレーム開いた）" %
					[_victim_hp_after, SETTLE_FRAMES])
				_attacker.call("_close_hitbox")
				_victim.global_position = Vector3(13.5, 0.2, 1.0)
				_advance(2)
		2:
			_player.global_position = _hitbox_center()
			if _frames - _phase_started == 1:
				_attacker.call("_open_hitbox")
			if _frames - _phase_started >= SETTLE_FRAMES:
				_player_hp_after = _player_health.current_hp()
				print("[enemy→player] プレイヤーの HP=%.1f" % _player_hp_after)
				_evaluate()


## 攻撃側の MeleeHitbox のワールド座標（足元基準）。
func _hitbox_center() -> Vector3:
	var hitbox := _attacker.get_node("MeleeHitbox") as Node3D
	var pos := hitbox.global_position
	pos.y = _attacker.global_position.y
	return pos


func _advance(phase: int) -> void:
	_phase = phase
	_phase_started = _frames


func _evaluate() -> void:
	_assert("敵の判定は味方の敵に当たらない",
		is_equal_approx(_victim_hp_after, _victim_health.max_hp))
	_assert("同じ判定がプレイヤーには当たる", _player_hp_after < _player_health.max_hp)
	_assert("味方誤爆で RunState の撃破数が増えていない", RunState.enemies_downed == 0)
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)


func _assert(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[PASS] " + label)
	else:
		_fail += 1
		print("[FAIL] " + label)


func _fatal(msg: String) -> void:
	print("[FATAL] " + msg)
	_fail += 1
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("HAS FAILURE")
	get_tree().quit(1)
