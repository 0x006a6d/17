extends CharacterBody3D
class_name Enemy

const EnemyAttackProfileType := preload("res://actors/enemy/enemy_attack_profile.gd")

## 敵の共通挙動（technical-spec §8）。旧 robber.gd（籠城銀行版）から、知覚・巡回・
## ナビゲーションを外し、ベルトスクロールの段追従（Z を合わせてから X を詰める）に
## 置き換えたもの。ATTACK / STAGGERED / GUARD / DOWNED と攻撃プロファイル、のけぞり耐性、
## ガード・反撃は旧実装のまま。役割差（rusher / bruiser / shielder）は `roles/` で注入する。
##
## 見た目は `Model` の下へ差し込む Mixamo キャラクター（With Skin）。差し替えは
## `model_scene` 1か所で完結する。役割はシルエット（服装）で見分ける前提とし、
## 色でステートを塗り分けない（重なると読めなくなる）。見た目に出す色は
## 被弾フラッシュだけで、ModelTint が overlay に白を短く重ねる。
##
## 攻撃判定の窓はこのスクリプトのタイマーで開閉し、クリップ長をそのタイマーに
## 合わせて再生する（速度スケール）。主人公（§6.3）の Call Method Track 方式へ
## 揃えるのは、犯人の攻撃クリップを専用にベイクしてからにする。
##
## 向きの規約: 敵は本体（CharacterBody3D）を回し、前方は Godot 標準の -Z。ベルト上では
## 前方を ±X に向ける（ヨー ±90°）。主人公は VRM の都合で Model ノードの +Z が前方。
##
## 役割スクリプトは `State.DOWNED + 1` から自分専用ステート（RUSH / SHIELD）を割り当てる。
## 基底 enum へ足すときは DOWNED より前に挿す。
enum State { SPAWN, APPROACH, ATTACK, STAGGERED, GUARD, DOWNED }

## 追跡対象を探すグループ名。プレイヤーが自分を登録している。
@export var target_group: StringName = &"player"

@export_group("Movement")
## X 方向の接近速度（m/s）。プレイヤー（4.5）より遅くし、逃げれば振り切れるようにする。
@export var chase_speed: float = 3.2
## 向き直りの補間速さ（lerp 係数）。
@export var rotation_speed: float = 8.0

@export_group("Belt")
## 出現後、無敵のまま画面内へ歩き込む秒数。
@export var spawn_walk_in: float = 0.8
## 奥行き（Z）を合わせる速度（m/s）。横より遅くし、段をずらせば一瞬は逃げられるようにする。
@export var depth_align_speed: float = 2.2
## 目標レーンにランダムに加えるずれ（m）。複数体が一直線に並ぶのを避ける。
@export var approach_jitter: float = 0.35
## 出現時に、プレイヤーの反対側へ回り込む側を選ぶ確率。
@export_range(0.0, 1.0) var flank_chance: float = 0.5
## プレイヤーの X を横切るときに使う、プレイヤーからのレーンのずれ（m）。
@export var cross_lane_offset: float = 1.0
## 攻撃に入るための奥行き差の上限（m）。Hitbox.depth_tolerance（0.6）より小さくする。
@export var attack_depth_tolerance: float = 0.45
## 一度画面に入ったあと、画面端から内側へ残す余白（m）。プレイヤー側の
## `screen_margin` と同じ役割。3面ボスのように後退する敵が画面外へ抜けると、
## プレイヤーは画面端で止まるため追えず、倒せなくなる。
@export var screen_margin: float = 0.6
## 画面へ入ってから、閉じ込める線を screen_margin ぶん内側へ寄せきるまでの秒数。
## 0 にすると入った瞬間に内側の線へ切り替わり、位置が飛ぶ。
@export var screen_margin_ramp: float = 0.5
## ダウン後に消えるまでの秒数。
@export var despawn_delay: float = 4.0

@export_group("Combat")
## 攻撃を始める距離（m）。
@export var attack_range: float = 1.35
## 攻撃を中断せず追撃を続ける距離（m）。attack_range より少し広く取る。
@export var attack_keep_range: float = 2.4
## 予備動作の秒数（プレイヤーが見てから避けられる長さ）。
@export var attack_telegraph: float = 0.45
## 判定を開いている秒数。
@export var attack_active: float = 0.18
## 硬直の秒数。
@export var attack_recovery: float = 0.35
## 次の攻撃までの間隔（秒）。
@export var attack_cooldown: float = 0.8
## 攻撃の踏み込み初速（m/s）。
@export var attack_lunge_speed: float = 1.2
## 与ダメージ。
@export var attack_damage: float = 1200.0
## 0以上なら全バリエーションのdamageより優先する（役割・テスト用）。
@export var attack_damage_override: float = -1.0
## 与ノックバック強度。
@export var attack_knockback: float = 3.0
## 距離条件を満たす候補から毎回1つ選ぶ。空なら上記の旧設定と cross punch を使う。
@export var attack_profiles: Array[EnemyAttackProfileType] = []

