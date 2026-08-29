extends Node

## 全面の接続チェーンの自動走破検証。
##   godot --path . --headless res://tools/test_chain.tscn
## 自分は current_scene ではなく root 直下に居座り、各面を current_scene として差し替えていく
## （BeltStage の change_scene_to_file が current_scene を置換しても自分は残る）。
## 毎フレーム: カードが出ていれば ui_accept、敵が居れば即倒す、プレイヤーは右へ走らせる。
## 到達した面の順序に加え、2・3面の lock→波→GO→boss→clear、波の構成、
## 幕間カード、3面銃ボスの初期間合いを記録して確認する。

const FIRST := "res://levels/stage_1.tscn"
## 4面にゾンビの波を足したぶん、通しの所要フレームが伸びている。
const MAX_FRAMES := 9000
const CH06_SCENE: String = "res://actors/enemy/roles/grunt_c.tscn"
## 色違い（上半身を黄色にした ch06）。素の ch06 と同じモデルなので同等に数える。
const CH06_ALT_SCENE: String = "res://actors/enemy/roles/grunt_c_yellow.tscn"
const STAGE_NUMBER_OFFSET: int = 1
const STAGE_2_NUMBER: int = 2
const STAGE_3_NUMBER: int = 3
const STAGE_2_TOTAL: int = 13
const STAGE_3_TOTAL: int = 17
const CORRIDOR_MIN_GAP: float = 10.0
const EXPECTED_LOCK_INDICES: Array[int] = [0, 1]

const EXPECTED_CARDS: Dictionary = {
	"Stage2": ["ミカゼ「次は地下鉄。流れが速いから、止まらないで。」"],
	"Stage3": ["ミカゼ「湾岸。人が一番集まった場所。」"],
	"Stage4": ["ミカゼ「工場。ニケはこの奥にいる。」"],
}

var _seen: Array[String] = []
var _last_scene := ""
var _f := 0
var _reached_ed := false
var _pass := 0
var _fail := 0
var _lock_started_by_stage: Dictionary = {}
var _lock_cleared_by_stage: Dictionary = {}
var _boss_started_by_stage: Dictionary = {}
var _stage_cleared: Dictionary = {}
var _card_content_ok: Dictionary = {}
var _stage_3_boss_spawn_distance: float = -1.0
var _stage_3_boss_retreat_distance: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.reset()
	StageDirector.reset()
	StageDirector.lock_started.connect(_on_lock_started)
	StageDirector.lock_cleared.connect(_on_lock_cleared)
	StageDirector.boss_started.connect(_on_boss_started)
	StageDirector.stage_cleared.connect(_on_stage_cleared)
	_load_first.call_deferred()


func _load_first() -> void:
	var stage := (load(FIRST) as PackedScene).instantiate()
	get_tree().root.add_child(stage)
	get_tree().current_scene = stage


func _physics_process(_d: float) -> void:
	_f += 1
	if _f > MAX_FRAMES:
		_assert("MAX_FRAMES 内に ED へ到達（seen=%s）" % str(_seen), _reached_ed)
		_finish()
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	# 面が変わったら記録＋撮影。
	if scene.name != _last_scene:
		_last_scene = String(scene.name)
		if _last_scene.begins_with("Stage") and not _seen.has(_last_scene):
			_seen.append(_last_scene)
			_record_card_content(scene)
	# カードが出てツリーが止まっていれば送って進める。
	if get_tree().paused:
		var e := InputEventAction.new(); e.action = "ui_accept"; e.pressed = true
		Input.parse_input_event(e)
		# ED（stage_5 到達後にカード）を踏んだら成功として止める。
		if _seen.has("Stage5"):
			_reached_ed = true
		return
	# プレイヤーを右へ、敵は即倒す。
	var e2 := InputEventKey.new(); e2.physical_keycode = KEY_D; e2.pressed = true
	Input.parse_input_event(e2)
	if StageDirector.phase == StageDirector.Phase.LOCKED \
			or StageDirector.phase == StageDirector.Phase.BOSS:
		var boss_phase: bool = StageDirector.phase == StageDirector.Phase.BOSS
		for n in get_tree().get_nodes_in_group(&"enemy"):
			# 面に置いてあるボス（4面の盾持ち）は波と同じグループに居るが、実プレイでは
			# 画面外で届かない。ボス戦に入る前に倒すと BossTrigger の参照先が消える。
			if not boss_phase and (n as Node).has_method("is_boss") \
					and bool((n as Node).call("is_boss")):
				continue
			var h := (n as Node).get_node_or_null("Health") as Health
			if h != null and not h.is_downed():
				h.take_hit(h.max_hp)
	# 人質はダウンしないので放置。Stage5 到達後、ボス撃破→ED カードで _reached_ed。
	if _reached_ed:
		_verify_and_finish()


func _verify_and_finish() -> void:
	_assert("stage_1 を通過した", _seen.has("Stage1"))
	_assert("stage_2 を通過した", _seen.has("Stage2"))
	_assert("stage_3 を通過した", _seen.has("Stage3"))
	_assert("stage_4 を通過した", _seen.has("Stage4"))
	_assert("stage_5 に到達した", _seen.has("Stage5"))
	_assert("ED まで到達した（seen=%s）" % str(_seen), _reached_ed)
	_assert("1→2 の幕間カード文言", bool(_card_content_ok.get("Stage2", false)))
	_assert("2→3 の幕間カード文言", bool(_card_content_ok.get("Stage3", false)))
	_assert("3→4 の幕間カード文言", bool(_card_content_ok.get("Stage4", false)))
	_assert("2面が lock×2 → GO×2 → boss → clear と進む",
		_stage_flow_completed(STAGE_2_NUMBER))
	_assert("3面が lock×2 → GO×2 → boss → clear と進む",
		_stage_flow_completed(STAGE_3_NUMBER))
	_verify_stage_content()
	_finish()


