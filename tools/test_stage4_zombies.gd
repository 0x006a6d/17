extends Node

## 4面のゾンビ追加と、敵が画面外へ出ないことの検証（8/26）。
##   godot --path . --headless res://tools/test_stage4_zombies.tscn
##
##   (1) 4面の LockPoint1 に入るとゾンビの波が出る（雑魚シーンが zombie*.tscn）
##   (2) BossTrigger に入ると、盾持ちのボスに加えて Ch30 のゾンビが供回りに出る
##   (3) 3面ボス（GUNNER）は、プレイヤーに詰められて後退しても画面の外へ出ない
##   (4) 面の題名が HUD の上中央に出る

const STAGE_4 := "res://levels/stage_4.tscn"
const BELT_TEST := "res://levels/belt_test.tscn"
const GUN_BOSS := "res://actors/enemy/bosses/stage_3_boss.tscn"
const ZOMBIE_PREFIX := "res://actors/enemy/roles/zombie"
const ZOMBIE_ESCORT := "res://actors/enemy/roles/zombie_escort.tscn"
const MAX_FRAMES := 6000
## 画面端からの許容はみ出し（m）。Enemy.screen_margin(0.6) の内側に居るはず。
const CLAMP_TOLERANCE := 0.05

var _pass: int = 0
var _fail: int = 0
var _frames: int = 0
var _phase: int = 0
var _phase_started: int = 0

var _stage: Node3D = null
var _player: Node3D = null
var _enemies: Node = null
var _hud: Node = null
var _title_seen: bool = false

var _belt: Node3D = null
var _belt_player: Node3D = null
var _gun_boss: Node3D = null
var _camera: Node3D = null
var _worst_overshoot: float = 0.0
var _boss_entered_screen: bool = false


