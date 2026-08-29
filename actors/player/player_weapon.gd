extends Node
class_name PlayerWeapon

## プレイヤーの武器（銃・日本刀・素手）。装備モデルは WeaponHolder（手ボーン装着）、
## 射撃は HitscanGun（正面 ±X へのヒットスキャン）を使う。
## technical-spec §14.5。敵側も同じ HitscanGun / WeaponHolder を使う（別途）。

enum WeaponKind { NONE, GUN, KATANA }

const PLAYER_GUN_FX := preload("res://actors/player/player_gun_fx.gd")
const PLAYER_KATANA_COMBO := preload("res://actors/player/player_katana_combo.gd")
const PLAYER_WEAPON_GRIP := preload("res://actors/player/player_weapon_grip.gd")

signal ammo_changed(ammo: int, kind: int)
signal weapon_changed(kind: int)
signal dry_fired()
## 撃った弾が当たった（得点の集計に使う）。
signal shot_hit(target: Node3D)
## 1発撃った（効果音に使う）。
signal fired()
signal reload_started()
signal reload_finished()

@export_group("Scenes")
@export var pistol_scene: PackedScene = preload("res://assets/weapons/pistol.glb")
@export var katana_scene: PackedScene = preload("res://assets/weapons/katana.glb")

@export_group("Grip (pistol)")
## 握り部のメッシュ実軸上の点を、握った4本指の第2関節の中心へ合わせた基準値。
@export var pistol_grip_offset: Vector3 = Vector3(0.0141, 0.0885, 0.0089)
## 静止して構えているときの向き。銃身（見た目の上端）が水平になる値。
@export var pistol_grip_rotation: Vector3 = Vector3(0.2, -179.9, 64.5)
## 歩いているときの向き。歩行クリップは銃を下げて持つ姿勢なので、そのままだと
## 銃身が 17.7 度下を向く。ブレンドに合わせてここまで寄せて水平に戻す。
@export var pistol_grip_rotation_walk: Vector3 = Vector3(0.2, -179.9, 82.2)
## 上の2つを混ぜきる速度（m/s）。銃歩行のブレンド（pistol_walk_reference_speed）と揃える。
@export var pistol_grip_blend_speed: float = 2.09
@export var pistol_grip_scale: Vector3 = Vector3(0.12, 0.12, 0.12)
## グリップ上端と下端のメッシュ実軸（モデル座標）。
@export var pistol_grip_axis_start: Vector3 = Vector3(0.0993, -0.1167, 0.0039)
@export var pistol_grip_axis_end: Vector3 = Vector3(0.0410, -0.4347, 0.0000)
## スケール適用前のモデル半径（m）。有効半径は実際の軸別スケールから求める。
@export var pistol_grip_model_radius: float = 0.133333

@export_group("Grip (katana)")
@export var katana_grip_offset: Vector3 = Vector3(0.0737, 0.1084, 0.0351)
@export var katana_grip_rotation: Vector3 = Vector3(10.5, -92.5, 171.1)
@export var katana_grip_scale: Vector3 = Vector3(0.40, 0.40, 0.50)
## 鍔側と柄頭側のメッシュ実軸（モデル座標）。
@export var katana_grip_axis_start: Vector3 = Vector3(0.0015, 0.0028, 0.0799)
@export var katana_grip_axis_end: Vector3 = Vector3(-0.0005, 0.0042, 0.2664)
## スケール適用前のモデル半径（m）。有効半径は実際の軸別スケールから求める。
@export var katana_grip_model_radius: float = 0.038

@export_group("Gun")
## 一発のダメージ。
@export var gun_damage: float = 4500.0
## 射程（m）。
@export var gun_range: float = 22.0
## 連射間隔（秒）。
@export var fire_cooldown: float = 0.28
## 初期弾数。
@export var gun_ammo_max: int = 30
## リロード開始から残弾が満タンへ戻るまでの秒数。
@export var reload_duration: float = 1.3
## 銃口の高さ（本体原点から、m）。武器モデルが取れないときの代替に使う。
@export var muzzle_height: float = 1.05
## 銃口を本体原点から向いている方向へ出す距離（m）。同じく代替用。
@export var muzzle_forward_offset: float = 0.4

