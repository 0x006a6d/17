extends Bruiser
class_name GunBoss

## 3面ボス。Enemy の共通 StateMachine に射撃距離を保つ役割ステートだけを追加する。
## 射撃判定と味方除外は共有 HitscanGun に任せ、AI は移動と発射タイミングだけを所有する。

const GUN_COMBAT: int = State.DOWNED + 1
const MIN_PHYSICS_DELTA: float = 0.000001

@export_group("Gun combat")
## ライフルの一発。5発のバーストで 25000 になり、プレイヤー（HP 30000）は瀕死になる。
## 拳銃（4500）より1発が重く、続けて撃つぶんさらに重い。
@export var gun_damage: float = 5000.0
@export var gun_range: float = 18.0
@export var gun_fire_interval: float = 1.2
## 1回の射撃で撃つ発数。自動小銃なので続けて撃つ。
@export var burst_count: int = 5
## バーストの発砲間隔（秒）。録音の実測（0.18秒）に合わせてある。
@export var burst_interval: float = 0.18
@export var gun_preferred_distance: float = 6.0
@export var gun_retreat_distance: float = 3.5
@export var gun_depth_tolerance: float = 0.45
## 正面との内積がこの値以上になってから撃つ。
@export_range(-1.0, 1.0) var gun_aim_alignment: float = 0.95
## 狙う高さ（相手のどこを撃つか）。銃口の位置とは別物。
@export var gun_muzzle_height: float = 1.05
## 銃口の代替位置（本体からの前方距離）。武器モデルを持たない個体でだけ使う。
@export var gun_muzzle_forward_offset: float = 0.4
## 発砲モーションを差し込む秒数。この間は移動のクリップに戻らない。
## gun_fire_interval より短くしないと、撃ち続けている間ずっと発砲の絵で埋まる。
@export var fire_reaction_duration: float = 0.4
@export_group("Gun nodes")
@export var gun_path: NodePath = ^"HitscanGun"
## 銃口炎・弾道・薬莢・反動の表示。敵専用（銃口炎を弾の向きへ合わせる）。
@export var gun_fx_path: NodePath = ^"GunFx"
## 反動で銃を弾かせるための装備参照。
@export var loadout_path: NodePath = ^"WeaponLoadout"
@export_group("Gun sound")
## 発砲音。プレイヤーの銃と同じ音を使う。
@export var fire_sound: StringName = &"gun_shot"
@export_group("")

var _gun: HitscanGun = null
## バーストの残り発数と、次の1発までの秒数。
var _burst_left: int = 0
var _burst_timer: float = 0.0
## バースト全弾の狙い点。1発目を撃つときに決め、残りもここへ撃つ。
var _burst_target: Vector3 = Vector3.ZERO
var _gun_fx: EnemyGunFx = null
var _loadout: WeaponLoadout = null
## 銃口の位置（装備中の武器モデルのローカル座標）。装備のたびに測り直す。
var _muzzle_local: Vector3 = Vector3.ZERO
## _muzzle_local を測った相手。武器が差し替わったら測り直す。
var _muzzle_weapon: Node3D = null


func _ready() -> void:
	super._ready()
	_gun = get_node_or_null(gun_path) as HitscanGun
	_gun_fx = get_node_or_null(gun_fx_path) as EnemyGunFx
	_loadout = get_node_or_null(loadout_path) as WeaponLoadout
	if _gun != null:
		# 表示と音は撃った事実だけを購読する。射撃判定には触らない。
		_gun.shot_fired.connect(_on_shot_fired)
		_gun.damage = gun_damage
		_gun.max_range = gun_range
		_gun.lethal = true
		_gun.ignore_stagger_threshold = true
		_gun.ignore_groups = [&"enemy", &"hostage"]
	if _sm != null:
		_sm.add_state(GUN_COMBAT, &"gun_combat", _enter_gun_combat,
			_physics_gun_combat, _exit_gun_combat)


func _uses_role_locomotion(state: int) -> bool:
	return state == GUN_COMBAT


func _role_approach_override(_delta: float) -> bool:
	if _target == null or _sm == null:
		return false
	_sm.transition_to(GUN_COMBAT)
	return true


func _enter_gun_combat() -> void:
	_close_hitbox()
	_stop_horizontal_immediate()


func _physics_gun_combat(delta: float) -> void:
	_update_burst(delta)
	if _target == null:
		_resolve_target()
		if _target == null:
			_stop_horizontal(delta)
			return
	var dx: float = _target.global_position.x - global_position.x
	var dz: float = _target.global_position.z - global_position.z
	var abs_dx: float = absf(dx)
	var abs_dz: float = absf(dz)
	var safe_delta: float = maxf(delta, MIN_PHYSICS_DELTA)

	if abs_dz > gun_depth_tolerance:
		velocity.z = signf(dz) * minf(depth_align_speed, abs_dz / safe_delta)
	else:
		velocity.z = move_toward(velocity.z, 0.0, stop_decel * delta)

	if abs_dx < gun_retreat_distance:
		velocity.x = -signf(dx) * chase_speed
	elif abs_dx > gun_preferred_distance:
		velocity.x = signf(dx) * chase_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, stop_decel * delta)
	_face_target_x(delta)

	_try_fire(gun_fire_interval)


