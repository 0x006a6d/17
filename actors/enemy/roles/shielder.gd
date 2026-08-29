extends GunBoss
class_name Shielder

## 4面ボス。人質（Hostage）を正面に保持し、正面扇形からの近接を弾く（technical-spec §8.3）。
## 旧 leader.gd の SHIELD をそのまま使い、対象を客から Hostage に変えただけ。
## 側面・背面から shield_break_hits 回当てると放し、regrab_cooldown 後にまた掴みに行く。
##
## 盾を構えている間も、その場から動かずに shield_fire_interval 間隔で撃つ（牽制）。正面は
## 盾で弾かれるので、プレイヤーは撃たれながら側面へ回り込むことになる。
## 盾を放している間は GunBoss の射撃（主人公と同じ拳銃）で距離を取って戦う。掴み直せる
## ようになったら GUN_COMBAT を抜けて APPROACH へ戻り、人質へ寄る。

## GunBoss が GUN_COMBAT に使う DOWNED+1 の、さらに次を使う。
const SHIELD: int = GunBoss.GUN_COMBAT + 1

@export_group("Shield")
## 面の開始時点で人質を保持した状態で出す（接近して掴む手順を踏まない）。
@export var grab_on_ready: bool = true
## 人質へ接近し、掴んだとみなす水平距離（m）。
@export var grab_range: float = 1.2
## 保持中に人質を置く、自分の正面方向の距離（m）。
@export var shield_offset: float = 0.7
## SHIELD 中にプレイヤーへ向き直る補間速さ。側面へ回り込めるよう共通値より遅くする。
@export var shield_face_speed: float = 1.5
## 正面からの近接を防ぐ角度（度、全角）。
@export var shield_arc_deg: float = 120.0
## 側面・背面から盾を解除するために必要な命中回数。
@export var shield_break_hits: int = 3
## 盾を離してから次に掴めるまでの秒数。
@export var regrab_cooldown: float = 6.0
## 盾を構えたまま撃つ間隔（秒）。盾越しでも牽制はしてくるが、放したあとの
## gun_fire_interval より遅くする。0 以下なら盾のままでは撃たない。
@export var shield_fire_interval: float = 2.0
## 人質ノード。空ならグループ hostage から探す。
@export var hostage_path: NodePath
@export_group("")

var _hostage: Hostage = null
var _shield_hit_count: int = 0
var _regrab_left: float = 0.0


func _ready() -> void:
	super._ready()
	if _sm != null:
		_sm.add_state(SHIELD, &"shield", _enter_shield, _physics_shield, _exit_shield)


## 開始時から保持する。SPAWN（画面外から歩き込む）は踏まない。
func _start_state_machine() -> void:
	_resolve_target()
	_resolve_hostage()
	if grab_on_ready and _hostage != null:
		_hostage.enter_shielded(self)
		_sm.start(SHIELD)
		return
	_sm.start(State.APPROACH)


func _physics_process(delta: float) -> void:
	if _regrab_left > 0.0:
		_regrab_left = maxf(_regrab_left - delta, 0.0)
	super._physics_process(delta)
	# StateMachine の更新後に本体が move_and_slide() するため、最後に同期して
	# 移動したフレームも shield_offset を正確に保つ。
	if current_state() == SHIELD:
		_sync_hostage()


## SHIELD 中も速度（0）から待機クリップを選ばせる。開始時から SHIELD に入るため、
## 何も再生しないと T ポーズのままになる。射撃ステートは GunBoss 側の指定に従う。
func _uses_role_locomotion(state: int) -> bool:
	return state == SHIELD or super._uses_role_locomotion(state)


## テスト・デバッグ用。
func shielded_hostage() -> Hostage:
	return _hostage if _is_holding() else null


## Hitbox の汎用方向防御フック。盾（SHIELD）と、基底のガード（GUARD）を合成する。
func blocks_hit_from(attacker_position: Vector3) -> bool:
	if super.blocks_hit_from(attacker_position):
		return true
	if current_state() != SHIELD or not _is_holding():
		return false
	return _is_in_front_arc(attacker_position, shield_arc_deg)


# --- Enemy の役割拡張点 ---------------------------------------------------

