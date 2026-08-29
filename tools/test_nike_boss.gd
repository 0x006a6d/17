extends Node

## 5面ボス ニケの検証。
##   godot --path . --headless res://tools/test_nike_boss.tscn
##
##   (1) 画面右に出たニケが段を合わせて接近し、一定時間内にプレイヤーの HP を減らす
##   (2) 赤シャツ（NikeSkin recolor）とヘアピン切り出しが適用されている
##   (3) 短時間に 2 回被弾するとガードに入り（guard_chance=1）、正面からの近接が弾かれる
##   (4) HP が 50% を切ると adds_requested(2) が 1 回だけ出る
##   (5) HP 0 で defeated が出て、立ち上がらず点滅してから消える

const STAGE := "res://levels/belt_test.tscn"
const NIKE := "res://actors/boss/nike.tscn"
const MAX_FRAMES := 3000
const PRE_DESPAWN_CHECK_FRAMES: int = 180
const POST_DESPAWN_CHECK_FRAMES: int = 270

var _pass: int = 0
var _fail: int = 0
var _stage: Node3D = null
var _player: Node3D = null
var _player_health: Health = null
var _nike: Node3D = null
var _nike_health: Health = null
var _frames: int = 0
var _phase: int = 0
var _phase_started: int = 0
var _blocked: int = 0
var _guard_seen: bool = false
var _adds: Array[int] = []
var _defeated: int = 0
var _pre_despawn_checked: bool = false
var _blink_started: bool = false
var _blink_opacity_changed: bool = false


func _ready() -> void:
	print("=== 5面ボス ニケ 検証開始 ===")
	RunState.reset()
	_stage = (load(STAGE) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node_or_null("Player") as Node3D
	_player_health = _player.get_node_or_null("Health") as Health
	for n in ["Dummy1", "Dummy2", "Dummy3"]:
		var d := _stage.get_node_or_null(n) as Node3D
		if d != null:
			d.global_position = Vector3(50.0, 0.2, 0.0)
	var camera := _stage.get_node_or_null("BeltCamera")
	if camera != null:
		camera.call("lock_at", 7.0)
	_player.global_position = Vector3(4.0, 0.2, 0.4)
	_nike = (load(NIKE) as PackedScene).instantiate() as Node3D
	_stage.add_child(_nike)
	_nike.global_position = Vector3(10.5, 0.2, -0.8)
	_nike.call("set_belt_bounds", -1.5, 1.5)
	_nike.set("guard_chance", 1.0)
	_nike_health = _nike.get_node_or_null("Health") as Health
	_nike.connect("adds_requested", func(n: int) -> void: _adds.append(n))
	_nike.connect("defeated", func(_e: Node3D) -> void: _defeated += 1)
	var blink: ModelBlink = _nike.get_node_or_null(^"DespawnBlink") as ModelBlink
	if blink != null:
		blink.blink_started.connect(func() -> void: _blink_started = true)
		blink.opacity_changed.connect(func(opacity: float) -> void:
			if opacity < 1.0:
				_blink_opacity_changed = true)
	var hitbox := _player.get_node_or_null("Model/MeleeHitbox") as Hitbox
	hitbox.hit_blocked.connect(func(_t: Node3D) -> void: _blocked += 1)


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
			if _player_health.current_hp() < _player_health.max_hp:
				var dz := absf(_nike.global_position.z - _player.global_position.z)
				_assert("(1) ニケが接近して殴り、プレイヤーの HP が減った (%.1f 秒, dz=%.2f)" %
					[local / 60.0, dz], true)
				var skin := _nike.get_node_or_null("NikeSkin")
				_assert("(2) 赤シャツが適用されている (%d)" % int(skin.call("recolored_surface_count")),
					int(skin.call("recolored_surface_count")) >= 1)
				_assert("(2) ヘアピンが切り出されている (%d)" % int(skin.call("cut_triangle_count")),
					int(skin.call("cut_triangle_count")) >= 100)
				# (3) ガード: 2 回続けて当てる。ニケを止めてから正面に立つ。
				_nike.set_physics_process(false)
				_nike.global_position = Vector3(8.0, 0.2, 0.0)
				_nike.set("_facing", -1)
				_player.global_position = Vector3(7.0, 0.2, 0.0)
				_player.set("_facing", 1)
				_player.get_node("Model").rotation.y = PI * 0.5
				_player_health.revive()
				_advance(1)
			elif local > 600:
				_assert("(1) ニケが 10 秒以内に接近して殴る (hp=%.0f)" %
					_player_health.current_hp(), false)
				_advance(1)
		1:
			_player.global_position = Vector3(7.0, 0.2, 0.0)
			_nike.global_position = Vector3(8.0, 0.2, 0.0)
			if bool(_nike.call("is_guarding")):
				_guard_seen = true
			# 6 フレーム開いて 6 フレーム閉じるを繰り返す。ガードに入るまで殴り、
			# 入ったあとの一撃が弾かれることを見る。
			var cycle := local % 12
			if cycle == 0:
				_player.call("_enable_hitbox", 10.0, 2.0)
			elif cycle == 6:
				_player.call("_disable_hitbox")
			if local >= 60:
				_assert("(3) 被弾を重ねるとガードに入る", _guard_seen)
				_assert("(3) ガード中の正面近接は弾かれる (blocked=%d)" % _blocked, _blocked >= 1)
				_nike.set_physics_process(true)
				_nike_health.take_hit(_nike_health.max_hp * 0.55)
				_advance(2)
		2:
			if local == 3:
				_assert("(4) HP 50% 未満で adds_requested(2) が 1 回 (%s)" % str(_adds),
					_adds.size() == 1 and _adds[0] == 2)
				_nike_health.take_hit(_nike_health.max_hp)
			if local == 6:
				_assert("(5) HP 0 で defeated が出る (%d)" % _defeated, _defeated == 1)
			if local >= PRE_DESPAWN_CHECK_FRAMES and not _pre_despawn_checked:
				_pre_despawn_checked = true
				_assert("(5) 消える前は倒れたまま",
					is_instance_valid(_nike) and bool(_nike.call("is_downed")))
			if local >= POST_DESPAWN_CHECK_FRAMES:
				_assert("(5) 消滅直前に点滅が始まり不透明度が変わる",
					_blink_started and _blink_opacity_changed)
				_assert("(5) despawn_delay 後に消える", not is_instance_valid(_nike))
				_finish()


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
