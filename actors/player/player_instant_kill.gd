extends Node
class_name PlayerInstantKill

## 一撃即死。日本刀と銃（ヘッドショット）が当たるたびに確率で判定し、
## 成立したらその場で倒す。ボスには効かない。4面でも起きない。
##
## 銃は射線が水平固定で、敵の当たり判定も体ひとつなので、頭を狙う操作は無い。
## ヘッドショットは当たりどころの当たり外れとして確率で表す。
##
## 命中の通知は KatanaHitbox と PlayerWeapon が既に出しているものを購読するだけで、
## ダメージ計算や当たり判定には触らない（player_score.gd と同じ形）。

## 一撃即死が成立した。演出をつなぐときに使う。
signal instant_killed(target: Node3D)

## 刀の1発ごとに一撃即死が起きる確率。
@export_range(0.0, 1.0, 0.01) var katana_chance: float = 0.15
## 銃の1発ごとにヘッドショットになる確率。連射が速いぶん刀より低くする。
@export_range(0.0, 1.0, 0.01) var gun_chance: float = 0.10
## この面では起きない。
@export var excluded_stage: int = GameTypes.Stage.STAGE_4

@export_group("Nodes")
## 日本刀の判定。
@export var katana_hitbox_path: NodePath = ^"../Model/KatanaHitbox"
## 銃の命中通知。
@export var weapon_path: NodePath = ^"../PlayerWeapon"
@export_group("")


func _ready() -> void:
	var katana_hitbox := get_node_or_null(katana_hitbox_path) as Hitbox
	if katana_hitbox != null:
		katana_hitbox.hit_landed.connect(_on_katana_hit)
	var weapon := get_node_or_null(weapon_path)
	if weapon != null and weapon.has_signal("shot_hit"):
		weapon.connect("shot_hit", _on_shot_hit)


func _on_katana_hit(target: Node3D) -> void:
	_roll(target, katana_chance)


func _on_shot_hit(target: Node3D) -> void:
	_roll(target, gun_chance)


func _roll(target: Node3D, chance: float) -> void:
	if not can_instant_kill(target):
		return
	if randf() >= chance:
		return
	_kill(target)


## ボスと除外面を弾く。
func can_instant_kill(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if RunState.current_stage == excluded_stage:
		return false
	if target.has_method("is_boss") and bool(target.call("is_boss")):
		return false
	return true


## 残り HP ぶんのダメージを致死として通す。撃破の加点と死亡演出は通常の経路に乗る。
func _kill(target: Node3D) -> void:
	var health := target.get_node_or_null(^"Health") as Health
	if health == null or health.is_downed():
		return
	health.take_hit(health.current_hp(), true, true)
	instant_killed.emit(target)
