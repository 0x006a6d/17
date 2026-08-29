class_name DamageFeedback3D
extends Node3D

## Hurtbox と Health の意味イベントを、世界空間の数字へ変換する表示部品。
## 被弾は黄、回復は水色で出す。回復は毎フレーム入るので、一定間隔ぶんを溜めて1つにまとめる。

@export var hurtbox_path: NodePath = ^"../Hurtbox"
@export var health_path: NodePath = ^"../Health"

@export_group("Damage Number")
@export var damage_color: Color = Color(1.0, 0.88, 0.35, 1.0)
@export var number_lifetime: float = 0.70
@export var number_rise: float = 0.65
@export var number_font_size: int = 42
@export var number_outline_size: int = 8
@export var random_offset_radius: float = 0.18

@export_group("Heal Number")
## 回復の数字の色（水色）。
@export var heal_color: Color = Color(0.42, 0.84, 1.0, 1.0)
## 回復を溜めてから1つ出すまでの間隔（秒）。踊り回復は毎フレーム入るのでまとめる。
@export var heal_number_interval: float = 0.35
## 回復の数字を出す高さ（本体からの相対、m）。
@export var heal_number_height: float = 1.35
@export_group("")

var _hurtbox: Hurtbox = null
var _health: Health = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## 溜めている回復量と、その経過秒。
var _heal_pending: float = 0.0
var _heal_elapsed: float = 0.0

## headless検証用。表示要求を受け、生成処理へ渡した値を通知する。
signal feedback_spawned(amount: float, impact_position: Vector3)
## headless検証用。回復の数字を出したときに通知する。
signal heal_spawned(amount: float)


func _ready() -> void:
	_rng.randomize()
	_health = get_node_or_null(health_path) as Health
	if _health != null:
		_health.healed.connect(_on_healed)
	_hurtbox = get_node_or_null(hurtbox_path) as Hurtbox
	if _hurtbox == null:
		push_warning("damage_feedback_3d: Hurtbox が無い")
		return
	_hurtbox.damage_applied.connect(_on_damage_applied)
	_hurtbox.shot_damage_applied.connect(_on_shot_damage_applied)
	_hurtbox.finish_hit_applied.connect(_on_finish_hit_applied)


func _process(delta: float) -> void:
	if _heal_pending <= 0.0:
		return
	_heal_elapsed += delta
	if _heal_elapsed < heal_number_interval:
		return
	_flush_heal()


func _on_healed(amount: float) -> void:
	if amount <= 0.0:
		return
	_heal_pending += amount


## 溜めた回復量を1つの数字にして出す。
func _flush_heal() -> void:
	var amount: float = _heal_pending
	_heal_pending = 0.0
	_heal_elapsed = 0.0
	if amount <= 0.0:
		return
	var anchor := Node3D.new()
	anchor.top_level = true
	add_child(anchor)
	anchor.global_position = global_position + Vector3.UP * heal_number_height \
		+ _random_offset()
	var label := _spawn_number(anchor, amount, heal_color)
	_animate_and_release(anchor, label, heal_color)
	heal_spawned.emit(amount)


func _on_damage_applied(amount: float, impact_position: Vector3) -> void:
	_spawn_feedback(amount, impact_position)


func _on_shot_damage_applied(amount: float, impact_position: Vector3) -> void:
	_spawn_feedback(amount, impact_position)


func _on_finish_hit_applied(impact_position: Vector3) -> void:
	# フィニッシュ固有の見た目は攻撃側VFXが担当する。旧スパークは出さない。
	feedback_spawned.emit(0.0, impact_position)


func _spawn_feedback(amount: float, impact_position: Vector3) -> void:
	if amount <= 0.0:
		feedback_spawned.emit(amount, impact_position)
		return
	var anchor := Node3D.new()
	anchor.top_level = true
	add_child(anchor)
	anchor.global_position = impact_position + _random_offset()
	var label := _spawn_number(anchor, amount, damage_color)
	_animate_and_release(anchor, label, damage_color)
	feedback_spawned.emit(amount, impact_position)


func _spawn_number(anchor: Node3D, amount: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = _format_damage(amount)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = number_font_size
	label.outline_size = number_outline_size
	label.modulate = color
	anchor.add_child(label)
	return label


func _animate_and_release(anchor: Node3D, label: Label3D, color: Color) -> void:
	var lifetime: float = maxf(number_lifetime, 0.01)
	var tween := anchor.create_tween().set_parallel(true)
	tween.tween_property(anchor, "global_position",
		anchor.global_position + Vector3.UP * number_rise, lifetime)
	if label != null:
		var faded := color
		faded.a = 0.0
		tween.tween_property(label, "modulate", faded, lifetime)
	tween.chain().tween_callback(anchor.queue_free)


func _random_offset() -> Vector3:
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(0.0, random_offset_radius)
	return Vector3(cos(angle) * radius, _rng.randf_range(0.0, radius), sin(angle) * radius)


## 数字は常に整数で出す（小数点は出さない）。端数は `DamageRoll` が作る。
func _format_damage(amount: float) -> String:
	return str(int(roundf(amount)))