@export_group("Reaction")
## 被弾でよろけている秒数。lead-in を飛ばした HIT クリップの残り 0.50 秒を全編再生する。
@export var stagger_duration: float = 0.5
## ノックバックを伴う大のけぞりの滞在秒数。1.0 秒のクリップが stagger_duration で
## 半分に切られないよう、通常より長く取って再生速度も合わせる。
@export var knockback_stagger_duration: float = 0.65
## HIT クリップ（mixamo_hit_head、実長 0.933s）先頭の無反応区間（秒）。
## 命中からのけぞり開始までの空白を、この位置から再生して飛ばす。
@export var hit_clip_lead_in: float = 0.1
## poise で耐えた被弾に差し込む軽いのけぞりの秒数。行動は中断しない。
@export var small_react_duration: float = 0.22
## 軽いのけぞりクリップの開始位置（秒）。先頭の無反応区間を飛ばす。
@export var small_react_start: float = 0.0
## のけぞり耐性。1回の被弾ごとに必ずのけぞると、殴り始めた側が一方的に固め続けられ、
## 攻防が成立しない（実測: 1対1で犯人がのけぞりに費やす時間が全体の 58%）。
## 短時間に受けた累計ダメージがこの値を超えたときだけ STAGGERED へ落とす。
## 0 以下にすると従来どおり毎回のけぞる。
@export var poise: float = 2800.0
## のけぞり耐性の回復量（毎秒）。殴る手を止めれば体勢が立て直る。
@export var poise_recovery: float = 2000.0
@export_group("Adds")
## 増援を呼ぶ HP の割合（残り HP / 最大 HP）。小さい順でも大きい順でもよく、
## それぞれ1回だけ発火する。空なら増援を呼ばない。ボスにだけ使う。
@export var adds_hp_ratios: Array[float] = []
## 1回に呼ぶ雑魚の数。出す種類は面側の adds_scenes が決める。
@export var adds_count: int = 0
@export_group("")

## のけぞるかどうか。false にすると、どれだけ殴られても STAGGERED へ落ちず、
## 耐えたときの軽いのけぞりも差し込まない（ノックバックも乗らない）。
## 4面・5面のゾンビに使う。
@export var staggers: bool = true
## 足を止めるときの減速度（m/s²）。攻撃の予備動作・硬直・よろけで使う。
@export var stop_decel: float = 20.0
## ノックバックの初速（m/s）。
@export var knockback_speed: float = 3.0
## ノックバックが減衰しきるまでの秒数。
@export var knockback_decay: float = 0.25
## 被弾フラッシュの色と持続秒数。
@export var flash_color: Color = Color(1, 1, 1, 1)
@export var flash_duration: float = 0.08
## ダウン時に倒れる角度（度）と所要秒数。ラグドールは使わない（tasks.md）。
@export var fall_angle_deg: float = 85.0
@export var fall_duration: float = 0.4

@export_group("Guard")
## ガードと反撃。殴られっぱなしだと格闘にならないので、耐えた直後に構えて、
## 受け止めたら反撃する。回り込めば正面扇形の外から通る。
@export var guard_enabled: bool = true
## 近接を防ぐ正面扇形の全角（度）。これより外から殴られたガードは成立しない。
@export var guard_arc_deg: float = 140.0
## 構えている秒数。
@export var guard_duration: float = 1.1
## ガードを解いてから次に構えるまでの秒数。
@export var guard_cooldown: float = 1.8
## のけぞらずに耐えた被弾1回につき、構えに入る確率。
@export_range(0.0, 1.0) var guard_chance: float = 0.4
## この回数を受け止めたら、時間を待たずに反撃へ移る。
@export var counter_after_blocks: int = 2
## 受け止めたあとに反撃する確率。
@export_range(0.0, 1.0) var counter_chance: float = 0.8
## 反撃の予備動作（秒）。通常の attack_telegraph より短く、割り込みにくい。
@export var counter_telegraph: float = 0.18
## ガード中の向き直りの速さ。遅くして側面へ回り込む余地を残す。
@export var guard_face_speed: float = 2.5

@export_group("Appearance")
## 見た目。`Model` の下へ差し込むキャラクターのシーン（Mixamo の FBX）。
## 差し替えはここ1か所で完結させる（technical-spec §9）。
@export var model_scene: PackedScene
## 主人公の VRM（MToon）へ寄せるため、写真テクスチャの陰影をトゥーンへ置き換える。
## 切ると Mixamo 本来の見た目に戻る。
@export var toon_skin: bool = true
## ステートの記録用の色。**描画には使わない**（_refresh_tint 参照）。
## 役割スクリプトが `color_idle` を上書きして役割を識別する慣習も残している。
@export var color_idle: Color = Color(0.42, 0.24, 0.26)
@export var color_alert: Color = Color(0.72, 0.52, 0.18)
@export var color_telegraph: Color = Color(0.85, 0.18, 0.16)
## 被弾フラッシュのピーク時の濃さ。
@export_range(0.0, 1.0) var flash_tint_alpha: float = 0.85

@export_group("Nodes")
@export var model_path: NodePath = ^"Model"
@export var animator_path: NodePath = ^"Animator"
@export var health_path: NodePath = ^"Health"
@export var hurtbox_path: NodePath = ^"Hurtbox"
@export var hitbox_path: NodePath = ^"MeleeHitbox"
@export var state_machine_path: NodePath = ^"StateMachine"
@export var despawn_blink_path: NodePath = ^"DespawnBlink"
@export_group("")