@export_group("Nodes")
@export var holder_path: NodePath = ^"../WeaponHolder"
@export var body_path: NodePath = ^".."
@export var animation_driver_path: NodePath = ^"../PlayerMelee"
@export var gun_fx_path: NodePath = ^"../PlayerGunFx"
@export var katana_combo_path: NodePath = ^"../PlayerKatanaCombo"
@export var weapon_grip_path: NodePath = ^"../PlayerWeaponGrip"
@export_group("")

var _holder: WeaponHolder = null
var _body: Node3D = null
var _animation_driver: Node = null
var _gun_fx: PLAYER_GUN_FX = null
var _katana_combo: PLAYER_KATANA_COMBO = null
var _weapon_grip: PLAYER_WEAPON_GRIP = null
var _gun: HitscanGun = null
var _kind: int = WeaponKind.NONE
var _ammo: int = 0
var _ammo_initialized: bool = false
var _cooldown_left: float = 0.0
var _reloading: bool = false
var _reload_left: float = 0.0
## 銃口をモデルのローカル座標で覚えておく。頂点を総なめするので測り直しは最小限にする。
var _muzzle_local: Vector3 = Vector3.ZERO
var _muzzle_weapon: Node3D = null
var _muzzle_facing: int = 0


func _ready() -> void:
	_holder = get_node_or_null(holder_path) as WeaponHolder
	_body = get_node_or_null(body_path) as Node3D
	_animation_driver = get_node_or_null(animation_driver_path)
	_gun_fx = get_node_or_null(gun_fx_path) as PLAYER_GUN_FX
	_katana_combo = get_node_or_null(katana_combo_path) as PLAYER_KATANA_COMBO
	_weapon_grip = get_node_or_null(weapon_grip_path) as PLAYER_WEAPON_GRIP
	if _body != null:
		# 刀は素手コンボと干渉しない専用ヒットボックスを使う。
		var katana_hitbox := _body.get_node_or_null(^"Model/KatanaHitbox") as Hitbox
		if katana_hitbox != null:
			katana_hitbox.hit_landed.connect(_on_katana_hit)
	# ヒットスキャン銃（自分から撃つ。射線は毎発 銃口位置へ移す）。
	_gun = HitscanGun.new()
	_gun.damage = gun_damage
	_gun.max_range = gun_range
	_gun.lethal = true
	_gun.ignore_stagger_threshold = true
	_gun.ignore_groups = [&"player"]
	add_child(_gun)
	_gun.shot_fired.connect(_on_shot_fired)
	# 素手から始める。持ち替えは 素手 → 日本刀 → 銃 の順。
	unequip()
	# 兄弟ノードの _ready 順に依存せず、PlayerMelee のツリー構築後にも反映する。
	call_deferred("_set_weapon_locomotion", false, false)


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _reloading:
		_reload_left = maxf(_reload_left - delta, 0.0)
		if _reload_left <= 0.0:
			_finish_reload()
	_update_pistol_grip_rotation()


## 構えと歩行で腕の姿勢が違い、同じ握りの角度だと銃身の向きが変わる。
## 実測で、構えを水平にすると歩行は 17.7 度下を向く。歩行ブレンドと同じ割合で
## 2つの角度を混ぜ、どちらの姿勢でも銃身を水平に保つ。発砲の跳ね上がりは
## 上半身のレイヤーが作るので、この補正では消えない。
func _update_pistol_grip_rotation() -> void:
	if _kind != WeaponKind.GUN or _holder == null or _body == null:
		return
	var speed: float = 0.0
	if _body is CharacterBody3D:
		var velocity: Vector3 = (_body as CharacterBody3D).velocity
		speed = Vector2(velocity.x, velocity.z).length()
	var blend: float = 0.0
	if pistol_grip_blend_speed > 0.0:
		blend = clampf(speed / pistol_grip_blend_speed, 0.0, 1.0)
	_holder.set_grip_rotation(
		pistol_grip_rotation.lerp(pistol_grip_rotation_walk, blend))


