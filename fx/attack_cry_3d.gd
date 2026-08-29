extends Node3D
class_name AttackCry3D

## 攻撃したときに、主人公の頭の上へ擬音を出す表示部品。
## 銃「ぱん」、日本刀「ぶん」、素手「ふっ」、ドロップキック「でやあ」。
##
## 既存の部品が出しているシグナル（`PlayerWeapon.fired` / `PlayerKatanaCombo.stage_started` /
## `PlayerMelee.stage_started` / `PlayerAction.special_used`）を購読するだけで、
## 戦闘の処理には触らない（`player_sfx.gd` と同じ形）。

## headless 検証用。出した文字と、その位置を通知する。
signal cry_shown(text: String, position: Vector3)

@export_group("Text")
## 銃を撃ったとき。
@export var gun_text: String = "ぱん"
## 日本刀を振ったとき。
@export var katana_text: String = "ぶん"
## 素手で殴ったとき。
@export var unarmed_text: String = "ふっ"
## ドロップキック（△必殺）を出したとき。
@export var dropkick_text: String = "でやあ"
@export var font: Font = preload("res://assets/fonts/ShipporiMinchoB1-ExtraBold.ttf")
@export var font_size: int = 64
@export var outline_size: int = 12
@export var color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var outline_color: Color = Color(0.05, 0.05, 0.08, 1.0)

@export_group("Placement")
## 頭のてっぺんの高さ（m）。ここを起点にする。
@export var head_height: float = 1.62
## 頭ひとつぶんの大きさ（m）。前へ出す距離をこの倍数で持つ。
@export var head_size: float = 0.23
## 向いている方向へ何個ぶん出すか。
@export var forward_heads: float = 2.0
## 上へ何個ぶん出すか。
@export var up_heads: float = 0.6

@export_group("Motion")
## 出てから消えるまでの秒数。
@export var lifetime: float = 0.55
## その間に上へ動く距離（m）。
@export var rise: float = 0.35
## 出た瞬間の拡大率。1.0 へ戻りながら落ち着く。
@export var pop_scale: float = 1.35

@export_group("Nodes")
@export var body_path: NodePath = ^".."
@export var melee_path: NodePath = ^"../PlayerMelee"
@export var katana_combo_path: NodePath = ^"../PlayerKatanaCombo"
@export var weapon_path: NodePath = ^"../PlayerWeapon"
@export var action_path: NodePath = ^"../PlayerAction"
@export_group("")

var _body: Node3D = null


func _ready() -> void:
	_body = get_node_or_null(body_path) as Node3D
	var melee := get_node_or_null(melee_path)
	if melee != null and melee.has_signal("stage_started"):
		melee.connect("stage_started", _on_unarmed_stage)
	var katana_combo := get_node_or_null(katana_combo_path)
	if katana_combo != null and katana_combo.has_signal("stage_started"):
		katana_combo.connect("stage_started", _on_katana_stage)
	var weapon := get_node_or_null(weapon_path)
	if weapon != null and weapon.has_signal("fired"):
		weapon.connect("fired", _on_fired)
	var action := get_node_or_null(action_path)
	if action != null and action.has_signal("special_used"):
		action.connect("special_used", _on_special_used)


func _on_unarmed_stage(_technique: StringName, _stage: int) -> void:
	show_cry(unarmed_text)


func _on_katana_stage(_stage: int) -> void:
	show_cry(katana_text)


func _on_fired() -> void:
	show_cry(gun_text)


func _on_special_used() -> void:
	show_cry(dropkick_text)


## 擬音を1つ出す。位置は頭のてっぺんから、向いている方向へ頭ふたつぶん。
func show_cry(text: String) -> void:
	if text.is_empty() or _body == null:
		return
	var anchor := Node3D.new()
	anchor.top_level = true
	add_child(anchor)
	anchor.global_position = _cry_position()
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font = font
	label.font_size = font_size
	label.outline_size = outline_size
	label.modulate = color
	label.outline_modulate = outline_color
	anchor.add_child(label)
	anchor.scale = Vector3.ONE * pop_scale
	_animate_and_release(anchor, label)
	cry_shown.emit(text, anchor.global_position)


## 出す位置。前方は本体の向き（facing）で決める。
func _cry_position() -> Vector3:
	var facing: float = 1.0
	if _body.has_method("facing"):
		facing = float(_body.call("facing"))
	return _body.global_position \
		+ Vector3.UP * (head_height + head_size * up_heads) \
		+ Vector3.RIGHT * (facing * head_size * forward_heads)


func _animate_and_release(anchor: Node3D, label: Label3D) -> void:
	var span: float = maxf(lifetime, 0.01)
	var tween := anchor.create_tween().set_parallel(true)
	tween.tween_property(anchor, "global_position",
		anchor.global_position + Vector3.UP * rise, span)
	tween.tween_property(anchor, "scale", Vector3.ONE, span * 0.35)
	var faded := color
	faded.a = 0.0
	tween.tween_property(label, "modulate", faded, span)
	var faded_outline := outline_color
	faded_outline.a = 0.0
	tween.tween_property(label, "outline_modulate", faded_outline, span)
	tween.chain().tween_callback(anchor.queue_free)