## 現在ステートが変わった（デバッグ表示・テスト用）。
signal state_entered(state: int)
## ダウンした（面側が波の全滅判定に使う）。
signal defeated(enemy: Node3D)
## ボスが増援を呼ぶ。面側（belt_stage）が受けて雑魚を出す。
signal adds_requested(count: int)

var _model: Node3D = null
var _animator: NpcAnimator = null
var _tint: ModelTint = ModelTint.new()
var _health: Health = null
var _hurtbox: Area3D = null
var _hitbox: Hitbox = null
var _sm: StateMachine = null
var _despawn_blink: ModelBlink = null

var _target: Node3D = null
## 現在のステート色。描画には使わず、テストとデバッグの識別に使う。
var _state_color: Color = Color.WHITE
var _flash_tween: Tween = null
var _cooldown_left: float = 0.0
var _hitbox_open: bool = false
## プレイヤーのどちら側に立つか。+1 = プレイヤーより +X 側、-1 = -X 側。
var _side: int = 1
## 目標レーンのずれ（approach_jitter から決める）。
var _lane_offset: float = 0.0
## ベルトの奥行き範囲。面側が set_belt_bounds() で渡す。
var _belt_z_min: float = -1.5
var _belt_z_max: float = 1.5
## 面側の BeltCamera（画面端の clamp に使う）。グループ belt_camera から探す。
var _belt_camera: Node3D = null
## 一度でも画面内に入ったか。出現直後は画面外に居るので、入るまでは clamp しない。
var _entered_screen: bool = false
## 閉じ込める線を可視範囲から余白の内側へ寄せた割合（0-1）。
var _margin_ratio: float = 0.0

var _knockback_vel: Vector3 = Vector3.ZERO
var _knockback_timer: float = 0.0
## 直近に蓄積した被弾ダメージ。poise を超えるとのけぞる。
var _poise_damage: float = 0.0
## 発火済みの増援閾値（adds_hp_ratios の添字）。
var _adds_fired: Array[int] = []
## ガードの再使用待ち（秒）。
var _guard_cooldown_left: float = 0.0
## 現在の構えで受け止めた回数。
var _guard_blocks: int = 0
## 次の ATTACK を反撃（短い予備動作）にする。
var _counter_pending: bool = false
var _current_attack_profile: EnemyAttackProfileType = null
## のけぞり判定に使う、前回の被弾時点の HP。
var _hp_before_hit: float = 0.0
## Hurtbox から通知された、最後に自分へ攻撃を成立させた本体。
var _last_attacker: Node3D = null
## 今回ののけぞりの滞在秒数。通常とノックバックで異なる（_enter_staggered で決める）。
var _stagger_duration_now: float = 0.0


func _ready() -> void:
	_model = get_node_or_null(model_path) as Node3D
	_health = get_node_or_null(health_path) as Health
	_hurtbox = get_node_or_null(hurtbox_path) as Area3D
	_hitbox = get_node_or_null(hitbox_path) as Hitbox
	_sm = get_node_or_null(state_machine_path) as StateMachine
	_despawn_blink = get_node_or_null(despawn_blink_path) as ModelBlink

	if _model != null and model_scene != null:
		_model.add_child(model_scene.instantiate())
	if toon_skin:
		ToonSkin.apply(_model)
	_tint.setup(_model)
	if _despawn_blink != null:
		_despawn_blink.setup(_tint)
	_state_color = color_idle
	_refresh_tint(0.0)
	# Animator は Model を読むので、キャラクターを差し込んだ後に初期化させる。
	_animator = get_node_or_null(animator_path) as NpcAnimator
	if _animator != null:
		for profile: EnemyAttackProfileType in attack_profiles:
			if profile != null and profile.animation_variant != 0:
				_animator.configure_attack_clip(_clip_for_variant(profile.animation_variant),
					profile.clip)
		_animator.setup()

	if _health != null:
		_hp_before_hit = _health.max_hp
		_health.staggered.connect(_on_staggered)
		_health.downed.connect(_on_downed)
		if not adds_hp_ratios.is_empty() and adds_count > 0:
			_health.hp_changed.connect(_on_hp_changed_for_adds)

	if _sm == null:
		push_warning("enemy: StateMachine が無い")
		return
	_sm.add_state(State.SPAWN, &"spawn", _enter_spawn, _physics_spawn, _exit_spawn)
	_sm.add_state(State.APPROACH, &"approach", _enter_approach, _physics_approach)
	_sm.add_state(State.ATTACK, &"attack", _enter_attack, _physics_attack, _exit_attack)
	_sm.add_state(State.STAGGERED, &"staggered", _enter_staggered, _physics_staggered)
	_sm.add_state(State.GUARD, &"guard", _enter_guard, _physics_guard, _exit_guard)
	_sm.add_state(State.DOWNED, &"downed", _enter_downed)
	_sm.state_changed.connect(func(_from: int, to: int) -> void: state_entered.emit(to))
	# 面側の set_belt_bounds() とプレイヤーの登録を待って、次フレームから開始する。
	call_deferred("_start_state_machine")