func _unhandled_input(event: InputEvent) -> void:
	if _body == null:
		return
	if event.is_action_pressed("fire"):
		_use_weapon()
	elif event.is_action_pressed("reload"):
		_try_reload()
	elif event.is_action_pressed("switch_weapon"):
		_switch_weapon()


## 銃を装備する。
func equip_gun() -> void:
	if _katana_combo != null:
		_katana_combo.cancel()
	_initialize_ammo()
	_kind = WeaponKind.GUN
	if _holder != null:
		_holder.equip(pistol_scene, pistol_grip_offset, pistol_grip_rotation, pistol_grip_scale)
	if _weapon_grip != null:
		var weapon_model: Node3D = _holder.current_weapon() if _holder != null else null
		_weapon_grip.set_grip_geometry(weapon_model, pistol_grip_axis_start,
			pistol_grip_axis_end, pistol_grip_model_radius)
		_weapon_grip.use_pistol_grip()
	_set_weapon_locomotion(true, false)
	weapon_changed.emit(_kind)
	ammo_changed.emit(_ammo, _kind)


## 装備中の武器を使う（銃=射撃 / 刀=斬り / 素手=何もしない）。
func _use_weapon() -> void:
	match _kind:
		WeaponKind.GUN:
			_try_fire()
		WeaponKind.KATANA:
			_try_swing()


## 素手 → 日本刀 → 銃 → 素手の順に持ち替える。
func _switch_weapon() -> void:
	match _kind:
		WeaponKind.NONE:
			equip_katana()
		WeaponKind.KATANA:
			equip_gun()
		WeaponKind.GUN:
			unequip()


## 日本刀を装備する。
func equip_katana() -> void:
	if _katana_combo != null:
		_katana_combo.cancel()
	_cancel_reload()
	_kind = WeaponKind.KATANA
	if _holder != null:
		_holder.equip(katana_scene, katana_grip_offset, katana_grip_rotation, katana_grip_scale)
	if _weapon_grip != null:
		var weapon_model: Node3D = _holder.current_weapon() if _holder != null else null
		_weapon_grip.set_grip_geometry(weapon_model, katana_grip_axis_start,
			katana_grip_axis_end, katana_grip_model_radius)
		_weapon_grip.use_katana_grip()
	_set_weapon_locomotion(false, true)
	weapon_changed.emit(_kind)


## 武器を外す。武器用 locomotion から既存 locomotion へ戻す。
func unequip() -> void:
	if _katana_combo != null:
		_katana_combo.cancel()
	_cancel_reload()
	_kind = WeaponKind.NONE
	if _holder != null:
		_holder.equip(null)
	if _weapon_grip != null:
		_weapon_grip.clear_grip()
	# 外したモデルへの参照を残さない。次に装備したときに測り直させる。
	_muzzle_weapon = null
	_set_weapon_locomotion(false, false)
	weapon_changed.emit(_kind)


## 刀で斬る。段・受付窓・判定は PlayerKatanaCombo が所有する。
func _try_swing() -> void:
	if _cooldown_left <= 0.0 and _katana_combo != null:
		_katana_combo.press()


func _try_fire() -> void:
	if _kind != WeaponKind.GUN or _reloading \
			or (_katana_combo != null and _katana_combo.is_cooling_down()):
		return
	if _ammo <= 0:
		dry_fired.emit()
		return
	if _cooldown_left > 0.0:
		return
	_cooldown_left = fire_cooldown
	_ammo -= 1
	var facing := 1
	if _body.has_method("facing"):
		facing = int(_body.call("facing"))
	# 射線は銃口から正面 ±X へ水平。撃った姿勢のままの銃口位置で決める。
	_update_muzzle_position(facing)
	var muzzle := _gun.global_position
	var target := muzzle + Vector3(float(facing) * gun_range, 0.0, 0.0)
	_gun.fire_at(target)
	fired.emit()
	_play_gun_fire()
	ammo_changed.emit(_ammo, _kind)


