extends Node3D

## 3面ボス GUNNER だけを出して実際に遊ぶための確認用ステージ。
##   godot --path . tools/play_gun_boss.tscn
##
## 面を頭から進めずにボス戦だけを見たいときに使う。ベルトの土台は `belt_test` を
## 借り、置いてあるダミーは消して、ボスを1体だけ前方に置く。得点・残機は
## `RunState` を初期化して素の状態から始める。
##
## 検証ツール（`tools/test_*.tscn` / `capture_*.tscn`）とは違い、これは人が遊ぶための
## もの。撃たれる・撃ち返される様子を目と耳で確かめる。

const STAGE_PATH: String = "res://levels/belt_test.tscn"
const BOSS_PATH: String = "res://actors/enemy/bosses/stage_3_boss.tscn"
## `belt_test` が置いているダミー。ボスだけを見たいので消す。
const DUMMY_NAMES: Array[String] = ["Dummy1", "Dummy2", "Dummy3"]
## ボスの初期位置。撃たれる距離（gun_preferred_distance 4.5）より少し離す。
const BOSS_POSITION := Vector3(6.5, 0.2, 0.0)
## ベルトの奥行き。`belt_test` の既定と揃える。
const BELT_Z_MIN: float = -1.5
const BELT_Z_MAX: float = 1.5


func _ready() -> void:
	RunState.reset()
	var stage := (load(STAGE_PATH) as PackedScene).instantiate()
	add_child(stage)

	for dummy_name: String in DUMMY_NAMES:
		var dummy := stage.get_node_or_null(dummy_name)
		if dummy != null:
			dummy.queue_free()

	var boss := (load(BOSS_PATH) as PackedScene).instantiate() as Node3D
	stage.add_child(boss)
	boss.position = BOSS_POSITION
	if boss.has_method("set_belt_bounds"):
		boss.call("set_belt_bounds", BELT_Z_MIN, BELT_Z_MAX)
	if boss.has_signal("defeated"):
		boss.connect("defeated", _on_boss_defeated)
	print("[play] 3面ボス GUNNER のみを配置した。位置 %v" % BOSS_POSITION)


func _on_boss_defeated(_enemy: Node3D) -> void:
	print("[play] ボスを倒した")
