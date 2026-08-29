extends CharacterBody3D

## プレイヤー本体。ベルトスクロールの段移動（A/D = X、W/S = 奥行き Z）と ±X の向き切り替え。
## 攻撃入力を受けて PlayerMelee（AnimationTree 駆動）にコンボを走らせる。
## 攻撃判定 MeleeHitbox の ON/OFF は melee クリップの Call Method Track が
## _enable_hitbox / _disable_hitbox を叩いて行う（コードでタイマーを持たない・§6.3）。
## 命中時（Hitbox.hit_landed）に手応え演出（ヒットストップ＋カメラシェイク）を起動する。

const ComboTree := preload("res://actors/player/combo_tree.gd")
const PLAYER_ACTION_ANIM := preload("res://actors/player/player_action_anim.gd")

## 平地移動速度（m/s）。身長160cm 基準の等身に合わせた既定値。
@export var move_speed: float = 4.5
## 加速度（m/s²）。一歩目がわずかに遅れることで質量感を出す。
@export var accel: float = 10.0
## 減速度（m/s²）。入力を離してもピタッと止まらず短い減速を挟む。
@export var decel: float = 14.0
## 攻撃開始時のブレーキ（m/s²）。移動慣性を踏み込み一歩ぶんだけ残して殺す。
@export var attack_brake: float = 30.0
@export_group("Melee Lunge")
## 技ごとの踏み込み初速（m/s）。attack_brake で減衰し、一歩踏み込んで止まる。
@export var jab_lunge_speed: float = 1.5
@export var straight_lunge_speed: float = 2.5
@export var hook_lunge_speed: float = 3.5
## 右膝は射程が短いため、既存キック初段の深い踏み込みを引き継ぐ。
@export var knee_lunge_speed: float = 3.0
@export var middle_lunge_speed: float = 2.0
@export var high_lunge_speed: float = 2.0
## 2段目以降へ進むたびに累乗する倍率。1.0 なら段による変化なし。
@export_range(0.0, 3.0, 0.05, "or_greater") var lunge_stage_multiplier: float = 1.0
## フィニッシュへ到達せずコンボが途切れたとき、最後に命中した相手へ与える強さ。
@export var interrupted_combo_knockback: float = 7.0
@export_group("")
## 向き（±X）を切り替えるときの回転補間の速さ（lerp 係数）。
@export var rotation_speed: float = 12.0

@export_group("Dodge")
## 回避で後方（向いている逆）へ退く距離（m）。回避クリップは水平ルートモーションを
## 潰してあるため、退く量はここが決める。初速は dodge_duration の終わりに
## ちょうど止まるよう一定減速で逆算する（_dodge_launch_speed）。
## 既定 2.85 は、初速 9.0m/s を 0.300 秒で減衰させていた頃の実測 1.425m の 2 倍。
## 画面端 clamp はカメラ半幅 4.765m − screen_margin 0.6m = 4.165m まで許すので、
## この距離では端に張り付かない（バク転だけに切り詰めた 0.800 秒では初速 7.125m/s、
## カメラの追従遅れは 0.89m 程度）。
@export var dodge_distance: float = 2.85
## この値は回避ステートの寿命であると同時に、PlayerActionAnim.configure_action() が
## 再生倍率を「クリップ長 / duration」で決める分母でもある。0.300 は回避クリップが
## 無かった頃の値で、Backflip（実測 2.167 秒）を割り当てた後は 7.222 倍速となり、
## モーションが一瞬で終わって読めなかった。
## 現在は助走・構えと着地後の立ち上がりを PlayerActionAnim の custom timeline で切り落とし、
## バク転だけを再生する。既定 0.800 はその切り出し区間の長さ
## （dodge_trim_start 0.600 〜 dodge_trim_end 1.400）と一致させ、再生倍率を 1.000 倍に保つ。
@export var dodge_duration: float = 0.800
## 無敵時間（秒）。この間は被弾しない（Hurtbox を切る）。
## 切り出した区間（＝跳んでいる間）全体を覆うため dodge_duration と同じ 0.800 とする。
## 元クリップでの接地は第40フレーム＝1.333 秒で、切り出し開始 0.600 秒からは 0.733 秒。
## 区間の終わり 0.800 秒はその 0.067 秒後にあたるため、着地後の無防備な余韻は無い。
@export var dodge_iframes: float = 0.800
## 回避の再使用待ち（秒）。
@export var dodge_cooldown: float = 0.45
@export_group("Belt")
## 奥行き（Z）方向の移動速度の倍率。ベルトスクロールでは上下を横より遅くする。
@export_range(0.1, 1.0, 0.05) var depth_speed_ratio: float = 0.7
## ベルトの奥行き範囲（m）。面側が set_belt_bounds() で渡すまで clamp しない。
@export var belt_z_min: float = -1.5
@export var belt_z_max: float = 1.5
## 画面端（BeltCamera の可視範囲）から内側へ取る余白（m）。
@export var screen_margin: float = 0.6
@export_group("")