func _start_state_machine() -> void:
	_resolve_target()
	_sm.start(State.SPAWN)


## 面側から呼ぶ。ベルトの奥行き範囲（レーンの clamp に使う）。
func set_belt_bounds(z_min: float, z_max: float) -> void:
	_belt_z_min = minf(z_min, z_max)
	_belt_z_max = maxf(z_min, z_max)


## HUD がボスバーを出すかどうか。中ボス・ボスの役割スクリプトが true を返す。
func is_boss() -> bool:
	return false


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _poise_damage > 0.0:
		_poise_damage = maxf(_poise_damage - poise_recovery * delta, 0.0)
	if _guard_cooldown_left > 0.0:
		_guard_cooldown_left = maxf(_guard_cooldown_left - delta, 0.0)

	if _sm != null:
		_sm.physics_update(delta)

	# ノックバックは全ステートに優先して水平速度を上書きする。
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity.x = _knockback_vel.x
		velocity.z = _knockback_vel.z
		_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO,
			(knockback_speed / knockback_decay) * delta)

	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	# レーンの外へは出ない（ノックバックで押し出された場合も含む）。
	var clamped_z := clampf(global_position.z, _belt_z_min, _belt_z_max)
	if not is_equal_approx(clamped_z, global_position.z):
		global_position.z = clamped_z
		velocity.z = 0.0
	_clamp_to_screen(delta)
	_update_locomotion_animation()


## 画面に入ったあとは画面外へ出さない。倒れた個体はカメラに押されて滑るので対象外。
##
## 「画面に入った」は余白を含まない可視範囲で判定する。余白の内側で判定すると、
## 距離を取る敵（3面ボスは gun_preferred_distance 4.5m を保つ）はそこまで来ないことが
## あり、判定が立たないまま画面外へ後退できてしまう（実測で 2.56m はみ出したまま戻らない）。
##
## 閉じ込める線は、入った直後は可視範囲そのもので、そこから screen_margin ぶん内側へ
## screen_margin_ramp 秒かけて寄せる。最初から内側の線で閉じ込めると、可視範囲へ入った
## 瞬間に最大 screen_margin ぶん引き戻されて位置が飛ぶ。
func _clamp_to_screen(delta: float) -> void:
	if _sm != null and _sm.current() == State.DOWNED:
		return
	var cam := _find_belt_camera()
	if cam == null:
		return
	var visible_left: float = float(cam.call("left_limit"))
	var visible_right: float = float(cam.call("right_limit"))
	var left: float = visible_left + screen_margin
	var right: float = visible_right - screen_margin
	if left >= right:
		return
	if not _entered_screen:
		if global_position.x < visible_left or global_position.x > visible_right:
			return
		_entered_screen = true
	if screen_margin_ramp > 0.0:
		_margin_ratio = minf(_margin_ratio + delta / screen_margin_ramp, 1.0)
	else:
		_margin_ratio = 1.0
	var low: float = lerpf(visible_left, left, _margin_ratio)
	var high: float = lerpf(visible_right, right, _margin_ratio)
	var x := clampf(global_position.x, low, high)
	if not is_equal_approx(x, global_position.x):
		global_position.x = x
		velocity.x = 0.0


## BeltCamera を探す。グループから一度だけ解決する。
func _find_belt_camera() -> Node3D:
	if _belt_camera != null and is_instance_valid(_belt_camera):
		return _belt_camera
	_belt_camera = null
	var found := get_tree().get_first_node_in_group(&"belt_camera") as Node3D
	if found != null and found.has_method("left_limit") and found.has_method("right_limit"):
		_belt_camera = found
	return _belt_camera


## ロコモーションだけを毎フレーム更新する。攻撃・のけぞり・ダウンの単発クリップは
## 各ステートの進入時に一度だけ再生する。
func _update_locomotion_animation() -> void:
	if _animator == null or not _animator.is_active() or _sm == null:
		return
	match _sm.current():
		State.SPAWN, State.APPROACH:
			_animator.drive_locomotion(Vector2(velocity.x, velocity.z).length())
		State.GUARD:
			# 待機クリップはボクシングの構え。そのままガードの絵になる。
			# 耐え被弾の軽いのけぞり中は上書きせず、出し終えてから構えへ戻す。
			if not _animator.is_one_shot_active():
				_animator.play(NpcAnimator.Clip.IDLE)
		_:
			# 派生役割が追加した移動ステートだけを明示的に駆動する。
			# 未知の全ステートを対象にすると、狙撃・盾などの静止ポーズを壊す。
			if _uses_role_locomotion(_sm.current()):
				_animator.drive_locomotion(Vector2(velocity.x, velocity.z).length())


## 派生役割が専用ステートのlocomotion駆動を宣言する拡張点。
func _uses_role_locomotion(_state: int) -> bool:
	return false


## HUD のゲージに出す表示名。役割スクリプトが上書きする。
## HUD がクラス名で分岐すると役割を増やすたびに UI を触ることになるため、
## 名乗るのは本体側の責任にする。
func display_name() -> String:
	return "敵"


