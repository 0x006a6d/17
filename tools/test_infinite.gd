extends Node
## infinite_lives=true のとき、何度倒れても残機が減らず必ず立ち上がることを確認。
const STAGE := "res://levels/belt_test.tscn"
var _belt: BeltStage
var _player: Node3D
var _health: Health
var _f := 0
var _recovered := 0
var _out := 0
var _downs := 0
var _pass := 0
var _fail := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.reset()
	RunState.infinite_lives = true
	var stage := (load(STAGE) as PackedScene).instantiate() as Node3D
	_belt = BeltStage.new(); _belt.player_path = ^"Player"; _belt.camera_path = ^"BeltCamera"; _belt.change_scene_on_continue = false
	for c in stage.get_children(): stage.remove_child(c); _belt.add_child(c)
	stage.queue_free(); add_child(_belt)
	_player = _belt.get_node("Player"); _health = _player.get_node("Health")
	_player.set("down_duration", 0.15); _player.set("stand_up_time", 0.15); _player.set("down_fall_time", 0.15)
	_player.connect("player_recovered", func(): _recovered += 1)
	_player.connect("player_out_of_lives", func(): _out += 1)
func _physics_process(_d: float) -> void:
	_f += 1
	if _f < 10: return
	# 立ち上がったら即また倒す、を繰り返す。
	if not bool(_player.call("is_downed")) and _health.current_hp() > 0.0:
		_health.take_hit(_health.max_hp); _downs += 1
	if _downs >= 6 and _f > 200:
		_assert("6回倒しても残機は初期値のまま (%d)" % RunState.lives, RunState.lives == RunState.initial_lives)
		_assert("player_out_of_lives は一度も出ない (%d)" % _out, _out == 0)
		_assert("毎回立ち上がる (recovered=%d downs=%d)" % [_recovered, _downs], _recovered >= 5)
		print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
		print("ALL PASS" if _fail == 0 else "HAS FAILURE")
		get_tree().quit(0 if _fail == 0 else 1)
func _assert(l: String, ok: bool) -> void:
	if ok: _pass += 1; print("[PASS] "+l)
	else: _fail += 1; print("[FAIL] "+l)