@export_group("Dance")
## interact を押して踊っている間の HP 回復量（毎秒）。
@export var dance_heal_per_second: float = 1000.0
@export_group("")

@export_group("Hurt")
## 被弾時のノックバック初速（m/s）。
@export var hurt_knockback_speed: float = 3.5
## ノックバックが減衰しきるまでの時間（秒）。この間は移動入力を受け付けない。
@export var hurt_knockback_decay: float = 0.28
## 上半身の被弾リアクションが見えている時間。入力ロックとは独立させる。
@export var hurt_reaction_duration: float = 0.60
## 被弾時のカメラシェイク強度（0.0-1.0）。VRM は色を変えられないため、
## 手応えの提示はカメラ側で行う。
@export var hurt_shake_strength: float = 0.8

@export_subgroup("Down")
## 倒れたら RunState の残機を 1 消費する。尽きていれば立ち上がらず player_out_of_lives を送る。
## false なら従来どおり時間だけ失って立ち上がる（テスト・ボス用）。
@export var uses_lives: bool = true
## 倒れてから立ち上がり始めるまでの秒数。倒れている間は無敵（Health が
## ダウン中の take_hit を弾く）で、失うのは時間だけ。ENGAGEMENT → BREACH が
## 時間で進むため、この遅れがそのまま「警察が近づく」代償になる。
@export var down_duration: float = 3.0
## ダウン用クリップの倒れ込みを終えるまでの所要秒数。
## クリップ本来の長さは 2.567 秒で、この値に合わせて再生速度をスケールする。
## 0.35 はモデルを傾けるだけの暫定表現だった頃の値で、クリップを当てた際に
## 7.3 倍速となり何が起きたか読めなかったため 1.6 (1.6 倍速) に変更した。
## 倒れ込みは down_duration と並行して進むため、ここを伸ばしても復帰までの
## 合計時間は変わらない。
@export var down_fall_time: float = 1.6
## 立ち上がりの所要秒数。この間もまだ入力は受け付けない。
@export var stand_up_time: float = 1.70
@export_group("")

## 命中時のヒットストップ時間（実時間・秒）。
@export var hit_stop_duration: float = 0.09
## 命中時のヒットストップのスロー係数（0 に近いほど強く止まる）。
## 0.05 は被弾前ポーズのまま凍結して見えたため、薄いスローへ緩めた。
@export var hit_stop_scale: float = 0.15
## 命中時のカメラシェイク強度（0.0-1.0）。
@export var hit_shake_strength: float = 0.6

@export var model_path: NodePath = ^"Model"
@export var melee_path: NodePath = ^"PlayerMelee"
@export var hitbox_path: NodePath = ^"Model/MeleeHitbox"
@export var health_path: NodePath = ^"Health"
@export var hurtbox_path: NodePath = ^"Hurtbox"
@export var recovery_blink_path: NodePath = ^"RecoveryBlink"
## 面側の BeltCamera。空ならグループ belt_camera から探す（無ければ X clamp しない）。
@export var camera_path: NodePath
## カメラシェイク。空なら BeltCamera の子 CameraShake を使う。
@export var camera_shake_path: NodePath

