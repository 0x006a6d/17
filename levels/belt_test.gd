extends Node3D

## 段移動・奥行き判定の確認用ベルトステージ。敵 AI は置かず、ダミーだけを並べる。
## 面の共通部（BeltStage）は 8/24 に作るため、ここでは Player へ直接ベルト幅を渡す。

@export var belt_z_min: float = -1.5
@export var belt_z_max: float = 1.5
@export var player_path: NodePath = ^"Player"


func _ready() -> void:
	var player := get_node_or_null(player_path)
	if player != null and player.has_method("set_belt_bounds"):
		player.call("set_belt_bounds", belt_z_min, belt_z_max)
