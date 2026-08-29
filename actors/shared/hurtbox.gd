extends Area3D
class_name Hurtbox

const DIRECTIONAL_BLOOD_SPRAY_3D := preload(
	"res://fx/directional_blood_spray_3d.gd")

## 被弾判定。technical-spec §2 のとおり layer=7(hurtbox) / mask=6(hitbox)。
## 検出は Hitbox 側が主導する（Hitbox.activate() / area_entered）。
## Hurtbox は本体（owner_body）と Health への橋渡しと、ノックバック方向の算出を担う。
## ノックバック方向は「攻撃者 → 被弾側」の水平ベクトルで算出し、被弾側へ渡す。

## この Hurtbox を持つ本体（Health / ノックバック受け手）。
@export var owner_body_path: NodePath = ^".."
## Health ノード（未指定なら owner_body から探索）。
@export var health_path: NodePath = ^""

var _owner_body: Node3D = null
var _health: Health = null
var _last_melee_impact_position: Vector3 = Vector3.ZERO
var _blood_spray: DIRECTIONAL_BLOOD_SPRAY_3D = null

## HPへ実際に適用されたダメージ。表示側はこの意味イベントだけを購読する。
signal damage_applied(amount: float, impact_position: Vector3)
## レイ実交点へ銃撃専用表示を出すため、近接と分離した実適用ダメージ。
signal shot_damage_applied(amount: float, impact_position: Vector3)
## ダウン後の追い打ちが成立した。HPダメージはないため別イベントにする。
signal finish_hit_applied(impact_position: Vector3)


func _ready() -> void:
	collision_layer = 1 << 6   # layer 7 = hurtbox
	collision_mask = 1 << 5    # mask 6 = hitbox
	monitoring = true
	monitorable = true

	_owner_body = get_node_or_null(owner_body_path) as Node3D
	if not health_path.is_empty():
		_health = get_node_or_null(health_path) as Health
	if _health == null and _owner_body != null:
		_health = _find_health(_owner_body)
	if _owner_body != null and _owner_body.is_in_group(&"enemy"):
		_blood_spray = DIRECTIONAL_BLOOD_SPRAY_3D.new()
		_blood_spray.name = &"DirectionalBloodSpray3D"
		add_child(_blood_spray)


func owner_body() -> Node3D:
	return _owner_body


func last_melee_impact_position() -> Vector3:
	return _last_melee_impact_position


## Hitbox から呼ばれる。payload を本体の Health / ノックバックへ伝える。
## 被弾処理が実際に通った場合だけ true を返す。
func receive_hit(hitbox: Hitbox) -> bool:
	var attacker := hitbox.source_body()
	_last_melee_impact_position = _melee_impact_position(hitbox)
	if _health != null and _health.is_downed():
		# 追い打ちはロックオン対象本人を exempt_body に指定した攻撃だけ通す。
		# 通常ダメージとノックバックは与えず、残りコンボや範囲攻撃では成立しない。
		if _owner_body != null and hitbox.exempt_body == _owner_body:
			_notify_attacker(attacker)
			if _owner_body.has_method("flash_hit"):
				_owner_body.call("flash_hit")
			if _health.take_finish_hit(attacker):
				finish_hit_applied.emit(_last_melee_impact_position)
				return true
			return false
		return false
	_notify_attacker(attacker)
	var dir := _knockback_direction(attacker)
	if _owner_body != null and _owner_body.has_method("receive_knockback"):
		_owner_body.call("receive_knockback", dir, hitbox.knockback)
	if _owner_body != null and _owner_body.has_method("flash_hit"):
		_owner_body.call("flash_hit")
	if _health != null:
		var hp_before: float = _health.current_hp()
		_health.take_hit(hitbox.damage, hitbox.lethal)
		_emit_applied_damage(hp_before, _last_melee_impact_position, false,
			hitbox.impact_flow_direction(),
			hitbox.impact_kind == Hitbox.ImpactKind.SLASH)
	return true