## HP が尽きて倒れた。
signal player_downed()
## 倒れた状態から立ち上がりきった（HP は全快している）。
signal player_recovered()
## 倒れて残機も尽きた（コンティニュー待ち）。立ち上がらない。
signal player_out_of_lives()

var _model: Node3D = null
var _melee: Node = null
var _hitbox: Hitbox = null
var _camera_shake: Node = null
var _health: Health = null
var _belt_camera: Node3D = null
var _hurtbox: Area3D = null
var _recovery_tint: ModelTint = ModelTint.new()
var _recovery_blink: ModelBlink = null
## 回避の残り秒数（>0 の間は回避移動・入力ロック）。
var _dodge_timer: float = 0.0
var _dodge_vel_x: float = 0.0
var _iframe_timer: float = 0.0
var _dodge_cooldown_left: float = 0.0
## PlayerAction から要求された全身技の踏み込み。移動と衝突は CharacterBody3D 側で処理する。
var _action_lunge_speed: float = 0.0
var _action_lunge_remaining: float = 0.0
var _action_lunge_facing: int = 1
## 向き。+1 = +X（画面右）、-1 = -X（画面左）。
var _facing: int = 1
## 残機が尽きて倒れたまま。
var _out_of_lives: bool = false
## set_belt_bounds() が呼ばれるまで奥行きを clamp しない（旧テストステージ互換）。
var _belt_bounds_set: bool = false
## 現在のコンボで最後に命中した相手。中断終了時の押し離しだけに使う。
var _last_combo_hit_target: Node3D = null

## 被弾ロックの残り時間（秒）。0 より大きい間は移動入力を受け付けない。
var _hurt_timer: float = 0.0
var _knockback_vel: Vector3 = Vector3.ZERO
var _downed: bool = false
## 倒れている残り秒数。0 になったら立ち上がりに入る。
var _down_timer: float = 0.0
## 立ち上がり動作の残り秒数。0 になったら操作が戻る。
var _stand_up_timer: float = 0.0
func _ready() -> void:
	_model = get_node_or_null(model_path) as Node3D
	_melee = get_node_or_null(melee_path)
	_hitbox = get_node_or_null(hitbox_path) as Hitbox
	_health = get_node_or_null(health_path) as Health
	_hurtbox = get_node_or_null(hurtbox_path) as Area3D
	_recovery_blink = get_node_or_null(recovery_blink_path) as ModelBlink
	if not camera_path.is_empty():
		_belt_camera = get_node_or_null(camera_path) as Node3D
	if not camera_shake_path.is_empty():
		_camera_shake = get_node_or_null(camera_shake_path)
	# 向きの初期値をモデルに反映する（VRM の前方は Model の +Z。+90° 回すと +X を向く）。
	if _model != null:
		_model.rotation.y = _facing_yaw()
	_recovery_tint.setup(_model)
	if _recovery_blink != null:
		_recovery_blink.setup(_recovery_tint)

	if _hitbox != null:
		_hitbox.hit_landed.connect(_on_hit_landed)
	if _melee != null and _melee.has_signal("stage_started"):
		_melee.connect("stage_started", _on_stage_started)
	if _melee != null and _melee.has_signal("combo_started"):
		_melee.connect("combo_started", _on_combo_started)
	if _melee != null and _melee.has_signal("combo_interrupted"):
		_melee.connect("combo_interrupted", _on_combo_interrupted)
	if _health != null:
		_health.downed.connect(_on_health_downed)


## 面側から呼ぶ。ベルトの奥行き範囲を設定し、以後 Z を clamp する。
func set_belt_bounds(z_min: float, z_max: float) -> void:
	belt_z_min = minf(z_min, z_max)
	belt_z_max = maxf(z_min, z_max)
	_belt_bounds_set = true


## 向き。+1 = +X（画面右）、-1 = -X（画面左）。
func facing() -> int:
	return _facing


## コンボの段開始で向いている方向（±X）へ踏み込む（attack_brake が減衰を担う）。
func _on_stage_started(technique: StringName, stage: int) -> void:
	var stage_scale := pow(lunge_stage_multiplier, float(maxi(stage - 1, 0)))
	var speed_for_stage := _lunge_speed_for(technique) * stage_scale
	velocity.x = float(_facing) * speed_for_stage
	velocity.z = 0.0