func _on_lock_started(lock_index: int) -> void:
	_append_stage_event(_lock_started_by_stage,
		RunState.current_stage + STAGE_NUMBER_OFFSET, lock_index)


func _on_lock_cleared(lock_index: int) -> void:
	_append_stage_event(_lock_cleared_by_stage,
		RunState.current_stage + STAGE_NUMBER_OFFSET, lock_index)


func _on_boss_started(boss: Node3D) -> void:
	var stage_number: int = RunState.current_stage + STAGE_NUMBER_OFFSET
	_boss_started_by_stage[stage_number] = true
	if stage_number != STAGE_3_NUMBER or boss == null:
		return
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null:
		_stage_3_boss_spawn_distance = absf(boss.global_position.x - player.global_position.x)
	_stage_3_boss_retreat_distance = float(boss.get("gun_retreat_distance"))


func _on_stage_cleared(stage: int) -> void:
	_stage_cleared[stage + STAGE_NUMBER_OFFSET] = true


func _append_stage_event(target: Dictionary, stage_number: int, value: int) -> void:
	var events: Array = target.get(stage_number, []) as Array
	events.append(value)
	target[stage_number] = events


func _stage_flow_completed(stage_number: int) -> bool:
	var started: Array = _lock_started_by_stage.get(stage_number, []) as Array
	var cleared: Array = _lock_cleared_by_stage.get(stage_number, []) as Array
	return started == EXPECTED_LOCK_INDICES and cleared == EXPECTED_LOCK_INDICES \
		and bool(_boss_started_by_stage.get(stage_number, false)) \
		and bool(_stage_cleared.get(stage_number, false))


func _record_card_content(scene: Node) -> void:
	var scene_name: String = String(scene.name)
	if not EXPECTED_CARDS.has(scene_name):
		return
	var actual: Array[String] = scene.get("opening_lines") as Array[String]
	var expected: Array = EXPECTED_CARDS[scene_name] as Array
	_card_content_ok[scene_name] = _lines_match(actual, expected)


func _lines_match(actual: Array[String], expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index: int in range(actual.size()):
		if actual[index] != String(expected[index]):
			return false
	return true


## ch06 が波に居るか。色違いでも同じモデルなので、どちらかが居ればよい。
func _contains_ch06(stage_root: Node) -> bool:
	return _stage_contains(stage_root, CH06_SCENE) \
		or _stage_contains(stage_root, CH06_ALT_SCENE)


func _verify_stage_content() -> void:
	var stage_2: Node = (load("res://levels/stage_2.tscn") as PackedScene).instantiate()
	var stage_3: Node = (load("res://levels/stage_3.tscn") as PackedScene).instantiate()
	_assert("2面は13体で1面より難しくする", _wave_total(stage_2) == STAGE_2_TOTAL)
	_assert("3面は17体で2面より難しくする", _wave_total(stage_3) == STAGE_3_TOTAL)
	_assert("2・3面の波に ch06 を使う",
		_contains_ch06(stage_2) and _contains_ch06(stage_3))
	var lock_2: Node3D = stage_3.get_node_or_null(^"LockPoint2") as Node3D
	var trigger: BossTrigger = stage_3.get_node_or_null(^"BossTrigger") as BossTrigger
	var corridor_gap: float = trigger.position.x - lock_2.position.x \
		if trigger != null and lock_2 != null else -1.0
	_assert("3面は第2ロックからボスまで通路の間合いがある (%.1fm)" % corridor_gap,
		corridor_gap >= CORRIDOR_MIN_GAP and trigger != null and trigger.side == 1)
	_assert("3面ボスは後退開始距離より外から出現する (spawn=%.2fm retreat=%.2fm)" % [
		_stage_3_boss_spawn_distance, _stage_3_boss_retreat_distance],
		_stage_3_boss_retreat_distance > 0.0
		and _stage_3_boss_spawn_distance >= _stage_3_boss_retreat_distance)
	stage_2.free()
	stage_3.free()


func _wave_total(stage: Node) -> int:
	var total: int = 0
	for child: Node in stage.get_children():
		var lock_point: LockPoint = child as LockPoint
		if lock_point == null:
			continue
		for wave: WaveSpec in lock_point.waves:
			if wave != null:
				total += wave.count
	return total


func _stage_contains(stage: Node, scene_path: String) -> bool:
	for child: Node in stage.get_children():
		var lock_point: LockPoint = child as LockPoint
		if lock_point == null:
			continue
		for wave: WaveSpec in lock_point.waves:
			if wave != null and wave.enemy_scene != null \
					and wave.enemy_scene.resource_path == scene_path:
				return true
	return false


func _assert(label: String, ok: bool) -> void:
	if ok: _pass += 1; print("[PASS] " + label)
	else: _fail += 1; print("[FAIL] " + label)


func _finish() -> void:
	set_physics_process(false)
	print("=== 結果: PASS=%d FAIL=%d 到達順=%s ===" % [_pass, _fail, str(_seen)])
	print("ALL PASS" if _fail == 0 and _pass > 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 and _pass > 0 else 1)