## 狙えるなら撃つ。撃てたら true。移動には触らないので、GUN_COMBAT 以外の
## ステート（4面ボスが盾を構えたまま撃つ SHIELD など）からも呼べる。
## interval は撃ち終わってから次の射撃までの秒数。
func _try_fire(interval: float) -> bool:
	if _gun == null or _cooldown_left > 0.0 or _target == null \
			or not is_instance_valid(_target):
		return false
	var dx: float = _target.global_position.x - global_position.x
	var dz: float = _target.global_position.z - global_position.z
	if absf(dz) > gun_depth_tolerance or absf(dx) > gun_range:
		return false
	var target_position: Vector3 = _target.global_position
	target_position.y = global_position.y + gun_muzzle_height
	_update_muzzle_position()
	var aim_direction: Vector3 = target_position - _gun.global_position
	aim_direction.y = 0.0
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	if aim_direction.is_zero_approx() or forward.normalized().dot(
			aim_direction.normalized()) < gun_aim_alignment:
		return false
	if not _gun.has_clear_shot(_target, target_position):
		return false
	_gun.fire_at(target_position)
	_burst_target = target_position
	_burst_left = maxi(burst_count, 1) - 1
	_burst_timer = burst_interval
	# 撃ち終わってから次の射撃までを数える。
	_cooldown_left = interval + float(_burst_left) * burst_interval
	_play_fire_reaction()
	return true


## バーストの残りを撃つ。狙いは 1発目を撃ったときの点（_burst_target）で固定する。
## 相手の現在位置を読み直すと、撃っている途中に段を外しても残りが追ってきて、
## 「段をずらせば当たらない」というベルトスクロールの約束が5発中4発で崩れる。
## 銃口は本体と一緒に動くので、射線の向きだけは毎発引き直す。
func _update_burst(delta: float) -> void:
	if _burst_left <= 0 or _gun == null:
		return
	_burst_timer -= delta
	if _burst_timer > 0.0:
		return
	_burst_timer = burst_interval
	_burst_left -= 1
	if _target == null or not is_instance_valid(_target):
		_cancel_burst()
		return
	_update_muzzle_position()
	_gun.fire_at(_burst_target)
	_play_fire_reaction()


## 撃ち残しを捨てる。ステートを抜けるときに呼ぶ。残したまま別のステートへ移ると、
## 戻ってきた瞬間に古い残弾が間隔を無視して出る。
func _cancel_burst() -> void:
	_burst_left = 0
	_burst_timer = 0.0


## 撃ったときの表示と音。HitscanGun.shot_fired から呼ばれる。
## 部品が無い個体（表示を持たないテスト用など）では、その分だけ黙って飛ばす。
func _on_shot_fired(from: Vector3, to: Vector3, hit_body: Node3D) -> void:
	Sfx.play(fire_sound)
	if _gun_fx == null:
		return
	var weapon: Node3D = _loadout.current_weapon() if _loadout != null else null
	_gun_fx.play_shot(from, to, hit_body, _facing_sign(from, to), weapon)


## 銃口炎や薬莢を出す向き（ベルトスクロールなので X の符号だけ）。
func _facing_sign(from: Vector3, to: Vector3) -> int:
	var dx: float = to.x - from.x
	if absf(dx) > 0.001:
		return 1 if dx > 0.0 else -1
	return 1 if -global_transform.basis.z.x > 0.0 else -1


## 撃つ絵を一度だけ差し込む。移動のクリップは毎フレーム drive_locomotion() が
## 指定し直すので、ステートを変えずに割り込める play_one_shot() を使う。
## 発砲クリップを持たない個体（素材未設定）では何もしない。
func _play_fire_reaction() -> void:
	if _animator == null or not _animator.is_active():
		return
	if not _animator.has_clip(NpcAnimator.Clip.FIRE):
		return
	_animator.play_one_shot(NpcAnimator.Clip.FIRE,
		minf(fire_reaction_duration, gun_fire_interval))


func _exit_gun_combat() -> void:
	_cancel_burst()
	_stop_horizontal_immediate()


## 銃口を武器モデルの実際の先端へ置く。銃口炎も弾道もここから出るので、本体からの
## 固定オフセットにすると、腕が動く発砲・歩き・走りで絵と離れる。
## 武器モデルが無い個体では、従来どおり本体からのオフセットで代替する。
func _update_muzzle_position() -> void:
	if _gun == null:
		return
	var weapon: Node3D = _loadout.current_weapon() if _loadout != null else null
	if weapon != null and is_instance_valid(weapon):
		if weapon != _muzzle_weapon:
			_muzzle_local = _measure_muzzle_local(weapon)
			_muzzle_weapon = weapon
		_gun.global_position = weapon.global_transform * _muzzle_local
		return
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	_gun.global_position = global_position + Vector3.UP * gun_muzzle_height \
		+ forward * gun_muzzle_forward_offset


## 武器モデルの銃口をローカル座標で求める。測り方は MuzzleTip（プレイヤーと共通）。
func _measure_muzzle_local(weapon: Node3D) -> Vector3:
	return MuzzleTip.measure_local(weapon, -global_transform.basis.z)
