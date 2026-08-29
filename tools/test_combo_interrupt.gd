extends Node

const STAGE_SCENE: String = "res://levels/belt_test.tscn"
const ENEMY_SCENE: String = "res://actors/enemy/enemy.tscn"

var _failures: int = 0


func _ready() -> void:
	print("=== コンボ中断ノックバック 検証開始 ===")
	var stage := (load(STAGE_SCENE) as PackedScene).instantiate() as Node3D
	add_child(stage)
	var player := stage.get_node("Player") as CharacterBody3D
	var melee := player.get_node("PlayerMelee")
	var robber := (load(ENEMY_SCENE) as PackedScene).instantiate() as CharacterBody3D
	stage.add_child(robber)
	robber.global_position = Vector3(20.0, 0.2, 0.0)
	# AI に動かれると _knockback_timer の観測がぶれるため止める。
	robber.set_physics_process(false)
	await get_tree().physics_frame

	# ジャブで途切れた場合は、最後の命中先へ追加ノックバックが入る。
	player.call("_on_combo_started")
	player.call("_on_hit_landed", robber)
	robber.set("_knockback_timer", 0.0)
	melee.set("combo_grace_time", 0.05)
	melee.set("_combo_node", &"p_jab")
	melee.set("_state", "melee_1")
	melee.call("_finish_combo")
	_check(is_zero_approx(float(robber.get("_knockback_timer"))),
		"non-finisher knockback is held during combo grace")
	for _frame: int in 5:
		await get_tree().physics_frame
	_check(float(robber.get("_knockback_timer")) > 0.0,
		"途中終了は最後の命中先をノックバック")

	# 既存の大ノックバック技（hook）で終わる場合は追加を重ねない。
	player.call("_on_combo_started")
	player.call("_on_hit_landed", robber)
	robber.set("_knockback_timer", 0.0)
	melee.set("_combo_node", &"ppp_hook")
	melee.set("_state", "melee_3")
	melee.call("_finish_combo")
	_check(is_zero_approx(float(robber.get("_knockback_timer"))),
		"フィニッシュ終了は追加ノックバックなし")

	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(_failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	_failures += 1
	print("FAIL: ", label)
