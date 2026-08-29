extends Area3D
class_name BossTrigger

## 面末尾のボス開始地点。プレイヤーが入ると reached を送る。ボスの実体化は BeltStage が行う。

## 出すボスのシーン。boss_path が指定されていればそちらを優先する。
@export var boss_scene: PackedScene
## 面に置いてあるボス（4面の盾持ちなど、開始時から存在させたい場合）。
@export var boss_path: NodePath
## ボスを出す側。1 = 画面右、-1 = 画面左。
@export_range(-1, 1) var side: int = 1
## true なら、カメラを lock_x に固定してボス戦を始める（アリーナ全体を画面に収める）。
## false なら、通過した時点のカメラ位置で固定する。
@export var use_lock_x: bool = false
@export var lock_x: float = 0.0

signal reached(trigger: BossTrigger)

var _triggered: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _triggered or not body.is_in_group(&"player"):
		return
	_triggered = true
	reached.emit(self)


## 面に置いてあるボスを返す。無ければ null（BeltStage が boss_scene から出す）。
func placed_boss() -> Node3D:
	if boss_path.is_empty():
		return null
	return get_node_or_null(boss_path) as Node3D