## 現在のステート（テスト・デバッグ用）。
func current_state() -> int:
	return _sm.current() if _sm != null else State.SPAWN


# --- SPAWN ----------------------------------------------------------------

## 画面外に出現し、無敵のまま画面内へ歩き込む。
func _enter_spawn() -> void:
	_set_color(color_idle)
	_resolve_target()
	_choose_side()
	_lane_offset = randf_range(-approach_jitter, approach_jitter)
	if _hurtbox != null:
		_hurtbox.set_deferred("monitorable", false)


func _physics_spawn(delta: float) -> void:
	if _target == null:
		_resolve_target()
	if _target != null:
		var dx := _target.global_position.x - global_position.x
		velocity.x = signf(dx) * chase_speed if absf(dx) > 0.1 else 0.0
		velocity.z = 0.0
		_face_target_x(delta)
	if _sm.time_in_state() >= spawn_walk_in:
		_sm.transition_to(State.APPROACH)


func _exit_spawn() -> void:
	if _hurtbox != null:
		_hurtbox.set_deferred("monitorable", true)


## 立つ側を決める。基本は出現した側。flank_chance で反対側へ回り込む。
func _choose_side() -> void:
	if _target == null:
		_side = 1
		return
	_side = 1 if global_position.x >= _target.global_position.x else -1
	if randf() < flank_chance:
		_side = -_side


# --- APPROACH -------------------------------------------------------------

func _enter_approach() -> void:
	_set_color(color_alert)
	_on_approach_entered()


## 役割スクリプトの拡張点。true を返した場合、共通の接近処理をそのフレームは行わない
## （突進など、役割固有ステートへ遷移したとき）。
func _role_approach_override(_delta: float) -> bool:
	return false


func _physics_approach(delta: float) -> void:
	if _target == null:
		_resolve_target()
		if _target == null:
			_stop_horizontal(delta)
			return
	if _role_approach_override(delta):
		return

	var target_x := _target.global_position.x
	var target_z := _target.global_position.z
	var dx := target_x - global_position.x
	var dz := target_z - global_position.z
	var in_depth := absf(dz) <= attack_depth_tolerance

	# 段が揃い、射程内で、クールダウン明けなら殴る。
	if in_depth and absf(dx) <= attack_range and _cooldown_left <= 0.0:
		_sm.transition_to(State.ATTACK)
		return

	# 射程付近でクールダウン中。これ以上踏み込まず間合いを保つ。
	if _cooldown_left > 0.0 and in_depth and absf(dx) <= attack_keep_range:
		_stop_horizontal(delta)
		_face_target_x(delta)
		return

	# 目標: プレイヤーの _side 側、攻撃射程の少し内側。レーンはプレイヤーに合わせる。
	var goal_x := target_x + float(_side) * attack_range * 0.85
	var goal_z := clampf(target_z + _lane_offset, _belt_z_min, _belt_z_max)
	# 目標がプレイヤーの向こう側なら、プレイヤーの正面を横切らずに別レーンで追い越す。
	var crossing := (global_position.x < target_x and target_x < goal_x) \
		or (goal_x < target_x and target_x < global_position.x)
	if crossing:
		var lane_sign := 1.0 if _lane_offset >= 0.0 else -1.0
		var cross_z := target_z + lane_sign * cross_lane_offset
		if cross_z < _belt_z_min or cross_z > _belt_z_max:
			cross_z = target_z - lane_sign * cross_lane_offset
		goal_z = clampf(cross_z, _belt_z_min, _belt_z_max)

	var to_x := goal_x - global_position.x
	var to_z := goal_z - global_position.z
	if absf(to_x) > 0.1:
		velocity.x = signf(to_x) * chase_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, stop_decel * delta)
	if absf(to_z) > 0.05:
		velocity.z = signf(to_z) * minf(depth_align_speed, absf(to_z) / maxf(delta, 0.001))
	else:
		velocity.z = 0.0
	_face_target_x(delta)


## 役割スクリプト向けの APPROACH 進入拡張点。
func _on_approach_entered() -> void:
	pass


# --- ATTACK ---------------------------------------------------------------

func _enter_attack() -> void:
	_set_color(color_telegraph)
	_hitbox_open = false
	_stop_horizontal_immediate()
	_current_attack_profile = _choose_attack_profile()
	# クリップ長を予備動作＋判定＋硬直に合わせ、当たる瞬間と絵をずらさない。
	if _animator != null and _animator.is_active():
		var clip: int = _current_attack_clip()
		var total: float = _current_telegraph() + _current_attack_active() \
			+ _current_attack_recovery()
		var length: float = _animator.clip_length(clip)
		var scale: float = length / total if total > 0.0 and length > 0.0 else 1.0
		_animator.play(clip, 0.05, scale, true)


## 反撃中は予備動作を短くする。ガードで受け止めた直後の一撃なので、
## 通常の振りかぶりだと殴り返される前に潰される。
func _current_telegraph() -> float:
	if _current_attack_profile != null:
		return _current_attack_profile.telegraph
	return counter_telegraph if _counter_pending else attack_telegraph


func _current_attack_active() -> float:
	return _current_attack_profile.active \
		if _current_attack_profile != null else attack_active


