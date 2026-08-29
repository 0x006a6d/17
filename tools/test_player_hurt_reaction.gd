extends Node

const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const INPUT_LOCK_EXPECTED: float = 0.28
const REACTION_EXPECTED: float = 0.60

var _failures: int = 0


func _ready() -> void:
	print("=== 主人公のけぞり表示時間 検証 ===")
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as CharacterBody3D
	add_child(player)
	await get_tree().physics_frame
	var melee := player.get_node("PlayerMelee")
	var state_before: String = str(melee.get("_state"))
	player.receive_knockback(Vector3.FORWARD, 3.0)
	_check(is_equal_approx(float(player.get("_hurt_timer")), INPUT_LOCK_EXPECTED),
		"入力ロックは0.28秒のまま")
	_check(is_equal_approx(float(melee.get("_hurt_duration")), REACTION_EXPECTED),
		"表示時間は独立した0.60秒")
	_check(str(melee.get("_state")) == state_before, "被弾でコンボ状態を遷移しない")
	for frame: int in 18:
		await get_tree().physics_frame
	_check(float(player.get("_hurt_timer")) <= 0.0, "0.30秒後に入力ロック解除")
	_check(float(melee.get("_hurt_time_left")) > 0.0, "入力ロック解除後ものけぞり表示継続")
	var tree := melee.get_node("AnimationTree") as AnimationTree
	var blend: float = float(tree.get("parameters/hurt_blend/blend_amount"))
	_check(blend >= 0.9, "表示時間の前半は強いブレンドを保持")
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(_failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	_failures += 1
	print("FAIL: ", label)