## PlayerAction が選んだ範囲攻撃を、近接と同じ被弾・表示経路へ流す。
## 対象選択は呼び出し側が済ませ、ここでは実適用、ノックバック、意味イベントだけを担う。
func receive_area_hit(attacker: Node3D, damage: float, knockback: float,
		knockback_origin: Vector3, lethal: bool = true,
		ignore_stagger_threshold: bool = true) -> bool:
	if _health == null or _health.is_downed():
		return false
	_last_melee_impact_position = _hurt_center()
	_notify_attacker(attacker)
	if _owner_body != null and _owner_body.has_method("receive_knockback"):
		var direction: Vector3 = _owner_body.global_position - knockback_origin
		direction.y = 0.0
		if not direction.is_zero_approx():
			direction = direction.normalized()
		_owner_body.call("receive_knockback", direction, knockback)
	if _owner_body != null and _owner_body.has_method("flash_hit"):
		_owner_body.call("flash_hit")
	var hp_before: float = _health.current_hp()
	_health.take_hit(damage, lethal, ignore_stagger_threshold)
	_emit_applied_damage(hp_before, _last_melee_impact_position)
	return _health.current_hp() < hp_before


## ヒットスキャン銃から呼ばれる。近接と同じ方向計算と被弾フラッシュを使うが、
## 銃撃のノックバック強度は 0 とする。
##
## Hitbox.ignore_groups は近接の広い判定による誤爆を防ぐ仕組みであり、ここでは
## 適用しない。銃弾は不安定型が客を撃つ場合も、リーダーが客を盾にする場合も
## 客へ届く必要があるため、狙った射線の最初の Hurtbox にそのまま通す。
func receive_shot(shooter: Node3D, damage: float, lethal: bool,
		ignore_stagger_threshold: bool,
		impact_position: Vector3 = Vector3(INF, INF, INF),
		shot_flow_direction: Vector3 = Vector3.ZERO) -> void:
	_notify_attacker(shooter)
	var dir := _knockback_direction(shooter)
	if _owner_body != null and _owner_body.has_method("receive_knockback"):
		_owner_body.call("receive_knockback", dir, 0.0)
	if _owner_body != null and _owner_body.has_method("flash_hit"):
		_owner_body.call("flash_hit")
	if _health != null:
		var hp_before: float = _health.current_hp()
		_health.take_hit(damage, lethal, ignore_stagger_threshold)
		var position: Vector3 = global_position if not impact_position.is_finite() \
			else impact_position
		var flow := shot_flow_direction
		if flow.is_zero_approx() and shooter != null:
			flow = position - shooter.global_position
		_emit_applied_damage(hp_before, position, true, flow, true)


func _emit_applied_damage(hp_before: float, impact_position: Vector3,
		was_shot: bool = false, flow_direction: Vector3 = Vector3.ZERO,
		spawn_blood: bool = false) -> void:
	if _health == null:
		return
	var applied: float = maxf(hp_before - _health.current_hp(), 0.0)
	if applied > 0.0:
		if was_shot:
			shot_damage_applied.emit(applied, impact_position)
		else:
			damage_applied.emit(applied, impact_position)
		if spawn_blood and _blood_spray != null:
			if was_shot:
				_blood_spray.play_shot(impact_position, flow_direction)
			else:
				_blood_spray.play_slash(impact_position, flow_direction)


func _melee_impact_position(hitbox: Hitbox) -> Vector3:
	var hurt_center := _hurt_center()
	if hitbox == null:
		return hurt_center
	return hurt_center.lerp(hitbox.global_position, 0.5)


func _hurt_center() -> Vector3:
	var hurt_center := global_position
	for child: Node in get_children():
		var collision_shape := child as CollisionShape3D
		if collision_shape != null and collision_shape.shape != null:
			hurt_center = collision_shape.global_position
			break
	return hurt_center


## 本体だけが最後の加害者を保持する。Hurtbox は具体的な役割型へ依存しない。
func _notify_attacker(attacker: Node3D) -> void:
	if _owner_body != null and _owner_body.has_method("record_attacker"):
		_owner_body.call("record_attacker", attacker)


## 攻撃者から被弾側への水平方向（ノックバックの向き）。
func _knockback_direction(attacker: Node3D) -> Vector3:
	if attacker == null or _owner_body == null:
		return Vector3.ZERO
	var d := _owner_body.global_position - attacker.global_position
	d.y = 0.0
	if d.length() < 0.001:
		return -attacker.global_transform.basis.z.normalized()
	return d.normalized()


func _find_health(node: Node) -> Health:
	for c in node.get_children():
		if c is Health:
			return c as Health
	return null
