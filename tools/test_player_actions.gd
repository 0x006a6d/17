extends Node
## 回避・△必殺と、範囲攻撃のダメージ表示経路を検証。
##   (1) dodge で無敵になり（Hurtbox monitorable=false）、後方へ動く
##   (2) special で自 HP を消費し、踏み込み＋全方位＋正面延長へダメージ
##   (3) special の自傷は被弾扱いにしない（やられた掛け声を鳴らさない）
const STAGE := "res://levels/belt_test.tscn"
const ENEMY := "res://actors/enemy/enemy.tscn"
const ACTION_END_SETTLE_FRAMES: int = 2
## 回避の観測時刻。無敵が切れる前に、後退量が読める位置を取る。
const DODGE_OBSERVE_IFRAME_RATIO: float = 0.8
## 入力は _unhandled_input 経由で届くため、移動開始は押した次の物理フレームになる。
## 実測とのずれはこのフレーム数ぶんの移動量まで許す。
const DODGE_INPUT_LATENCY_FRAMES: float = 2.0
const DODGE_PRESS_FRAME: int = 8
const SPECIAL_LUNGE_DISTANCE_TOLERANCE: float = 0.08
const SPECIAL_EARLY_OBSERVE_FRAME: int = 12
const SPECIAL_KICK_VFX_OBSERVE_FRAME: int = 48
const SPECIAL_IMPACT_OBSERVE_FRAME: int = 60
const SPECIAL_MIN_EARLY_ADVANCE: float = 0.10
const SPECIAL_REAR_OFFSET: float = 1.0
const SPECIAL_RANGE_MARGIN: float = 0.5
var _pass := 0
var _fail := 0
var _stage: Node3D
var _player: Node3D
var _action: Node
var _melee: Node
var _special_vfx: Node
var _hurtbox: Area3D
var _f := 0
var _phase := 0
var _behind: Node3D
var _behind_h: Health
var _side: Node3D
var _side_h: Health
var _far_front: Node3D
var _far_front_h: Health
var _x0 := 0.0
## 回避明けを待つフレーム。入力ロックとクールダウンが明けるまで待つ。
## 回避の継続はモーション実尺に合わせて @export で持つため、固定値ではなく
## dodge_duration + dodge_cooldown から物理フレーム数へ換算する。
var _dodge_recover_frame: int = 0
## 回避を観測するフレームと、そのときの後退量の理論値（m）。どちらも @export から求める。
var _dodge_observe_frame: int = 0
var _dodge_expected_dx: float = 0.0
var _dodge_dx_tolerance: float = 0.0
var _behind_feedback: Array[float] = []
## special の自傷で被弾（staggered）が飛ぶと、やられた掛け声が鳴ってしまう。
var _player_staggered: bool = false
var _far_front_feedback: Array[float] = []
func _ready() -> void:
	RunState.reset()
	_stage = (load(STAGE) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node("Player")
	for n in ["Dummy1","Dummy2","Dummy3"]:
		(_stage.get_node(n) as Node3D).global_position = Vector3(60,0.2,0)
	_action = _player.get_node("PlayerAction")
	var player_health := _player.get_node(^"Health") as Health
	player_health.staggered.connect(func() -> void: _player_staggered = true)
	_melee = _player.get_node("PlayerMelee")
	_special_vfx = _player.get_node("DropkickVfx3D")
	_special_vfx.connect("impact_spawned", _on_special_impact_spawned)
	_hurtbox = _player.get_node("Hurtbox")
	# 背後 1.0m、側面（段ずれ）1.0m
	_behind = _spawn(Vector3(3.0,0.2,0)); _behind_h = _behind.get_node("Health")
	_side = _spawn(Vector3(5.0,0.2,2.6)); _side_h = _side.get_node("Health")
	_far_front = _spawn(Vector3(8.5,0.2,0)); _far_front_h = _far_front.get_node("Health")
	# 厳密な数値を見るので、この検証では端数の揺らぎを切る。
	for h: Health in [_behind_h, _side_h, _far_front_h]:
		h.damage_variance = 0.0
	(_behind.get_node("DamageFeedback3D") as DamageFeedback3D).feedback_spawned.connect(
		_on_behind_feedback_spawned)
	(_far_front.get_node("DamageFeedback3D") as DamageFeedback3D).feedback_spawned.connect(
		_on_far_front_feedback_spawned)
	_player.global_position = Vector3(4.0,0.2,0)
	_player.set("_facing", 1)
	var dodge_block: float = float(_player.get("dodge_duration")) \
		+ float(_player.get("dodge_cooldown"))
	_dodge_recover_frame = ceili(dodge_block * float(Engine.physics_ticks_per_second)) \
		+ ACTION_END_SETTLE_FRAMES
	_setup_dodge_expectation()
func _spawn(pos: Vector3) -> Node3D:
	var e := (load(ENEMY) as PackedScene).instantiate(); _stage.add_child(e)
	e.global_position = pos; e.set_physics_process(false)
	return e
## 回避は初速 2 * dodge_distance / dodge_duration から一定減速で dodge_duration の
## 終わりに止まる。観測時刻の後退量はその積分で決まるので、固定値ではなく実装の
## @export から求める。
func _setup_dodge_expectation() -> void:
	var ticks: float = float(Engine.physics_ticks_per_second)
	var duration: float = float(_player.get("dodge_duration"))
	var distance: float = float(_player.get("dodge_distance"))
	var iframes: float = float(_player.get("dodge_iframes"))
	var observe_frames: int = maxi(1,
		floori(iframes * DODGE_OBSERVE_IFRAME_RATIO * ticks))
	_dodge_observe_frame = DODGE_PRESS_FRAME + observe_frames
	var launch_speed: float = float(_player.call("_dodge_launch_speed"))
	var elapsed: float = float(observe_frames) / ticks
	_dodge_expected_dx = launch_speed * elapsed \
		- launch_speed * elapsed * elapsed / (2.0 * duration)
	_dodge_dx_tolerance = launch_speed * DODGE_INPUT_LATENCY_FRAMES / ticks


func _act(a: String) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = true
	Input.parse_input_event(e)
func _physics_process(_d: float) -> void:
	_f += 1
	match _phase:
		0:
			if _f == DODGE_PRESS_FRAME:
				_x0 = _player.global_position.x
				_act("dodge")
			if _f == _dodge_observe_frame:
				var dx: float = _player.global_position.x - _x0
				_assert("(1) 回避中は無敵（Hurtbox monitorable=false）", not _hurtbox.monitorable)
				_assert("(1) 回避で後方(-X)へ動く (dx=%.2f / 理論値 -%.2f)" % [
					dx, _dodge_expected_dx],
					dx < 0.0 and absf(absf(dx) - _dodge_expected_dx) <= _dodge_dx_tolerance)
				_phase = 1; _f = 0
		1:
			# 回避明けまで待つ
			if _f == _dodge_recover_frame:
				_player.global_position = Vector3(4.0,0.2,0)
			var special_start_frame: int = _dodge_recover_frame + ACTION_END_SETTLE_FRAMES
			if _f >= special_start_frame and not bool(_melee.call("is_action_playing")):
				# special: 周囲全部
				var php := (_player.get_node("Health") as Health).current_hp()
				set_meta("php", php)
				var start_x: float = _player.global_position.x
				var impact_x: float = start_x + float(_player.call("facing")) \
					* float(_action.get("special_lunge_distance"))
				var radius: float = float(_action.get("special_radius"))
				var front_distance: float = float(_action.get("special_front_distance"))
				var front_probe_distance: float = (radius + front_distance) * 0.5
				var side_offset: float = maxf(radius,
					float(_action.get("special_front_width")) * 0.5) + SPECIAL_RANGE_MARGIN
				_behind.global_position = Vector3(impact_x - SPECIAL_REAR_OFFSET, 0.2, 0.0)
				_far_front.global_position = Vector3(impact_x + front_probe_distance, 0.2, 0.0)
				_side.global_position = Vector3(impact_x, 0.2, side_offset)
				set_meta("behind_before_special", _behind_h.current_hp())
				set_meta("side_before_special", _side_h.current_hp())
				set_meta("far_front_before_special", _far_front_h.current_hp())
				set_meta("special_start_x", start_x)
				_act("special")
				_phase = 2; _f = 0
		2:
			if _f == 4:
				var php := (_player.get_node("Health") as Health).current_hp()
				_assert("(2) special で自 HP を消費 (%.0f→%.0f)" % [float(get_meta("php")), php],
					php < float(get_meta("php")))
				_assert("(3) special の自傷では被弾扱いにしない", not _player_staggered)
				_assert("(2) special の判定は蹴りの接触前には出ない",
					is_equal_approx(_behind_h.current_hp(), float(get_meta("behind_before_special"))))
				_assert("(2) △ドロップキックは助走中にVFXを出さない",
					(_special_vfx.call("trail_endpoint") as Vector3).is_zero_approx())
			if _f == SPECIAL_EARLY_OBSERVE_FRAME:
				var early_advance: float = _player.global_position.x \
					- float(get_meta("special_start_x"))
				_assert("(2) special は助走前半から前進する (%.3fm)" % early_advance,
					early_advance >= SPECIAL_MIN_EARLY_ADVANCE)
			if _f == SPECIAL_KICK_VFX_OBSERVE_FRAME:
				var live_kick := _special_vfx.get_node_or_null(
					^"DropkickStage3KickTrail")
				var sampled_foot := _special_vfx.call("trail_endpoint") as Vector3
				var effect_foot := live_kick.call("latest_position") as Vector3 \
					if live_kick != null else Vector3.INF
				_assert("(2) ドロップキックVFXは助走後の蹴り動作中から表示する",
					live_kick != null and not bool(get_meta("special_vfx_impact", false)))
				_assert("(2) ドロップキックVFXの先端は命中前も実蹴り足へ追従する",
					live_kick != null and effect_foot.distance_to(sampled_foot) < 0.02)
				var live_axis := _special_vfx.call("live_kick_axis") as Vector3
				_assert("(2) ドロップキックVFXの向きは横固定せず実下腿軸へ追従する",
					absf(live_axis.y) > 0.10)
			if _f == SPECIAL_IMPACT_OBSERVE_FRAME:
				var advance: float = _player.global_position.x \
					- float(get_meta("special_start_x"))
				var expected_advance: float = float(_action.get("special_lunge_distance"))
				_assert("(2) special が前方へ踏み込む (%.3fm / %.3fm)" % [
					advance, expected_advance],
					absf(advance - expected_advance) <= SPECIAL_LUNGE_DISTANCE_TOLERANCE)
				_assert("(2) special で周囲の敵にダメージ（背後の敵 HP=%.0f）" % _behind_h.current_hp(),
					_behind_h.current_hp() < float(get_meta("behind_before_special")))
				_assert("(2) special の正面延長が半径外の敵へ届く (HP=%.0f)" %
					_far_front_h.current_hp(), _far_front_h.current_hp()
					< float(get_meta("far_front_before_special")))
				_assert("(2) special の正面幅外には届かない (HP=%.0f)" % _side_h.current_hp(),
					is_equal_approx(_side_h.current_hp(), float(get_meta("side_before_special"))))
				var special_damage: float = float(_action.get("special_damage"))
				_assert("(2) special の全方位実ダメージが DamageFeedback3D へ届く",
					_has_feedback(_behind_feedback, special_damage))
				_assert("(2) special の正面延長実ダメージが DamageFeedback3D へ届く",
					_has_feedback(_far_front_feedback, special_damage))
				_assert("(2) 実ダメージと同じフレームで大範囲爆発が発生する",
					bool(get_meta("special_vfx_impact", false)))
				_assert("(2) 接触前の蹴り区間だけ実ボーン軌道を採取する",
					not (_special_vfx.call("trail_endpoint") as Vector3).is_zero_approx())
				_assert("(2) 爆発の地面円半径が実ダメージ半径と一致する (%.2fm)" %
					float(_special_vfx.call("burst_radius")),
					is_equal_approx(float(_special_vfx.call("burst_radius")),
						float(_action.get("special_radius"))))
				_finish()


func _on_special_impact_spawned(_center: Vector3, radius: float) -> void:
	set_meta("special_vfx_impact", true)
	set_meta("special_vfx_radius", radius)
	var kick_trail := _special_vfx.get_node_or_null(^"DropkickStage3KickTrail")
	_assert("(2) ドロップキック接触は通常キック3段目と同じ太い素材スタックを使う",
		kick_trail != null \
		and kick_trail.get_node_or_null(^"KickImpactPlumeSmoke") != null \
		and kick_trail.get_node_or_null(^"KickTrailLightningOuter") != null \
		and kick_trail.get_node_or_null(^"KickFootFlashCore") != null)
	var ground_burst := _special_vfx.get_node_or_null(^"DropkickImpactBurst")
	_assert("(2) 地面衝撃は黒芯・黄橙・白熱芯の三層亀裂を使う",
		ground_burst != null \
		and ground_burst.get_node_or_null(^"GroundCrackBlackBody") != null \
		and ground_burst.get_node_or_null(^"GroundLightningCracks") != null \
		and ground_burst.get_node_or_null(^"GroundCrackWhiteCore") != null)
	_assert("(2) 地面衝撃に黄白い主雷と青白い枝雷を同時に出す",
		ground_burst != null \
		and ground_burst.get_node_or_null(^"ImpactLightningBlackBody") != null \
		and ground_burst.get_node_or_null(^"ImpactLightningAmber") != null \
		and ground_burst.get_node_or_null(^"ImpactLightningIvoryCore") != null \
		and ground_burst.get_node_or_null(^"OuterLightningBlue") != null \
		and ground_burst.get_node_or_null(^"OuterLightningWhiteCore") != null)


func _on_behind_feedback_spawned(amount: float, _impact_position: Vector3) -> void:
	_behind_feedback.append(amount)


func _on_far_front_feedback_spawned(amount: float, _impact_position: Vector3) -> void:
	_far_front_feedback.append(amount)


func _has_feedback(values: Array[float], expected: float) -> bool:
	for value: float in values:
		if is_equal_approx(value, expected):
			return true
	return false


func _assert(l: String, ok: bool) -> void:
	if ok: _pass += 1; print("[PASS] "+l)
	else: _fail += 1; print("[FAIL] "+l)
func _finish() -> void:
	set_physics_process(false)
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)
