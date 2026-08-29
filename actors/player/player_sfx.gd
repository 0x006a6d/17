extends Node
class_name PlayerSfx

## プレイヤー側の効果音の呼び出しを1か所に集める。既存の部品が出しているシグナルを
## 購読するだけで、戦闘の処理そのものには触らない。実際の再生は `Sfx` autoload。
##
## 素手は技によって鳴らす音を変える。どの技が出ているかは PlayerMelee の
## `stage_started` で受け取り、鳴らすのは実際に当たった瞬間（`Hitbox.hit_landed`）にする。
## フック・ハイはコンボの締めなので別の音を当て、パンチ・キックもそれぞれ分ける。
##
## `hit_landed` は当たった相手ごとに出る。複数体を巻き込んだときに同じ波形が同じ
## フレームへ重なると音量が跳ねて濁るので、1フレームにつき1回だけ鳴らす。

const ComboTree := preload("res://actors/player/combo_tree.gd")

@export_group("Nodes")
@export var melee_hitbox_path: NodePath = ^"../Model/MeleeHitbox"
@export var melee_path: NodePath = ^"../PlayerMelee"
@export var katana_combo_path: NodePath = ^"../PlayerKatanaCombo"
@export var weapon_path: NodePath = ^"../PlayerWeapon"
@export_group("Sounds")
@export var punch_sound: StringName = &"hit_punch"
@export var kick_sound: StringName = &"hit_kick"
@export var finish_sound: StringName = &"hit_finish"
@export var katana_sound: StringName = &"katana_slash"
@export var gun_sound: StringName = &"gun_shot"
@export var dry_sound: StringName = &"gun_dry"
@export var reload_sound: StringName = &"gun_reload"
@export_group("Volume")
@export var punch_volume_db: float = 0.0
@export var kick_volume_db: float = 0.0
## 締めの技は他より一段大きく鳴らす。素材そのものの実効値が約1dB低いぶんも含む。
@export var finish_volume_db: float = 2.0
@export_group("")

## 直前に始まった素手の技。命中時にどの音を鳴らすかの決め手にする。
var _technique: StringName = ComboTree.TECHNIQUE_JAB
## 素手の命中音を鳴らした物理フレーム。同フレームの重複再生を避けるために持つ。
var _last_hit_frame: int = -1


func _ready() -> void:
	var melee_hitbox := get_node_or_null(melee_hitbox_path) as Hitbox
	if melee_hitbox != null:
		melee_hitbox.hit_landed.connect(_on_punch_hit)
	var melee := get_node_or_null(melee_path)
	if melee != null and melee.has_signal("stage_started"):
		melee.connect("stage_started", _on_melee_stage)
	var katana_combo := get_node_or_null(katana_combo_path)
	if katana_combo != null and katana_combo.has_signal("stage_started"):
		katana_combo.connect("stage_started", _on_katana_stage)
	var weapon := get_node_or_null(weapon_path)
	if weapon == null:
		return
	if weapon.has_signal("fired"):
		weapon.connect("fired", _on_fired)
	if weapon.has_signal("dry_fired"):
		weapon.connect("dry_fired", _on_dry_fired)
	if weapon.has_signal("reload_started"):
		weapon.connect("reload_started", _on_reload_started)


func _on_melee_stage(technique: StringName, _stage: int) -> void:
	_technique = technique


func _on_punch_hit(_target: Node3D) -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _last_hit_frame:
		return
	_last_hit_frame = frame
	Sfx.play(_sound_for(_technique), _volume_for(_technique))


## 技に対応する命中音。締め（フック・ハイ）→ キック → それ以外はパンチ、の順に見る。
func _sound_for(technique: StringName) -> StringName:
	match technique:
		ComboTree.TECHNIQUE_HOOK, ComboTree.TECHNIQUE_HIGH:
			return finish_sound
		ComboTree.TECHNIQUE_KNEE, ComboTree.TECHNIQUE_MIDDLE:
			return kick_sound
		_:
			return punch_sound


func _volume_for(technique: StringName) -> float:
	match technique:
		ComboTree.TECHNIQUE_HOOK, ComboTree.TECHNIQUE_HIGH:
			return finish_volume_db
		ComboTree.TECHNIQUE_KNEE, ComboTree.TECHNIQUE_MIDDLE:
			return kick_volume_db
		_:
			return punch_volume_db


func _on_katana_stage(_stage: int) -> void:
	Sfx.play(katana_sound)


func _on_fired() -> void:
	Sfx.play(gun_sound)


func _on_dry_fired() -> void:
	Sfx.play(dry_sound)


func _on_reload_started() -> void:
	Sfx.play(reload_sound)
