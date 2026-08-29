extends Node

## 4面ボスが盾を放したあと、主人公と同じ拳銃を構えて撃つところを撮る QC 用。
## 描画結果が要るので --headless では実行しない。
##   godot --path . --resolution 1280x720 res://tools/capture_stage4_boss_gun.tscn

const STAGE: String = "res://levels/belt_test.tscn"
const BOSS: String = "res://actors/enemy/bosses/stage_4_boss.tscn"
const OUT_DIR: String = "res://docs/img"
const SHOT_FRAMES: Array[int] = [30, 90, 150, 210]

var _stage: Node3D = null
var _boss: Node3D = null
var _shots: int = 0
var _frames: int = 0


func _ready() -> void:
	RunState.reset()
	_stage = (load(STAGE) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	for dummy_name: String in ["Dummy1", "Dummy2", "Dummy3"]:
		var dummy := _stage.get_node_or_null(NodePath(dummy_name)) as Node3D
		if dummy != null:
			dummy.global_position = Vector3(60.0, 0.2, 0.0)
	var player := _stage.get_node_or_null(^"Player") as Node3D
	if player != null:
		player.global_position = Vector3(4.0, 0.2, 0.0)
	_boss = (load(BOSS) as PackedScene).instantiate() as Node3D
	# 人質の居ない検証ステージなので、盾を放した状態で出す。
	_boss.set("grab_on_ready", false)
	_stage.add_child(_boss)
	_boss.global_position = Vector3(9.0, 0.2, 0.0)
	_boss.call("set_belt_bounds", -1.5, 1.5)
	var gun := _boss.get_node_or_null(^"HitscanGun") as HitscanGun
	if gun != null:
		gun.shot_fired.connect(func(_f: Vector3, _t: Vector3, hit: Node3D) -> void:
			_shots += 1
			print("[s4gun] shot %d hit=%s frame=%d" % [_shots,
				hit.name if hit != null else "-", _frames]))


func _physics_process(_delta: float) -> void:
	_frames += 1
	if SHOT_FRAMES.has(_frames):
		var img := get_viewport().get_texture().get_image()
		var path := "%s/qc_stage4_boss_gun_%03d.png" % [OUT_DIR, _frames]
		print("[s4gun] %s (%s) state=%d shots=%d" % [path,
			error_string(img.save_png(path)), int(_boss.call("current_state")), _shots])
	if _frames > SHOT_FRAMES[SHOT_FRAMES.size() - 1]:
		get_tree().quit()
