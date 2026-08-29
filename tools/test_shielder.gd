extends Node

## 4面ボス（Shielder）と人質（Hostage）の検証。
##   godot --path . --headless res://tools/test_shielder.tscn
##
##   (1) 開始時から人質を保持し（SHIELDED）、正面の近接は弾かれる（HP 不変・hit_blocked）
##   (2) 背面からの近接は通る（HP 減少）。3 回当てると人質を放し、人質は SEATED に戻る
##   (3) 人質は Health / Hurtbox を持たず、どの判定でも HP の概念が無い
##   (4) Shielder を倒すと defeated が出る。人質は放されている
##   (5) NikeSkin が人質のヘアピン（NikeChanKazari）のサーフェスを 1 つ以上隠し、
##       シャツは差し替えていない（recolor_shirt=false）

const STAGE := "res://levels/belt_test.tscn"
const SHIELDER := "res://actors/enemy/roles/shielder.tscn"
const HOSTAGE := "res://actors/hostage/hostage.tscn"
const MAX_FRAMES := 2400

var _pass: int = 0
var _fail: int = 0
var _stage: Node3D = null
var _player: Node3D = null
var _boss: Node3D = null
var _boss_health: Health = null
var _hostage: Node3D = null
var _frames: int = 0
var _phase: int = 0
var _phase_started: int = 0
var _blocked: int = 0
var _landed: int = 0
var _defeated: int = 0
var _hits_done: int = 0


func _ready() -> void:
	print("=== 4面ボス（盾）と人質 検証開始 ===")
	RunState.reset()
	_stage = (load(STAGE) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node_or_null("Player") as Node3D
	for n in ["Dummy1", "Dummy2", "Dummy3"]:
		var d := _stage.get_node_or_null(n) as Node3D
		if d != null:
			d.global_position = Vector3(50.0, 0.2, 0.0)
	var camera := _stage.get_node_or_null("BeltCamera")
	if camera != null:
		camera.call("lock_at", 10.0)
	_hostage = (load(HOSTAGE) as PackedScene).instantiate() as Node3D
	_stage.add_child(_hostage)
	_hostage.global_position = Vector3(11.0, 0.2, 0.0)
	_boss = (load(SHIELDER) as PackedScene).instantiate() as Node3D
	_stage.add_child(_boss)
	_boss.global_position = Vector3(12.0, 0.2, 0.0)
	# 正面を -X（プレイヤー側）へ向ける。前方は -Z なので Y 回転 +90°。
	_boss.rotation.y = PI * 0.5
	_boss_health = _boss.get_node_or_null("Health") as Health
	_boss.connect("defeated", func(_e: Node3D) -> void: _defeated += 1)
	var hitbox := _player.get_node_or_null("Model/MeleeHitbox") as Hitbox
	hitbox.hit_blocked.connect(func(_t: Node3D) -> void: _blocked += 1)
	hitbox.hit_landed.connect(func(_t: Node3D) -> void: _landed += 1)
	_player.global_position = Vector3(10.0, 0.2, 0.0)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > MAX_FRAMES:
		_assert("全ケースが MAX_FRAMES 内に完了した (phase=%d)" % _phase, false)
		_finish()
		return
	if _frames < 10:
		return
	var local := _frames - _phase_started
	match _phase:
		0:
			_assert("(1) 開始時から人質を保持している (state=%d)" % int(_hostage.call("current_state")),
				bool(_hostage.call("is_shielded")))
			_assert("(1) Shielder が SHIELD ステートにいる",
				int(_boss.call("current_state")) == Shielder.SHIELD)
			_assert("(3) 人質は Health を持たない", _hostage.get_node_or_null("Health") == null)
			_assert("(3) 人質は Hurtbox を持たない", _hostage.get_node_or_null("Hurtbox") == null)
			var skin := _hostage.get_node_or_null("NikeSkin")
			_assert("(5) NikeSkin がヘアピンの三角形を切り出した (%d)" %
				int(skin.call("cut_triangle_count")),
				int(skin.call("cut_triangle_count")) >= 100)
			_assert("(5) サーフェス単位では何も隠していない（シュシュ・イヤリングは残る）",
				int(skin.call("hidden_surface_count")) == 0)
			_assert("(5) 人質のシャツは差し替えない (%d)" %
				int(skin.call("recolored_surface_count")),
				int(skin.call("recolored_surface_count")) == 0)
			# 正面（-X 側）で殴る。人質が boss の正面 0.7m にいる。プレイヤーは x=10.0、
			# boss は x=12.0、判定は x=10.5 付近。人質 x=11.3 には Hurtbox が無い。
			# 判定を boss に届かせるため、正面 1.1m に寄せる。
			_player.global_position = Vector3(10.9, 0.2, 0.0)
			_advance(1)
		1:
			_player.global_position = Vector3(10.9, 0.2, 0.0)
			_pulse_hitbox(local)
			if local >= 40:
				_assert("(1) 正面からの近接は弾かれる (blocked=%d landed=%d)" % [_blocked, _landed],
					_blocked >= 1 and _landed == 0)
				_assert("(1) 正面攻撃で Shielder の HP は減らない",
					is_equal_approx(_boss_health.current_hp(), _boss_health.max_hp))
				# 背面へ回る（boss の +X 側、同じ段）。向き直りは遅いので即座に殴る。
				_player.global_position = Vector3(13.1, 0.2, 0.0)
				_player.set("_facing", -1)
				_player.get_node("Model").rotation.y = -PI * 0.5
				_landed = 0
				_blocked = 0
				_hits_done = 0
				_advance(2)
		2:
			_player.global_position = Vector3(13.1, 0.2, 0.0)
			_pulse_hitbox(local)
			if local >= 44:
				_assert("(2) 背面からの近接は通る (landed=%d)" % _landed, _landed >= 3)
				_assert("(2) 背面攻撃で Shielder の HP が減る",
					_boss_health.current_hp() < _boss_health.max_hp)
				_assert("(2) 3 回当てると人質を放す (shielded=%s)" %
					bool(_hostage.call("is_shielded")), not bool(_hostage.call("is_shielded")))
				_assert("(2) 放した人質は SEATED (state=%d)" % int(_hostage.call("current_state")),
					int(_hostage.call("current_state")) == 0)
				_boss_health.take_hit(_boss_health.max_hp)
				_advance(3)
		3:
			if local >= 3:
				_assert("(4) Shielder を倒すと defeated が出る (%d)" % _defeated, _defeated == 1)
				_assert("(4) 倒れたあとも人質は保持されていない",
					not bool(_hostage.call("is_shielded")))
				_finish()


## 6 フレーム開いて 6 フレーム閉じる。1 回の開閉で同じ相手に 1 回だけ当たる。
func _pulse_hitbox(local: int) -> void:
	var cycle := local % 12
	if cycle == 0:
		_player.call("_enable_hitbox", 10.0, 2.0)
	elif cycle == 6:
		_player.call("_disable_hitbox")


func _advance(phase: int) -> void:
	_phase = phase
	_phase_started = _frames


func _assert(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[PASS] " + label)
	else:
		_fail += 1
		print("[FAIL] " + label)


func _finish() -> void:
	set_physics_process(false)
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)