func _current_attack_recovery() -> float:
	return _current_attack_profile.recovery \
		if _current_attack_profile != null else attack_recovery


func _current_attack_clip() -> int:
	if _current_attack_profile == null:
		return NpcAnimator.Clip.ATTACK
	return _clip_for_variant(_current_attack_profile.animation_variant)


func _clip_for_variant(variant: int) -> int:
	match variant:
		1:
			return NpcAnimator.Clip.ATTACK_JAB
		2:
			return NpcAnimator.Clip.ATTACK_HOOK
	return NpcAnimator.Clip.ATTACK


func _choose_attack_profile() -> EnemyAttackProfileType:
	if attack_profiles.is_empty() or _target == null:
		return null
	var distance := _flat_distance_to(_target.global_position)
	var candidates: Array[EnemyAttackProfileType] = []
	for profile: EnemyAttackProfileType in attack_profiles:
		if profile == null or distance < profile.min_distance \
				or distance > profile.max_distance:
			continue
		var clip: int = _clip_for_variant(profile.animation_variant)
		if _animator == null or _animator.has_clip(clip):
			candidates.append(profile)
	if candidates.is_empty():
		return null
	return candidates[randi_range(0, candidates.size() - 1)]


func _physics_attack(delta: float) -> void:
	var t := _sm.time_in_state()
	# export の attack_telegraph を隠さないよう別名にする（反撃では短くなる）。
	var telegraph := _current_telegraph()
	var active_end := telegraph + _current_attack_active()
	var recovery_end := active_end + _current_attack_recovery()

	if t < telegraph:
		# 予備動作。向きだけ合わせて踏みとどまる。
		_stop_horizontal(delta)
		_face_target_x(delta)
		return

	if t < active_end:
		# 判定窓。開くのは1回だけ（Hitbox 側が二重ヒットを防ぐ）。
		if not _hitbox_open:
			_hitbox_open = true
			_set_color(color_alert)
			_open_hitbox()
			_lunge_forward()
		return

	if _hitbox_open:
		_close_hitbox()

	if t < recovery_end:
		# 硬直。次の攻撃までここで足を止める。
		_stop_horizontal(delta)
		return

	_cooldown_left = attack_cooldown
	_sm.transition_to(State.APPROACH)


func _exit_attack() -> void:
	_close_hitbox()
	_counter_pending = false
	_current_attack_profile = null


# --- STAGGERED ------------------------------------------------------------

func _enter_staggered() -> void:
	_close_hitbox()
	_set_color(color_alert)
	_stagger_duration_now = stagger_duration
	if _animator != null and _animator.is_active():
		# ノックバックを伴う被弾は大きくのけぞらせる。連続被弾では頭から出し直す。
		var clip: int = NpcAnimator.Clip.HIT
		var speed: float = 1.0
		var start: float = hit_clip_lead_in
		if _knockback_timer > 0.0 and _animator.has_clip(NpcAnimator.Clip.KNOCKBACK):
			clip = NpcAnimator.Clip.KNOCKBACK
			start = 0.0
			_stagger_duration_now = knockback_stagger_duration
			# 1.0 秒のクリップを滞在時間で全編見せる。
			var length: float = _animator.clip_length(clip)
			if length > 0.0 and _stagger_duration_now > 0.0:
				speed = length / _stagger_duration_now
		_animator.play(clip, 0.05, speed, true, start)


func _physics_staggered(delta: float) -> void:
	# のけぞり中は自走しない（ノックバックは _physics_process 側が上書きする）。
	_stop_horizontal(delta)
	if _sm.time_in_state() >= _stagger_duration_now:
		_resolve_target()
		_sm.transition_to(State.APPROACH)


# --- GUARD ----------------------------------------------------------------

## Hitbox の汎用方向防御フック。構えている間だけ、正面扇形からの近接を弾く。
## 役割スクリプト（リーダーの盾）は override して super() と OR で合成する。
func blocks_hit_from(attacker_position: Vector3) -> bool:
	if _sm == null or _sm.current() != State.GUARD:
		return false
	if not _is_in_front_arc(attacker_position, guard_arc_deg):
		return false
	_guard_blocks += 1
	# 受け止めた手応え。ダメージは通っていないので Hurtbox は呼ばれない。
	flash_hit()
	if _guard_blocks >= counter_after_blocks:
		# 待たずに反撃へ。ガードで固まり続けると、今度は殴れないだけの置物になる。
		_leave_guard_to_counter()
	return true


func _enter_guard() -> void:
	_close_hitbox()
	_guard_blocks = 0
	_stop_horizontal_immediate()


func _physics_guard(delta: float) -> void:
	_stop_horizontal(delta)
	_face_target_x_at_speed(delta, guard_face_speed)
	if _sm.time_in_state() < guard_duration:
		return
	if _guard_blocks > 0:
		_leave_guard_to_counter()
		return
	# 空振りのガード。接近へ戻す。
	_sm.transition_to(State.APPROACH)


func _exit_guard() -> void:
	_guard_cooldown_left = guard_cooldown