## 銃口を武器モデルの実際の先端へ置く。本体からの固定オフセットにすると、腕が動く
## 構え・歩き・発砲で銃口炎と弾道が銃の先から離れる（3面ボスと同じ方式）。
## 武器モデルが取れない場合だけ、従来どおり本体からのオフセットで代替する。
func _update_muzzle_position(facing: int) -> void:
	if _gun == null or _body == null:
		return
	var weapon: Node3D = _holder.current_weapon() if _holder != null else null
	if weapon != null and is_instance_valid(weapon):
		if weapon != _muzzle_weapon or facing != _muzzle_facing:
			_muzzle_local = MuzzleTip.measure_local(weapon,
				Vector3(float(facing), 0.0, 0.0))
			_muzzle_weapon = weapon
			_muzzle_facing = facing
		_gun.global_position = weapon.global_transform * _muzzle_local
		return
	var fallback := _body.global_position + Vector3.UP * muzzle_height
	_gun.global_position = fallback \
		+ Vector3(float(facing) * muzzle_forward_offset, 0.0, 0.0)


## 撃った瞬間の絵。構えは静止しているので、撃つ動きはここでだけ入る。
func _play_gun_fire() -> void:
	if _animation_driver != null and _animation_driver.has_method("play_gun_fire"):
		_animation_driver.call("play_gun_fire")


func _try_reload() -> void:
	if _kind != WeaponKind.GUN or _reloading or _ammo >= gun_ammo_max \
			or gun_ammo_max <= 0:
		return
	_reloading = true
	_reload_left = maxf(reload_duration, 0.0)
	reload_started.emit()
	if _reload_left <= 0.0:
		_finish_reload()


func _finish_reload() -> void:
	if not _reloading:
		return
	_reloading = false
	_reload_left = 0.0
	_ammo = maxi(gun_ammo_max, 0)
	ammo_changed.emit(_ammo, _kind)
	reload_finished.emit()


func _cancel_reload() -> void:
	_reloading = false
	_reload_left = 0.0


func _initialize_ammo() -> void:
	if _ammo_initialized:
		return
	_ammo = maxi(gun_ammo_max, 0)
	_ammo_initialized = true


func _on_shot_fired(from: Vector3, to: Vector3, hit_body: Node3D) -> void:
	if hit_body != null:
		shot_hit.emit(hit_body)
	if _gun_fx == null:
		return
	var facing: int = 1
	if _body != null and _body.has_method("facing"):
		facing = int(_body.call("facing"))
	var weapon_model: Node3D = _holder.current_weapon() if _holder != null else null
	_gun_fx.play_shot(from, to, hit_body, facing, weapon_model)


## 刀のヒット時、プレイヤーの手応え演出（ヒットストップ・シェイク）を起こす。
func _on_katana_hit(target: Node3D) -> void:
	if _body != null and _body.has_method("_on_hit_landed"):
		_body.call("_on_hit_landed", target)


func _set_gun_locomotion(enabled: bool) -> void:
	if _animation_driver != null and _animation_driver.has_method("set_gun_locomotion"):
		_animation_driver.call("set_gun_locomotion", enabled)


func _set_katana_locomotion(enabled: bool) -> void:
	if _animation_driver != null and _animation_driver.has_method("set_katana_locomotion"):
		_animation_driver.call("set_katana_locomotion", enabled)


func _set_weapon_locomotion(gun_enabled: bool, katana_enabled: bool) -> void:
	_set_gun_locomotion(gun_enabled)
	_set_katana_locomotion(katana_enabled)


func ammo() -> int:
	return _ammo


func max_ammo() -> int:
	return maxi(gun_ammo_max, 0)


func is_reloading() -> bool:
	return _reloading


func kind() -> int:
	return _kind