func _ready() -> void:
	print("=== 4面ゾンビと画面端 検証開始 ===")
	# 冒頭カードがツリーを一時停止するので、この検証ノードだけは止めない。
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.reset()
	_stage = (load(STAGE_4) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node_or_null("Player") as Node3D
	_enemies = _stage.get_node_or_null("Enemies")
	_hud = _stage.get_node_or_null("Hud")
	StageDirector.stage_title_shown.connect(func(_t: String) -> void: _title_seen = true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > MAX_FRAMES:
		_assert("全ケースが MAX_FRAMES 内に完了した (phase=%d)" % _phase, false)
		_finish()
		return
	if _frames < 10:
		return
	# 冒頭カードを閉じるまでは面側の物理が止まっている。閉じてから検証を始める。
	if _phase == 0 and StageDirector.phase == StageDirector.Phase.CARD:
		if _frames % 6 == 0:
			_accept()
		if _frames > 900:
			_assert("冒頭カードが閉じる", false)
			_finish()
		return
	var local := _frames - _phase_started
	match _phase:
		0:
			# カードが閉じた時点で BeltStage が題名を送っているはず。
			_assert("(4) 面の題名が HUD へ渡る", _title_seen)
			if _hud != null and _hud.has_method("stage_title_visible"):
				_assert("(4) 題名が画面に出ている", bool(_hud.call("stage_title_visible")))
			_player.global_position = Vector3(7.0, 0.2, 0.0)
			_next_phase()
		1:
			# (1) ロック地点でゾンビの波が出る。
			var spawned := _spawned_paths()
			if spawned.size() >= 2:
				var all_zombie := true
				for path: String in spawned:
					if not path.begins_with(ZOMBIE_PREFIX):
						all_zombie = false
				_assert("(1) 4面のロックでゾンビが %d 体出た" % spawned.size(), true)
				_assert("(1) 出た雑魚がすべてゾンビ", all_zombie)
				_next_phase()
			elif local > 420:
				_assert("(1) 4面のロックでゾンビの波が出る（出た数 %d）" % spawned.size(),
					false)
				_next_phase()
		2:
			# 波を片付けてカメラを解放する（解放されないとボス地点へ入れない）。
			_kill_spawned()
			if not _camera_locked(_stage):
				_assert("(1) 波を全滅させるとカメラが解放される", true)
				_next_phase()
			elif local > 2400:
				_assert("(1) 波を全滅させるとカメラが解放される", false)
				_next_phase()
		3:
			# プレイヤーはカメラの可視範囲に clamp されるので、瞬間移動では
			# ボス地点へ入れない。カメラを連れて少しずつ右へ進める。
			_player.global_position.x = minf(_player.global_position.x + 0.25, 14.0)
			# (2) ボス戦の供回りに Ch30 のゾンビが加わる。
			if _spawned_paths().has(ZOMBIE_ESCORT):
				_assert("(2) ボス戦に Ch30 のゾンビが加わる", true)
				_start_gun_boss_case()
				_next_phase()
			elif local > 900:
				_assert("(2) ボス戦に Ch30 のゾンビが加わる（居るのは %s）"
					% str(_spawned_paths()), false)
				_start_gun_boss_case()
				_next_phase()
		4:
			# (3) 銃使いが後退しても画面内に残る。
			_track_gun_boss()
			if local == 180:
				# 画面内へ入ったところで、後退させるために真横まで詰める。
				_belt_player.global_position = Vector3(
					_gun_boss.global_position.x - 1.0, 0.2, 0.0)
			if local > 600:
				_assert("(3) 銃使いが画面内に入った", _boss_entered_screen)
				_assert("(3) 詰めても画面外へ出ない（最大はみ出し %.3f m）"
					% _worst_overshoot, _worst_overshoot <= CLAMP_TOLERANCE)
				_finish()


## いま出ている雑魚を落とす（戦闘は再現せず、進行の確認だけが目的）。
func _kill_spawned() -> void:
	if _enemies == null or not is_instance_valid(_enemies):
		return
	for child in _enemies.get_children():
		var health := child.get_node_or_null(^"Health") as Health
		if health != null and not health.is_downed():
			health.take_hit(9999.0, true)


func _camera_of(stage: Node) -> Node3D:
	return stage.get_node_or_null(^"BeltCamera") as Node3D


## カメラが無ければ FAIL を記録し、ロック中とみなす（解放の PASS を誤って出さない）。
func _camera_locked(stage: Node) -> bool:
	var camera := _camera_of(stage)
	if camera == null:
		_assert("BeltCamera が面に存在する", false)
		return true
	return bool(camera.call("is_locked"))


## 4面のボス戦を止めて、銃使いの検証用ステージへ切り替える。
func _start_gun_boss_case() -> void:
	_stage.queue_free()
	_stage = null
	_belt = (load(BELT_TEST) as PackedScene).instantiate() as Node3D
	add_child(_belt)
	_belt_player = _belt.get_node_or_null("Player") as Node3D
	for n: String in ["Dummy1", "Dummy2", "Dummy3"]:
		var d := _belt.get_node_or_null(n) as Node3D
		if d != null:
			d.global_position = Vector3(50.0, 0.2, 0.0)
	_camera = _belt.get_node_or_null("BeltCamera") as Node3D
	_belt_player.global_position = Vector3(10.0, 0.2, 0.0)
	_camera.call("lock_at", 10.0)
	_gun_boss = (load(GUN_BOSS) as PackedScene).instantiate() as Node3D
	_belt.add_child(_gun_boss)
	_gun_boss.global_position = Vector3(13.0, 0.2, 0.0)
	_gun_boss.call("set_belt_bounds", -1.5, 1.5)


func _track_gun_boss() -> void:
	if _gun_boss == null or not is_instance_valid(_gun_boss) or _camera == null:
		return
	var left: float = float(_camera.call("left_limit"))
	var right: float = float(_camera.call("right_limit"))
	var x: float = _gun_boss.global_position.x
	if x > left and x < right:
		_boss_entered_screen = true
	if not _boss_entered_screen:
		return
	_worst_overshoot = maxf(_worst_overshoot, maxf(x - right, left - x))


## いま Enemies 配下に居る敵の、元シーンのパス一覧。
func _spawned_paths() -> PackedStringArray:
	var out := PackedStringArray()
	if _enemies == null or not is_instance_valid(_enemies):
		return out
	for child in _enemies.get_children():
		out.append(child.scene_file_path)
	return out


## テキストカードを閉じるための決定入力。
func _accept() -> void:
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	Input.parse_input_event(event)


func _next_phase() -> void:
	_phase += 1
	_phase_started = _frames


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