## 受け止めたあとの行き先を決める。反撃するか、追跡へ戻るか。
func _leave_guard_to_counter() -> void:
	if _sm == null or _sm.current() != State.GUARD:
		return
	if randf() < counter_chance and _target != null \
			and _flat_distance_to(_target.global_position) <= attack_keep_range:
		_counter_pending = true
		_sm.transition_to(State.ATTACK)
		return
	_sm.transition_to(State.APPROACH)


## 被弾を耐えたときに構えるか決める。
func _try_enter_guard() -> void:
	if not guard_enabled or _sm == null or _guard_cooldown_left > 0.0:
		return
	match _sm.current():
		State.APPROACH, State.ATTACK:
			pass
		_:
			return
	if _target == null or _flat_distance_to(_target.global_position) > attack_keep_range:
		return
	if randf() >= guard_chance:
		return
	_sm.transition_to(State.GUARD)


## 正面 arc_deg（全角）の扇形に相手がいるか。
func _is_in_front_arc(point: Vector3, arc_deg: float) -> bool:
	var toward := point - global_position
	toward.y = 0.0
	if toward.length_squared() <= 0.0:
		return false
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var half_arc := deg_to_rad(clampf(arc_deg, 0.0, 360.0) * 0.5)
	return forward.dot(toward.normalized()) >= cos(half_arc)


# --- DOWNED ---------------------------------------------------------------

func _enter_downed() -> void:
	_close_hitbox()
	_stop_horizontal_immediate()
	# 撃破の一撃は Hurtbox が「ノックバック → ダメージ」の順で流すので、ダウンが
	# 確定した時点では受けたばかりのノックバックが残っている。_physics_process の
	# ノックバックは全ステートに優先して velocity を上書きし、DOWNED は物理更新を
	# 持たない（velocity を戻す側がいない）ため、ここで消さないと倒れたまま運ばれる。
	_knockback_vel = Vector3.ZERO
	_knockback_timer = 0.0
	# 予備動作の色のまま倒れないよう、ステート色を通常へ戻す。
	_set_color(color_idle)
	# Hurtbox 自身が他の Area を監視する必要はないため monitoring は切る一方、
	# プレイヤーの Hitbox 側から検出できるよう monitorable だけを残す。Health は
	# ダウン中の通常 take_hit() を弾き、Hurtbox も再ロック済みの追い打ちだけを
	# 振り分けるため、他人の通常攻撃がダメージへ戻ることはない。
	# ダウンは物理信号中に確定するため、変更は物理ステップ末尾へ遅延する。
	if _hurtbox != null:
		_hurtbox.set_deferred("monitoring", false)
		_hurtbox.set_deferred("monitorable", false)
	# 倒れた本体は他の敵やプレイヤーの移動を妨げない。
	set_deferred("collision_layer", 0)
	# しばらく倒れたままにしてから消える。
	if despawn_delay > 0.0:
		if _despawn_blink != null:
			_despawn_blink.begin(despawn_delay)
		get_tree().create_timer(despawn_delay).timeout.connect(_despawn)
	if _animator != null and _animator.is_active():
		# 倒れ込みはクリップが持つ。本体まで倒すと二重に倒れるので回さない。
		_animator.play(NpcAnimator.Clip.DOWN, 0.1, 1.0, true)
		return
	# プリミティブ表示のままの個体は従来どおり固定ポーズで倒す
	# （ラグドールはコンテスト版では扱わない）。
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", deg_to_rad(fall_angle_deg), fall_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# --- Health からの通知 -----------------------------------------------------

## 増援の閾値を通過したら1回だけ呼ぶ。倒れた後は呼ばない。
func _on_hp_changed_for_adds(current: float, maximum: float) -> void:
	if maximum <= 0.0 or _health == null or _health.is_downed():
		return
	for i in range(adds_hp_ratios.size()):
		if _adds_fired.has(i):
			continue
		if current <= maximum * adds_hp_ratios[i]:
			_adds_fired.append(i)
			adds_requested.emit(adds_count)


## Health からのよろけ通知。ここで「のけぞらせるか」を決める。
## Health は被弾のたびに発火するだけで、耐えるかどうかは受け手の判断にする。
func _on_staggered() -> void:
	if _sm == null or _sm.current() == State.DOWNED:
		return
	# Health は信号にダメージ量を載せないので、HP の差分から取る。
	var hp_now: float = _health.current_hp() if _health != null else 0.0
	var taken: float = maxf(_hp_before_hit - hp_now, 0.0)
	_hp_before_hit = hp_now

	if not staggers:
		return

	if poise > 0.0:
		_poise_damage += taken
		if _poise_damage < poise:
			# 耐える。行動は中断しないが、軽いのけぞりを差し込んで手応えを見せる。
			# 攻撃中は差し込まない（振りかぶり＝予備動作の絵を消すとかわせなくなる）。
			if _animator != null and _animator.is_active() \
					and _animator.has_clip(NpcAnimator.Clip.HIT_SMALL) \
					and _sm.current() != State.ATTACK:
				_animator.play_one_shot(NpcAnimator.Clip.HIT_SMALL,
					small_react_duration, small_react_start)
			# 耐えた直後は構えに入る余地を作る（殴られっぱなしにしない）。
			_try_enter_guard()
			return
		_poise_damage = 0.0
	# 連続被弾で滞在時間を延ばす（force=true で再進入）。
	_sm.transition_to(State.STAGGERED, true)