## 接近中、掴み直せるなら人質へ向かう。掴めないときは GunBoss の射撃へ渡す。
func _role_approach_override(delta: float) -> bool:
	if not _can_regrab():
		return super._role_approach_override(delta)
	var to := _hostage.global_position - global_position
	to.y = 0.0
	if to.length() <= grab_range:
		_hostage.enter_shielded(self)
		if _hostage.is_shielded():
			_sm.transition_to(SHIELD)
			return true
		return super._role_approach_override(delta)
	velocity.x = signf(to.x) * chase_speed if absf(to.x) > 0.1 else 0.0
	velocity.z = signf(to.z) * minf(depth_align_speed, absf(to.z) / maxf(delta, 0.001)) \
		if absf(to.z) > 0.05 else 0.0
	if absf(to.x) > 0.01:
		_face_direction_at_speed(Vector3(signf(to.x), 0.0, 0.0), delta, rotation_speed)
	return true


# --- 射撃 -----------------------------------------------------------------

## 掴み直せるようになったら射撃をやめて人質へ寄る。それ以外は GunBoss のまま。
func _physics_gun_combat(delta: float) -> void:
	if _can_regrab():
		_sm.transition_to(State.APPROACH)
		return
	super._physics_gun_combat(delta)


## 盾を持っておらず、待ち時間が明けていて、掴める人質が居るか。
func _can_regrab() -> bool:
	if _regrab_left > 0.0 or _is_holding():
		return false
	_resolve_hostage()
	return _hostage != null \
		and _hostage.current_state() != Hostage.HostageState.STANDING


# --- SHIELD ---------------------------------------------------------------

func _enter_shield() -> void:
	_set_color(color_alert)
	_shield_hit_count = 0
	_stop_horizontal_immediate()
	if not _is_holding():
		_release_shield()
		_sm.transition_to(State.APPROACH)
		return
	# 構えた瞬間に撃たない。ボス戦の開始直後と掴み直した直後に 1 周期ぶん置く。
	_cooldown_left = maxf(_cooldown_left, shield_fire_interval)
	_sync_hostage()


func _physics_shield(delta: float) -> void:
	# 人質を取った側から間合いを詰めず、プレイヤーに踏み込ませる。
	_stop_horizontal_immediate()
	_update_burst(delta)
	if not _is_holding():
		_release_shield()
		_sm.transition_to(State.APPROACH)
		return
	if _target == null:
		_resolve_target()
		if _target == null:
			return
	_face_target_x_at_speed(delta, shield_face_speed)
	# 向き直る速さが遅いので、正面へ入るまでは gun_aim_alignment で弾かれて撃てない。
	if shield_fire_interval > 0.0:
		_try_fire(shield_fire_interval)


func _exit_shield() -> void:
	_cancel_burst()
	_stop_horizontal_immediate()


# --- Health 遷移の差分 ---------------------------------------------------

func _on_staggered() -> void:
	if _sm != null and _sm.current() == SHIELD:
		_shield_hit_count += 1
		flash_hit()
		if _shield_hit_count >= maxi(shield_break_hits, 1):
			_release_shield()
			_sm.transition_to(State.APPROACH)
		return
	super._on_staggered()


func _enter_staggered() -> void:
	_release_shield()
	super._enter_staggered()


func _enter_downed() -> void:
	_release_shield()
	super._enter_downed()


# --- 人質の保持・解放 ----------------------------------------------------

func _resolve_hostage() -> void:
	if _hostage != null and is_instance_valid(_hostage):
		return
	_hostage = null
	if not hostage_path.is_empty():
		_hostage = get_node_or_null(hostage_path) as Hostage
	if _hostage == null:
		_hostage = get_tree().get_first_node_in_group(&"hostage") as Hostage


func _is_holding() -> bool:
	return _hostage != null and is_instance_valid(_hostage) and _hostage.is_inside_tree() \
		and _hostage.is_shielded()


func _sync_hostage() -> void:
	if not _is_holding():
		return
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	_hostage.global_position = global_position + forward * shield_offset
	_hostage.global_rotation = global_rotation


func _release_shield() -> void:
	var was_holding := _is_holding()
	if was_holding:
		_hostage.exit_shielded()
	_shield_hit_count = 0
	if was_holding:
		_regrab_left = maxf(regrab_cooldown, 0.0)
