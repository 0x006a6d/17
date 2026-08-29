extends Node

## 敵の段追従 AI（8/24）の検証。
##   godot --path . --headless res://tools/test_enemy_ai.tscn
##
##   (1) 画面右の外に出現した敵が、プレイヤーの段（Z）へ寄りながら X を詰め、
##       一定時間内に ATTACK へ入ってプレイヤーの HP が減る
##   (2) プレイヤーを 1.2 m 奥へ移すと、敵が Z を合わせ直す（|dz| が縮む）
##   (3) 敵を倒すと defeated が 1 回出て、RunState.enemies_downed が増え、
##       消滅直前に薄く点滅して despawn_delay 後にツリーから消える
##   (4) LockPoint: 2 体の波を出し、全滅で cleared が出る（スポーンは面側の Callable）

const STAGE := "res://levels/belt_test.tscn"
const ENEMY := "res://actors/enemy/enemy.tscn"
const MAX_FRAMES := 3000

var _pass: int = 0
var _fail: int = 0
var _stage: Node3D = null
var _player: Node3D = null
var _player_health: Health = null
var _enemy: Node3D = null
var _enemy_health: Health = null
var _frames: int = 0
var _phase: int = 0
var _phase_started: int = 0
var _attack_seen: bool = false
var _defeated_count: int = 0
var _min_dz_after_shift: float = INF
var _lock: LockPoint = null
var _lock_cleared: bool = false
var _spawned: Array[Node3D] = []
var _blink_started: bool = false
var _blink_opacity_changed: bool = false


func _ready() -> void:
	print("=== 敵の段追従 AI 検証開始 ===")
	RunState.reset()
	_stage = (load(STAGE) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node_or_null("Player") as Node3D
	_player_health = _player.get_node_or_null("Health") as Health
	# ダミーを遠ざける。
	for n in ["Dummy1", "Dummy2", "Dummy3"]:
		var d := _stage.get_node_or_null(n) as Node3D
		if d != null:
			d.global_position = Vector3(50.0, 0.2, 0.0)
	_enemy = (load(ENEMY) as PackedScene).instantiate() as Node3D
	_stage.add_child(_enemy)
	_enemy.global_position = Vector3(12.0, 0.2, -1.0)
	_enemy.call("set_belt_bounds", -1.5, 1.5)
	_enemy_health = _enemy.get_node_or_null("Health") as Health
	_enemy.connect("state_entered", func(state: int) -> void:
		if state == 2:  # Enemy.State.ATTACK
			_attack_seen = true)
	_enemy.connect("defeated", func(_e: Node3D) -> void: _defeated_count += 1)
	var blink: ModelBlink = _enemy.get_node_or_null(^"DespawnBlink") as ModelBlink
	if blink != null:
		blink.blink_started.connect(func() -> void: _blink_started = true)
		blink.opacity_changed.connect(func(opacity: float) -> void:
			if opacity < 1.0:
				_blink_opacity_changed = true)
	_player.global_position = Vector3(4.0, 0.2, 0.5)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > MAX_FRAMES:
		_assert("全ケースが MAX_FRAMES 内に完了した (phase=%d)" % _phase, false)
		_finish()
		return
	var local := _frames - _phase_started
	match _phase:
		0:
			# (1) 敵が寄ってきて殴るまで待つ（最大 8 秒）。プレイヤーは動かさない。
			if _attack_seen and _player_health.current_hp() < _player_health.max_hp:
				_assert("(1) 敵が段を合わせて接近し ATTACK へ入り、プレイヤーの HP が減った",
					true)
				var dz := absf(_enemy.global_position.z - _player.global_position.z)
				_assert("(1) 攻撃時の奥行き差が 0.6 m 以内 (%.2f)" % dz, dz <= 0.6)
				# (2) プレイヤーを奥へ移す。
				_player.global_position.z = -0.9
				_min_dz_after_shift = INF
				_advance(1)
			elif local > 480:
				_assert("(1) 敵が 8 秒以内に接近して殴る (attack_seen=%s hp=%.0f)" %
					[_attack_seen, _player_health.current_hp()], false)
				_advance(1)
		1:
			var dz := absf(_enemy.global_position.z - _player.global_position.z)
			_min_dz_after_shift = minf(_min_dz_after_shift, dz)
			if local >= 150:
				_assert("(2) プレイヤーが段を変えると敵が Z を合わせ直す (min dz=%.2f)" %
					_min_dz_after_shift, _min_dz_after_shift <= 0.6)
				# (3) 倒す。
				_enemy_health.take_hit(_enemy_health.max_hp)
				_advance(2)
		2:
			if local == 2:
				_assert("(3) defeated が 1 回出た (実測 %d)" % _defeated_count, _defeated_count == 1)
				_assert("(3) RunState.enemies_downed == 1 (実測 %d)" % RunState.enemies_downed,
					RunState.enemies_downed == 1)
			# despawn_delay 4.0 s + 余裕
			if local >= 300:
				var gone := not is_instance_valid(_enemy) or not _enemy.is_inside_tree()
				_assert("(3) 消滅直前に点滅が始まり不透明度が変わる",
					_blink_started and _blink_opacity_changed)
				_assert("(3) despawn_delay 後にツリーから消える", gone)
				_start_lock_test()
				_advance(3)
		3:
			if _lock_cleared:
				_assert("(4) 波の全滅で LockPoint.cleared が出た", true)
				_finish()
			elif local == 30:
				# 出現した 2 体を倒す。
				_assert("(4) 波で 2 体出た (実測 %d)" % _spawned.size(), _spawned.size() == 2)
				for e in _spawned:
					var h := e.get_node_or_null("Health") as Health
					if h != null:
						h.take_hit(h.max_hp)
			elif local > 600:
				_assert("(4) 波の全滅で LockPoint.cleared が出る", false)
				_finish()


func _start_lock_test() -> void:
	_lock = LockPoint.new()
	var wave := WaveSpec.new()
	wave.enemy_scene = load(ENEMY) as PackedScene
	wave.count = 2
	wave.side = 0
	wave.delay = 0.0
	wave.spacing = 0.1
	_lock.waves = [wave]
	_stage.add_child(_lock)
	_lock.cleared.connect(func(_lp: LockPoint) -> void: _lock_cleared = true)
	_lock.start(_spawn)


func _spawn(scene: PackedScene, side: int) -> Node3D:
	var e := scene.instantiate() as Node3D
	_stage.add_child(e)
	e.global_position = Vector3(4.0 + float(side) * 7.0, 0.2, 0.0)
	_spawned.append(e)
	return e


func _advance(phase: int) -> void:
	_phase = phase
	_phase_started = _frames


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
