extends Node
## 攻撃時の擬音（ぱん／ぶん／ふっ／でやあ）の見え方を撮る。
##   qc_attack_cry_gun.png / _katana.png / _unarmed.png / _left.png
##   ドロップキックは実際に出して2枚（_dropkick.png / _dropkick_late.png）
## 実行:
##   godot --path . --resolution 1280x720 res://tools/capture_attack_cry.tscn
##
## 撮ったあとは人が6枚を開いて次を見る（数値では判定できない）。
##   1. 文字が「ぱん」「ぶん」「ふっ」「でやあ」で、書体が Shippori Mincho（明朝の太字）に
##      なっている
##   2. 頭のてっぺんより上に出ていて、体や HUD に重なっていない
##   3. 右向き（_gun / _katana / _unarmed）は右上、左向き（_left）は左上に出ている
##   4. 縁取りが背景に埋もれず、字が読める
##   5. ドロップキックの2枚（_dropkick / _dropkick_late）は「でやあ」が出ていて、
##      踏み込みで前へ出た体に対して文字がその場に残り、頭より上のまま薄くなっていく。
##      △必殺が出なかったときと、2枚目の時点で文字がほとんど消えているときは
##      「[警告]」が出るので撮り直す
## 1つでも外れていたら、AttackCry3D の head_height / head_size / forward_heads /
## font_size / outline_size を直してから撮り直す。

const STAGE := "res://levels/belt_test.tscn"
const OUTPUT_DIRECTORY := "res://docs/img/"
const PLAYER_START := Vector3(20.0, 0.2, 0.0)
const WARMUP_FRAMES: int = 30
const SETTLE_FRAMES: int = 60
## 擬音を出してから撮るまでのフレーム数（出た直後の拡大が落ち着く頃）。
const SHOT_DELAY_FRAMES: int = 8
## ドロップキックの2枚を撮る時刻（擬音の寿命に対する割合）。
const DROPKICK_EARLY_RATIO: float = 0.25
const DROPKICK_LATE_RATIO: float = 0.70
## 2枚目に文字が残っているとみなす濃さの下限。
const MIN_LATE_ALPHA: float = 0.15

var _stage: Node3D = null
var _player: Node3D = null
var _cry: AttackCry3D = null


func _ready() -> void:
	RunState.reset()
	_stage = (load(STAGE) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node(^"Player") as Node3D
	_cry = _player.get_node(^"AttackCry3D") as AttackCry3D
	for dummy_name: String in ["Dummy1", "Dummy2", "Dummy3"]:
		var dummy := _stage.get_node_or_null(NodePath(dummy_name)) as Node3D
		if dummy != null:
			dummy.global_position = Vector3(60.0, 0.2, 0.0)
	_run()


func _run() -> void:
	await _wait_frames(WARMUP_FRAMES)
	_player.global_position = PLAYER_START
	await _wait_frames(SETTLE_FRAMES)
	await _shoot(1, _cry.gun_text, "qc_attack_cry_gun.png")
	await _shoot(1, _cry.katana_text, "qc_attack_cry_katana.png")
	await _shoot(1, _cry.unarmed_text, "qc_attack_cry_unarmed.png")
	await _shoot(-1, _cry.gun_text, "qc_attack_cry_left.png")
	await _dropkick()
	get_tree().quit()


func _shoot(facing: int, text: String, name: String) -> void:
	_player.set("_facing", facing)
	await _wait_frames(2)
	_cry.show_cry(text)
	await _wait_frames(SHOT_DELAY_FRAMES)
	await RenderingServer.frame_post_draw
	var path := OUTPUT_DIRECTORY + name
	get_viewport().get_texture().get_image().save_png(path)
	print("[saved] %s（%s / facing=%d）" % [path, text, facing])
	await _wait_frames(int(_cry.lifetime * 60.0) + 10)


## ドロップキック（△必殺）は実際に出して撮る。文字は踏み込みの前に出るので、
## 出た直後と、踏み込んだあとの2枚を残す。
##
## 撮る時刻は寿命の割合で決め、フレーム数では数えない。擬音は tween（実時間）で
## 消えるので、フレーム数だと画面の更新間隔しだいで2枚が同じ絵になる。
## 2枚目は「1枚目からの待ち」ではなく押した時刻からの締切で測る。待ちを繋ぐと
## PNG の書き出しにかかった時間だけ後ろへずれ、文字が消えたあとになりうる。
func _dropkick() -> void:
	_player.set("_facing", 1)
	await _wait_frames(2)
	var shown: Array[String] = []
	var record := func(text: String, _position: Vector3) -> void: shown.append(text)
	_cry.cry_shown.connect(record)
	var event := InputEventAction.new()
	event.action = "special"
	event.pressed = true
	Input.parse_input_event(event)
	var pressed_msec: int = Time.get_ticks_msec()
	await _wait_until(pressed_msec, _cry.lifetime * DROPKICK_EARLY_RATIO)
	await _save("qc_attack_cry_dropkick.png", "でやあ（出た直後）")
	await _wait_until(pressed_msec, _cry.lifetime * DROPKICK_LATE_RATIO)
	var late_alpha: float = _cry_alpha()
	await _save("qc_attack_cry_dropkick_late.png", "でやあ（踏み込んだあと）")
	_cry.cry_shown.disconnect(record)
	# △必殺は硬直中・再使用待ち・HP 不足では出ない。出ていないと文字の無い絵が
	# 残るだけなので、撮れたことにしない。
	if shown.is_empty():
		print("[警告] △必殺が出なかった。ドロップキックの2枚は撮り直す")
	elif late_alpha < MIN_LATE_ALPHA:
		print("[警告] 2枚目の時点で文字がほとんど消えている（濃さ %.2f）。"
			% late_alpha + "DROPKICK_LATE_RATIO を下げて撮り直す")
	await _wait_seconds(_cry.lifetime + 0.2)


## いま出ている擬音の濃さ（0〜1）。出ていなければ 0。
func _cry_alpha() -> float:
	if _cry.get_child_count() == 0:
		return 0.0
	var anchor := _cry.get_child(_cry.get_child_count() - 1)
	if anchor == null or anchor.get_child_count() == 0:
		return 0.0
	var label := anchor.get_child(0) as Label3D
	return label.modulate.a if label != null else 0.0


func _save(name: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OUTPUT_DIRECTORY + name
	get_viewport().get_texture().get_image().save_png(path)
	print("[saved] %s（%s）" % [path, label])


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.0)).timeout


## 起点からの経過が seconds になるまで待つ。締切で測るので、途中の書き出しに
## 時間がかかっても撮る時刻はずれない。
func _wait_until(start_msec: int, seconds: float) -> void:
	var deadline: int = start_msec + int(maxf(seconds, 0.0) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
