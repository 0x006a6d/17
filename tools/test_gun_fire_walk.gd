extends Node

## 撃った直後に歩いたとき、脚が銃持ち歩行のままかを見る。
##   godot --path . --headless res://tools/test_gun_fire_walk.tscn
##
## 発砲は静止した構えへ OneShot で重ねる（technical-spec §17.1）。この重なりを
## 上半身へ絞っていないと、重なっている約1秒のあいだ脚まで発砲クリップの立ち姿勢に
## なり、撃った直後に歩いても銃持ち歩行の絵にならない。
##
##   (1) 撃っている間も両足は歩行の周期を刻む
##   (2) 撃った直後の脚は、撃たずに歩いているときと同じ高さに来る
##   (3) 上半身（右手）には発砲の反動が出ている

const PLAYER: PackedScene = preload("res://actors/player/player.tscn")
## 歩行として与える速度（m/s）。銃歩行の基準 2.09 を越える実移動速度。
const WALK_SPEED: float = 4.5
## 標本を取るフレーム数。発砲の重なり（約1.037秒）を覆う。
const SAMPLE_FRAMES: int = 70
## 足の上下動がこれ以上あれば歩いていると見なす（m）。上半身へ絞らないと
## 発砲クリップに引かれて 0.055m まで潰れるので、その上に置く。
const STEP_RANGE_MIN: float = 0.10
## 撃ちながら歩いた足の高さと、撃たずに歩いた足の高さの許容差（m）。
const FOOT_MATCH_TOLERANCE: float = 0.03
## 右手がこれ以上動いていれば反動が出ていると見なす（m）。
const HAND_RANGE_MIN: float = 0.01

var _pass: int = 0
var _fail: int = 0


func _ready() -> void:
	print("=== 撃った直後の歩行 検証開始 ===")
	RunState.reset()
	_run()


func _run() -> void:
	var walking: Dictionary = await _sample(false)
	var firing: Dictionary = await _sample(true)
	if walking.is_empty() or firing.is_empty():
		_assert("骨を取得できる", false)
		_finish()
		return

	var foot_range: float = firing["foot_range"]
	_assert("(1) 撃っている間も足が歩行の周期を刻む（上下動 %.3fm）" % foot_range,
		foot_range >= STEP_RANGE_MIN)
	var foot_gap: float = absf(firing["foot_mean"] - walking["foot_mean"])
	_assert("(2) 撃たずに歩いたときと足の高さが揃う（差 %.3fm）" % foot_gap,
		foot_gap <= FOOT_MATCH_TOLERANCE)
	var hand_range: float = firing["hand_range"]
	_assert("(3) 右手に発砲の反動が出る（移動量 %.3fm）" % hand_range,
		hand_range >= HAND_RANGE_MIN)
	_finish()


## 銃を構えて歩かせ、足と右手の動きを測る。fire=true なら測り始めに1発撃つ。
func _sample(fire: bool) -> Dictionary:
	var player := PLAYER.instantiate() as CharacterBody3D
	add_child(player)
	await _wait_frames(4)
	# player.gd の _physics_process は実速度（ここでは 0）で set_locomotion を
	# 上書きするので止める。歩行はこのテストが直接与える。
	player.set_physics_process(false)
	var melee: Node = player.get_node(^"PlayerMelee")
	var weapon: Node = player.get_node(^"PlayerWeapon")
	weapon.call("equip_gun")
	await _wait_frames(2)
	var skeleton := _find_skeleton(player.get_node(^"Model"))
	if skeleton == null:
		player.queue_free()
		await _wait_frames(2)
		return {}
	var left_foot: int = skeleton.find_bone("LeftFoot")
	var right_foot: int = skeleton.find_bone("RightFoot")
	var right_hand: int = skeleton.find_bone("RightHand")
	if left_foot < 0 or right_foot < 0 or right_hand < 0:
		player.queue_free()
		await _wait_frames(2)
		return {}
	# 歩行のブレンドを先に立ち上げてから撃つ（撃った瞬間だけを見たいので）。
	for _i: int in range(6):
		melee.call("set_locomotion", WALK_SPEED)
		await get_tree().process_frame
	if fire:
		melee.call("play_gun_fire")

	var foot_min: float = INF
	var foot_max: float = -INF
	var foot_sum: float = 0.0
	var hand_min: float = INF
	var hand_max: float = -INF
	for _i: int in range(SAMPLE_FRAMES):
		melee.call("set_locomotion", WALK_SPEED)
		await get_tree().process_frame
		var lift: float = absf(skeleton.get_bone_global_pose(left_foot).origin.y
			- skeleton.get_bone_global_pose(right_foot).origin.y)
		foot_min = minf(foot_min, lift)
		foot_max = maxf(foot_max, lift)
		foot_sum += lift
		var hand_y: float = skeleton.get_bone_global_pose(right_hand).origin.y
		hand_min = minf(hand_min, hand_y)
		hand_max = maxf(hand_max, hand_y)
	player.queue_free()
	await _wait_frames(2)
	return {
		"foot_range": foot_max - foot_min,
		"foot_mean": foot_sum / float(SAMPLE_FRAMES),
		"hand_range": hand_max - hand_min,
	}


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


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