func _on_downed(_lethal: bool) -> void:
	if _sm == null or _sm.current() == State.DOWNED:
		return
	RunState.enemies_downed += 1
	RunState.add_defeat_score()
	Sfx.play(&"enemy_down")
	_sm.transition_to(State.DOWNED)
	defeated.emit(self)


func _despawn() -> void:
	if is_inside_tree():
		queue_free()


# --- Hurtbox からの呼び出し -------------------------------------------------

## Hurtbox から具体的な攻撃種別に依存せず、最後の加害者を受け取る。
func record_attacker(attacker: Node3D) -> void:
	_last_attacker = attacker

## direction は攻撃者→自分の水平方向。
func receive_knockback(direction: Vector3, strength: float) -> void:
	if _sm != null and _sm.current() == State.DOWNED:
		return
	if strength <= 0.0:
		return
	var d := direction
	d.y = 0.0
	if d.length() < 0.001:
		return
	_knockback_vel = d.normalized() * knockback_speed * clampf(strength / 5.0, 0.5, 2.0)
	_knockback_timer = knockback_decay


## 被弾フラッシュ。白を重ねて 0 へ抜く。
func flash_hit() -> void:
	if not _tint.is_ready():
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(_apply_flash_mix, 1.0, 0.0, flash_duration)


func _apply_flash_mix(amount: float) -> void:
	_refresh_tint(amount)


## 被せ色を更新する。**被弾フラッシュのときだけ**白を重ねる。
## ステートを色で塗り分けると、複数の色（役割・警戒・予備動作・ダウン）が
## 重なって何を示しているのか読めなくなるため、色による状態表示はやめた。
## 警戒と予備動作はアニメーション（振り向き・追跡・攻撃の振りかぶり）で伝える。
func _refresh_tint(flash_amount: float) -> void:
	if not _tint.is_ready():
		return
	_tint.apply(flash_color, flash_amount * flash_tint_alpha)


# --- 内部ヘルパ -------------------------------------------------------------

func _resolve_target() -> void:
	_target = get_tree().get_first_node_in_group(target_group) as Node3D


func _flat_distance_to(point: Vector3) -> float:
	var d := point - global_position
	return Vector2(d.x, d.z).length()


## プレイヤーのいる側（±X）へ向く。Z 成分は無視し、斜めを向かない。
func _face_target_x(delta: float) -> void:
	_face_target_x_at_speed(delta, rotation_speed)


func _face_target_x_at_speed(delta: float, face_speed: float) -> void:
	if _target == null:
		return
	var dx := _target.global_position.x - global_position.x
	if absf(dx) < 0.01:
		return
	_face_direction_at_speed(Vector3(signf(dx), 0.0, 0.0), delta, face_speed)


func _face_position(point: Vector3, delta: float) -> void:
	_face_position_at_speed(point, delta, rotation_speed)


## 役割ステートだけ向き直り速度を差し替えるための拡張点。
## 共通ステートは _face_position() を通して従来の rotation_speed を使う。
func _face_position_at_speed(point: Vector3, delta: float, face_speed: float) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() < 0.01:
		return
	_face_direction_at_speed(d.normalized(), delta, face_speed)


## 前方は -Z。atan2(x, z) の結果に π を足すと -Z 向きのヨーになる。
func _face_direction(direction: Vector3, delta: float) -> void:
	_face_direction_at_speed(direction, delta, rotation_speed)


func _face_direction_at_speed(direction: Vector3, delta: float, face_speed: float) -> void:
	var target_yaw := atan2(direction.x, direction.z) + PI
	rotation.y = lerp_angle(rotation.y, target_yaw, face_speed * delta)


func _stop_horizontal(delta: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z)
	horizontal = horizontal.move_toward(Vector2.ZERO, stop_decel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y


func _stop_horizontal_immediate() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _lunge_forward() -> void:
	var forward := -global_transform.basis.z
	var speed: float = _current_attack_profile.lunge_speed \
		if _current_attack_profile != null else attack_lunge_speed
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed


func _open_hitbox() -> void:
	if _hitbox == null:
		return
	var damage: float = _current_attack_profile.damage \
		if _current_attack_profile != null else attack_damage
	var knockback: float = _current_attack_profile.knockback \
		if _current_attack_profile != null else attack_knockback
	if attack_damage_override >= 0.0:
		damage = attack_damage_override
	_hitbox.configure(damage, knockback, false)
	_hitbox.activate()


## 判定を閉じる。よろけ・ダウンは被弾処理（信号）の最中に確定するため、
## 常に deferred 版を使う（判定自体は即座に閉じる）。
func _close_hitbox() -> void:
	_hitbox_open = false
	if _hitbox != null:
		_hitbox.deactivate_deferred()


## ステート色を記録する。描画には使わない（_refresh_tint 参照）。役割スクリプトと
## テストが現在ステートの識別に読むため、値の管理だけ従来どおり残している。
func _set_color(color: Color) -> void:
	_state_color = color