func _lunge_speed_for(technique: StringName) -> float:
	match technique:
		ComboTree.TECHNIQUE_JAB:
			return jab_lunge_speed
		ComboTree.TECHNIQUE_STRAIGHT:
			return straight_lunge_speed
		ComboTree.TECHNIQUE_HOOK:
			return hook_lunge_speed
		ComboTree.TECHNIQUE_KNEE:
			return knee_lunge_speed
		ComboTree.TECHNIQUE_MIDDLE:
			return middle_lunge_speed
		ComboTree.TECHNIQUE_HIGH:
			return high_lunge_speed
	return 0.0


func _physics_process(delta: float) -> void:
	var attacking: bool = _melee != null and bool(_melee.call("is_attacking"))
	var dancing: bool = _melee != null and bool(_melee.call("is_dancing"))

	var input_dir := _read_move_input()
	# X は横、Z は奥行き（move_forward = 奥 = -Z）。カメラは固定なのでカメラ相対変換はしない。
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)

	if _hurt_timer > 0.0:
		_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	if _dodge_cooldown_left > 0.0:
		_dodge_cooldown_left = maxf(_dodge_cooldown_left - delta, 0.0)
	if _dodge_timer > 0.0:
		_dodge_timer = maxf(_dodge_timer - delta, 0.0)
	if _iframe_timer > 0.0:
		_iframe_timer = maxf(_iframe_timer - delta, 0.0)
		if _iframe_timer <= 0.0 and _hurtbox != null:
			_hurtbox.set_deferred("monitorable", true)
	if _downed:
		_update_down(delta)
	if dancing and (not _interact_held()
			or not input_dir.is_zero_approx() or _hurt_timer > 0.0 or _downed):
		_stop_dance()
		dancing = false
	if dancing and _health != null:
		_health.heal(dance_heal_per_second * delta)

	# 速度は目標値へ加減速で寄せる（即時切替をやめて慣性＝質量感を出す）。
	var horizontal := Vector2(velocity.x, velocity.z)
	if _downed:
		horizontal = horizontal.move_toward(Vector2.ZERO, decel * delta)
	elif _hurt_timer > 0.0:
		# 被弾ロック中。ノックバックに流されるだけで、入力・攻撃は通らない。
		# 回避の無敵が切れた後半で被弾した場合もここが優先し、ノックバックを
		# 回避の終了まで持ち越さない（receive_knockback が回避の滑りを止めている）。
		horizontal = Vector2(_knockback_vel.x, _knockback_vel.z)
		_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO,
			(hurt_knockback_speed / hurt_knockback_decay) * delta)
	elif _dodge_timer > 0.0:
		# 回避中はダッシュ速度で滑る。入力・攻撃は受けない。
		horizontal = Vector2(_dodge_vel_x, 0.0)
		_dodge_vel_x = move_toward(_dodge_vel_x, 0.0,
			(_dodge_launch_speed() / dodge_duration) * delta)
	elif _action_lunge_remaining > 0.0:
		# 全身技の指定距離を、通常攻撃の attack_brake で減衰させずに踏み込む。
		var frame_speed: float = _action_lunge_speed
		if delta > 0.0:
			frame_speed = minf(frame_speed, _action_lunge_remaining / delta)
		horizontal = Vector2(float(_action_lunge_facing) * frame_speed, 0.0)
	elif attacking:
		# 攻撃中は移動入力を無視し、強めのブレーキで踏み込み一歩ぶんだけ滑って止まる。
		horizontal = horizontal.move_toward(Vector2.ZERO, attack_brake * delta)
	elif dancing:
		# 回復中は残っていた慣性も含めて水平移動を完全に止める。
		horizontal = Vector2.ZERO
	elif direction.length() > 0.001:
		var target := Vector2(direction.x * move_speed,
			direction.z * move_speed * depth_speed_ratio)
		horizontal = horizontal.move_toward(target, accel * delta)
		if absf(direction.x) > 0.001:
			_facing = 1 if direction.x > 0.0 else -1
	else:
		horizontal = horizontal.move_toward(Vector2.ZERO, decel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	else:
		velocity.y = 0.0

	var position_before_move: Vector3 = global_position
	move_and_slide()
	_clamp_to_belt()
	if _action_lunge_remaining > 0.0:
		var lunge_advance: float = absf(global_position.x - position_before_move.x)
		_action_lunge_remaining = maxf(_action_lunge_remaining - lunge_advance, 0.0)
		if _action_lunge_remaining <= 0.0:
			_action_lunge_speed = 0.0
			velocity.x = 0.0
	_update_facing(delta)

	if _melee != null:
		var planar := Vector2(velocity.x, velocity.z).length()
		_melee.call("set_locomotion", planar)


func _unhandled_input(event: InputEvent) -> void:
	if not _accepts_player_input():
		return
	if _downed or _hurt_timer > 0.0:
		return
	var dancing: bool = _melee != null and bool(_melee.call("is_dancing"))
	if dancing:
		if event.is_action_released("interact") or event.is_action_pressed("attack") \
				or event.is_action_pressed("kick"):
			_stop_dance()
		return
	if event.is_action_pressed("dodge"):
		_try_dodge()
		return
	if event.is_action_pressed("interact"):
		_try_start_dance()
		return
	if event.is_action_pressed("attack"):
		if _melee != null:
			_melee.call("attack")
	elif event.is_action_pressed("kick"):
		if _melee != null:
			_melee.call("kick")


## 回避。向いている逆方向へ跳んで無敵で避ける。ダウン・被弾・回避中・クールダウン中は不可。
func _try_dodge() -> void:
	if _downed or _hurt_timer > 0.0 or _dodge_timer > 0.0 or _dodge_cooldown_left > 0.0:
		return
	_stop_dance()
	if _melee != null and _melee.has_method("request_action") \
			and not bool(_melee.call("request_action", PLAYER_ACTION_ANIM.ACTION_DODGE,
			dodge_duration)):
		return
	# 後方（向いている逆）へ跳ぶ。
	_dodge_vel_x = float(-_facing) * _dodge_launch_speed()
	_dodge_timer = dodge_duration
	_iframe_timer = dodge_iframes
	_dodge_cooldown_left = dodge_cooldown + dodge_duration
	if _hurtbox != null:
		_hurtbox.set_deferred("monitorable", false)


## 一定減速で dodge_duration の終わりに停止し、その間に dodge_distance だけ退く初速（m/s）。
## 距離 = 初速 * 持続 / 2 なので、初速 = 2 * 距離 / 持続。
func _dodge_launch_speed() -> float:
	if dodge_duration <= 0.0:
		return 0.0
	return 2.0 * dodge_distance / dodge_duration


func is_dodging() -> bool:
	return _dodge_timer > 0.0


## 全身技を向いている方向へ指定距離だけ移動させる。PlayerAction は開始時刻だけを決め、
## 衝突・画面端 clamp を含む実移動は CharacterBody3D が所有する。
func start_action_lunge(speed: float, distance: float) -> void:
	_action_lunge_speed = maxf(speed, 0.0)
	_action_lunge_remaining = maxf(distance, 0.0)
	_action_lunge_facing = _facing
	velocity.z = 0.0


func stop_action_lunge() -> void:
	_action_lunge_speed = 0.0
	_action_lunge_remaining = 0.0
	velocity.x = 0.0
	velocity.z = 0.0


func _try_start_dance() -> void:
	if _melee == null or _downed or _hurt_timer > 0.0:
		return
	var input_dir := _read_move_input()
	if not input_dir.is_zero_approx():
		return
	if bool(_melee.call("start_dance")):
		velocity.x = 0.0
		velocity.z = 0.0


func _stop_dance() -> void:
	if _melee != null:
		_melee.call("stop_dance")


## MeleeHitbox の Call Method Track から呼ばれる（有効化）。
## 倒れている間は判定を出さない。ダウンした時点で再生中だったクリップは
## そのまま最後まで進むため、ここで止めないと寝たまま殴れてしまう。
func _enable_hitbox(damage: float, knockback: float) -> void:
	if _hitbox == null or _downed:
		return
	_hitbox.configure(damage, knockback, false)
	_hitbox.activate()


## MeleeHitbox の Call Method Track から呼ばれる（無効化）。
func _disable_hitbox() -> void:
	if _hitbox == null:
		return
	_hitbox.deactivate()


## Hitbox が誰かに当たった瞬間の手応え演出。
func _on_hit_landed(target: Node3D) -> void:
	_last_combo_hit_target = target
	play_action_hit_feedback()


## PlayerAction の範囲攻撃も、通常攻撃と同じヒットストップとシェイクを使う。
## コンボ中断用の命中対象は通常コンボだけが所有するため、ここでは変更しない。
func play_action_hit_feedback() -> void:
	var hs := get_node_or_null(^"/root/HitStop")
	if hs != null and hs.has_method("apply"):
		hs.call("apply", hit_stop_duration, hit_stop_scale)
	_shake_camera(hit_shake_strength)


func _on_combo_started() -> void:
	_last_combo_hit_target = null


func _on_combo_interrupted() -> void:
	if not is_instance_valid(_last_combo_hit_target) \
			or interrupted_combo_knockback <= 0.0:
		_last_combo_hit_target = null
		return
	if _last_combo_hit_target.has_method("receive_knockback"):
		var direction := _last_combo_hit_target.global_position - global_position
		_last_combo_hit_target.call("receive_knockback", direction,
			interrupted_combo_knockback)
	_last_combo_hit_target = null


## Hurtbox から呼ばれる。direction は攻撃者→自分の水平方向。
## 被弾ロックの間は移動入力と攻撃入力を受け付けない（一方的な連打で押し切れないように）。
func receive_knockback(direction: Vector3, strength: float) -> void:
	# 被弾通知自体でダンスを止める。strength=0 の銃撃でもキャンセルされる。
	_stop_dance()
	if _downed:
		return
	# 被弾モーションは上半身レイヤーで重ねる（コンボ・入力・判定は中断しない）。
	# strength=0 の銃撃でも出すため、ノックバック不成立の早期 return より前に置く。
	if _melee != null and _melee.has_method("play_hurt"):
		_melee.call("play_hurt", hurt_reaction_duration)
	if strength <= 0.0:
		return
	var d := direction
	d.y = 0.0
	if d.length() < 0.001:
		return
	_knockback_vel = d.normalized() * hurt_knockback_speed * clampf(strength / 5.0, 0.5, 2.0)
	_hurt_timer = hurt_knockback_decay
	# 回避の後半（無敵切れ）で当たった場合、回避の滑りは止めてノックバックに従う。
	_dodge_vel_x = 0.0


## Hurtbox から呼ばれる。VRM のマテリアルは触らず、カメラで被弾を提示する。
func flash_hit() -> void:
	_stop_dance()
	_shake_camera(hurt_shake_strength)


## HP が尽きた。倒れて down_duration 秒後に自力で立ち上がる。
## 失うのは時間だけで、ゲームオーバーは作らない（エンディング4分岐に
## プレイヤー死亡が無いため。docs/tasks.md 8/17 の決定）。
func _on_health_downed(_lethal: bool) -> void:
	if _downed:
		return
	_stop_dance()
	_downed = true
	_hurt_timer = 0.0
	_down_timer = down_duration
	_stand_up_timer = 0.0
	if _recovery_blink != null:
		_recovery_blink.begin(down_duration)
	# 攻撃中に倒れた場合、開いたままの判定を閉じる。
	if _hitbox != null:
		_hitbox.deactivate_deferred()
	if _melee != null and _melee.has_method("start_down"):
		_melee.call("start_down", down_fall_time)
	player_downed.emit()


## 倒れている間の時間管理。倒れ → 立ち上がり → 操作復帰の順に進む。
func _update_down(delta: float) -> void:
	if _out_of_lives:
		return
	if _down_timer > 0.0:
		_down_timer = maxf(_down_timer - delta, 0.0)
		if _down_timer <= 0.0:
			if _consume_life():
				_start_stand_up()
			else:
				_out_of_lives = true
				if _recovery_blink != null:
					_recovery_blink.finish()
				player_out_of_lives.emit()
		return

	if _stand_up_timer > 0.0:
		_stand_up_timer = maxf(_stand_up_timer - delta, 0.0)
		if _stand_up_timer > 0.0:
			return
		_finish_recovery()
		return

	# どちらのタイマーも尽きている。down_duration / stand_up_time に 0 を
	# 設定するとここへ落ちる。復帰を確定させないと、倒れたまま操作不能になる
	# （値の設定だけで「ダウンして戻らない」不具合が再発してしまう）。
	_finish_recovery()


func _start_stand_up() -> void:
	_stand_up_timer = stand_up_time
	if _recovery_blink != null:
		_recovery_blink.finish()
	if _melee != null and _melee.has_method("start_stand_up"):
		_melee.call("start_stand_up", stand_up_time)


## 立ち上がり完了。HP の全快はここで行う。立ち上がり中に全快させると
## Health のダウン無敵が切れる一方で入力は戻っておらず、避けられない一方的な
## 被弾窓（stand_up_time 秒）ができるため。
func _finish_recovery() -> void:
	if _recovery_blink != null:
		_recovery_blink.finish()
	if _health != null:
		_health.revive()
	_stand_up_timer = 0.0
	if _melee != null and _melee.has_method("finish_down"):
		_melee.call("finish_down")
	_downed = false
	player_recovered.emit()


func is_downed() -> bool:
	return _downed


func is_out_of_lives() -> bool:
	return _out_of_lives


## 残機を 1 消費する。まだ残っていれば true。uses_lives が false なら常に true。
func _consume_life() -> bool:
	if not uses_lives:
		return true
	return RunState.lose_life()


## 入力の読み取り。AI 制御（5面のニケ）はこれらを上書きする。
func _read_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _interact_held() -> bool:
	return Input.is_action_pressed("interact")


## _unhandled_input を処理するか。AI 制御では false。
func _accepts_player_input() -> bool:
	return true


func is_dancing() -> bool:
	return _melee != null and bool(_melee.call("is_dancing"))


func current_hp() -> float:
	return _health.current_hp() if _health != null else 0.0


## 向き（±X）に対応する Model のヨー。VRM の前方は Model の +Z なので +X は +90°。
func _facing_yaw() -> float:
	return float(_facing) * PI * 0.5


func _update_facing(delta: float) -> void:
	if _model == null:
		return
	_model.rotation.y = wrapf(
		lerp_angle(_model.rotation.y, _facing_yaw(), rotation_speed * delta), -PI, PI)


## 奥行きをベルト幅に、X をカメラの可視範囲に収める。clamp した軸の速度は殺す。
func _clamp_to_belt() -> void:
	if _belt_bounds_set:
		var z := clampf(global_position.z, belt_z_min, belt_z_max)
		if not is_equal_approx(z, global_position.z):
			global_position.z = z
			velocity.z = 0.0
	var cam := _find_belt_camera()
	if cam == null:
		return
	var left: float = float(cam.call("left_limit")) + screen_margin
	var right: float = float(cam.call("right_limit")) - screen_margin
	if left >= right:
		return
	var x := clampf(global_position.x, left, right)
	if not is_equal_approx(x, global_position.x):
		global_position.x = x
		velocity.x = 0.0


## BeltCamera を探す。@export 未指定ならグループから一度だけ解決する。
func _find_belt_camera() -> Node3D:
	if _belt_camera != null and is_instance_valid(_belt_camera):
		return _belt_camera
	_belt_camera = null
	var found := get_tree().get_first_node_in_group(&"belt_camera") as Node3D
	if found != null and found.has_method("left_limit") and found.has_method("right_limit"):
		_belt_camera = found
	return _belt_camera


func _shake_camera(strength: float) -> void:
	if _camera_shake == null or not is_instance_valid(_camera_shake):
		_camera_shake = null
		var cam := _find_belt_camera()
		if cam != null:
			_camera_shake = cam.get_node_or_null(^"CameraShake")
	if _camera_shake != null and _camera_shake.has_method("shake"):
		_camera_shake.call("shake", strength)
