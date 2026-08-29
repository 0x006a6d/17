extends Node
## 回避（バク転だけに切り出した現行設定）の連続フレームを保存する。
##   qc_dodge_trim_N.png     … 開始〜終了の等間隔 8 枚
##   qc_dodge_trim_in_N.png  … 待機ポーズ→回避の入りを 1 物理フレームずつ 6 枚
##   qc_dodge_trim_out_N.png … 回避→待機ポーズの抜けを 1 物理フレームずつ 6 枚
## 入り・抜けは、切り出しでクリップの途中から再生することによる飛びが出ていないかを
## 見るためのもので、等間隔の 8 枚では間隔が粗すぎて判定できない。
##
## スクリーンショットの待ち（frame_post_draw）自体が物理フレームを消費するため、
## 1 回の回避の中で複数枚を撮ると狙ったフレームからずれる。1 枚につき 1 回ずつ
## 回避をやり直し、押してから目的のフレーム数だけ進めて撮る。
## 修正前（未切り出し）の比較画像は docs/img/qc_dodge_after_*.png に保存済みのものを使う。
## 実行:
##   godot --path . --resolution 1280x720 res://tools/capture_dodge.tscn
const STAGE := "res://levels/belt_test.tscn"
const OUTPUT_DIRECTORY := "res://docs/img/"
## 等間隔で撮る枚数（開始〜終了）。
const SHOT_COUNT: int = 8
## 入り・抜けを 1 物理フレームずつ撮る枚数。
const BLEND_SHOT_COUNT: int = 6
## 抜けの収録を回避終了の何フレーム前から始めるか。
const EXIT_LEAD_FRAMES: int = 3
const WARMUP_FRAMES: int = 30
## 位置を戻した後、追従カメラが落ち着いて画面端 clamp が止まるまで待つフレーム数。
const SETTLE_FRAMES: int = 90
const PLAYER_START := Vector3(20.0, 0.2, 0.0)

var _stage: Node3D = null
var _player: Node3D = null
var _camera: Camera3D = null


func _ready() -> void:
	RunState.reset()
	_stage = (load(STAGE) as PackedScene).instantiate() as Node3D
	add_child(_stage)
	_player = _stage.get_node(^"Player") as Node3D
	_camera = _stage.get_node(^"BeltCamera") as Camera3D
	# ダミーは動かさず、その場に立たせたまま world 上の目印にする。カメラが
	# プレイヤーを追うため、後退したことは目印との間隔でしか絵に出ない。
	for dummy_name: String in ["Dummy1", "Dummy2", "Dummy3"]:
		var dummy: Node3D = _stage.get_node(dummy_name) as Node3D
		dummy.set_physics_process(false)
		dummy.set_process(false)
	await _wait_frames(WARMUP_FRAMES)

	var duration: float = float(_player.get("dodge_duration"))
	var total_frames: int = int(round(duration * float(Engine.physics_ticks_per_second)))
	_report_setup(duration, total_frames)
	for shot: Array in _build_shots(total_frames):
		await _capture_one(String(shot[0]), int(shot[1]), int(shot[2]), total_frames)
	print("ALL PASS")
	get_tree().quit(0)


func _report_setup(duration: float, total_frames: int) -> void:
	var action_anim: Node = _player.get_node(^"PlayerActionAnim")
	var trim: Vector2 = action_anim.call("action_trim", &"dodge")
	print("[setup] 切り出し=%.3f〜%.3fs（長さ %.3fs）/ 素材 %.3fs duration=%.3fs(%dフレーム) distance=%.2fm iframes=%.3fs" % [
		trim.x, trim.x + trim.y, trim.y,
		float(action_anim.call("source_clip_length", &"dodge")), duration, total_frames,
		float(_player.get("dodge_distance")), float(_player.get("dodge_iframes"))])


## [接頭辞, 枚数の通し番号, 回避を押してからの物理フレーム数] の一覧。
func _build_shots(total_frames: int) -> Array[Array]:
	var shots: Array[Array] = []
	for shot: int in range(SHOT_COUNT):
		shots.append(["trim", shot + 1, 1 + int(round(float(shot)
			* float(total_frames - 1) / float(SHOT_COUNT - 1)))])
	# 入りの 1 枚目は押す前の待機ポーズ（0 フレーム）。
	for shot: int in range(BLEND_SHOT_COUNT):
		shots.append(["in", shot + 1, shot])
	for shot: int in range(BLEND_SHOT_COUNT):
		shots.append(["out", shot + 1, total_frames - EXIT_LEAD_FRAMES + shot])
	return shots


func _capture_one(prefix: String, shot: int, target_frame: int, total_frames: int) -> void:
	_player.global_position = PLAYER_START
	_player.set("_facing", 1)
	await _wait_frames(SETTLE_FRAMES)
	var start_x: float = _player.global_position.x
	var press_frame: int = 0
	if target_frame > 0:
		_act("dodge")
		press_frame = Engine.get_physics_frames()
		await _wait_frames(target_frame)
	else:
		press_frame = Engine.get_physics_frames()
	var elapsed_before_draw: int = Engine.get_physics_frames() - press_frame
	await RenderingServer.frame_post_draw
	var elapsed: int = Engine.get_physics_frames() - press_frame
	var path: String = "%sqc_dodge_trim%s_%d.png" % [OUTPUT_DIRECTORY,
		"" if prefix == "trim" else "_" + prefix, shot]
	get_viewport().get_texture().get_image().save_png(path)
	var screen: Vector2 = _camera.unproject_position(
		_player.global_position + Vector3(0.0, 0.8, 0.0))
	print("[shot] %s frame=%d/%d(描画時 %d) t=%.3fs dx=%.2fm dodging=%s screen=%d,%d" % [
		path, elapsed_before_draw, total_frames, elapsed,
		float(elapsed_before_draw) / float(Engine.physics_ticks_per_second),
		_player.global_position.x - start_x,
		str(bool(_player.call("is_dodging"))),
		int(round(screen.x)), int(round(screen.y))])


func _act(action_name: String) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	Input.parse_input_event(event)


func _wait_frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().physics_frame
