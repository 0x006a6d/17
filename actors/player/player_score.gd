extends Node
class_name PlayerScore

## 得点の集計（HUD 右上と結果画面で使う）。加点の条件はここ1か所に集め、
## 実際の保持は `RunState`（唯一のグローバル可変状態）が行う。
##
## 配点の考え：素手が一番高く、日本刀・銃の順に下げる。段数を基礎点に掛けるので、
## コンボが繋がるほど1発の価値が上がる。死亡すると減点する。
##
## 命中の通知はそれぞれの部品が既に出しているものを購読するだけで、
## ダメージ計算や当たり判定には触らない。

@export_group("Nodes")
## 素手コンボの判定。
@export var melee_hitbox_path: NodePath = ^"../Model/MeleeHitbox"
## 日本刀の判定。
@export var katana_hitbox_path: NodePath = ^"../Model/KatanaHitbox"
## 素手コンボの段数を知るため。
@export var melee_path: NodePath = ^"../PlayerMelee"
## 日本刀コンボの段数を知るため。
@export var katana_combo_path: NodePath = ^"../PlayerKatanaCombo"
## 銃の命中通知。
@export var weapon_path: NodePath = ^"../PlayerWeapon"
## 死亡の減点。
@export var health_path: NodePath = ^"../Health"
@export_group("")

var _katana_combo: Node = null
## 直近に始まった素手コンボの段（1始まり）。stage_started を数える。
var _unarmed_stage: int = 1


func _ready() -> void:
	var melee_hitbox := get_node_or_null(melee_hitbox_path) as Hitbox
	if melee_hitbox != null:
		melee_hitbox.hit_landed.connect(_on_unarmed_hit)
	var katana_hitbox := get_node_or_null(katana_hitbox_path) as Hitbox
	if katana_hitbox != null:
		katana_hitbox.hit_landed.connect(_on_katana_hit)
	var melee := get_node_or_null(melee_path)
	if melee != null and melee.has_signal("stage_started"):
		melee.connect("stage_started", _on_unarmed_stage_started)
	if melee != null and melee.has_signal("combo_started"):
		melee.connect("combo_started", _on_unarmed_combo_started)
	_katana_combo = get_node_or_null(katana_combo_path)
	var weapon := get_node_or_null(weapon_path)
	if weapon != null and weapon.has_signal("shot_hit"):
		weapon.connect("shot_hit", _on_shot_hit)
	var health := get_node_or_null(health_path) as Health
	if health != null:
		health.downed.connect(_on_downed)


func _on_unarmed_combo_started() -> void:
	_unarmed_stage = 1


func _on_unarmed_stage_started(_technique: StringName, stage: int) -> void:
	_unarmed_stage = maxi(stage, 1)


func _on_unarmed_hit(_target: Node3D) -> void:
	RunState.add_hit_score(GameTypes.ScoreWeapon.UNARMED, _unarmed_stage)


func _on_katana_hit(_target: Node3D) -> void:
	var stage: int = 1
	if _katana_combo != null and _katana_combo.has_method("current_stage"):
		stage = int(_katana_combo.call("current_stage"))
	RunState.add_hit_score(GameTypes.ScoreWeapon.KATANA, stage)


func _on_shot_hit(_target: Node3D) -> void:
	RunState.add_hit_score(GameTypes.ScoreWeapon.GUN)


func _on_downed(_lethal: bool) -> void:
	RunState.apply_death_penalty()


## 検証用。直近の素手コンボの段。
func unarmed_stage() -> int:
	return _unarmed_stage
