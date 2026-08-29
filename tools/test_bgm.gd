extends Node

## 面の音楽の検証。
##   godot --path . --headless res://tools/test_bgm.tscn
##
##   (1) 5曲がループ有りでインポートされている
##   (2) 各面のシーンが持つ曲が指定どおり
##   (3) Bgm.play() で鳴り始め、同じ曲を渡し直しても鳴らし直さない（面をまたいで繋ぐ）
##   (4) 違う曲を渡すと入れ替わり、null を渡すと止まる
##   (5) 曲ごとの音量補正が音量へ乗る
##   (6) 面のシーンを実際に開くと、その面の曲が鳴り出す
##   (7) 5面の曲は3面の曲の後半（6:19 以降）と一致する

const TRACKS: Dictionary = {
	1: "res://assets/bgm/stage1.ogg",
	2: "res://assets/bgm/stage2.mp3",
	3: "res://assets/bgm/stage3.ogg",
	4: "res://assets/bgm/stage4.ogg",
	5: "res://assets/bgm/stage5.ogg",
}

## 5面が3面の曲のどこから始まるか（秒）と、その長さ（秒）。SOURCES.md の表と対応する。
const STAGE5_CUT_FROM: float = 379.0
const STAGE5_LENGTH: float = 166.19
## Ogg のページ単位で切れるぶんの許容（秒）。
const CUT_TOLERANCE: float = 0.05

var _pass: int = 0
var _fail: int = 0


func _ready() -> void:
	print("=== 面の音楽 検証開始 ===")
	_check_imports()
	_check_stages()
	_check_stage5_cut()
	await _check_playback()
	await _check_stage_starts()
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)


func _check_imports() -> void:
	for stage: int in TRACKS:
		var path: String = TRACKS[stage]
		_assert("(1) %s がある" % path, ResourceLoader.exists(path))
		var stream := load(path) as AudioStream
		_assert("(1) %s が AudioStream として読める" % path, stream != null)
		if stream == null:
			continue
		_assert("(1) %s がループ有り" % path, bool(stream.get("loop")))


func _check_stages() -> void:
	for stage: int in [1, 2, 3, 4, 5]:
		var scene := load("res://levels/stage_%d.tscn" % stage) as PackedScene
		var state := scene.get_state()
		var found := ""
		for i: int in range(state.get_node_property_count(0)):
			if state.get_node_property_name(0, i) == &"bgm":
				var stream := state.get_node_property_value(0, i) as AudioStream
				found = stream.resource_path if stream != null else ""
		var want: String = TRACKS.get(stage, "")
		_assert("(2) %d面の曲は %s" % [stage, want if not want.is_empty() else "無し"],
			found == want, "実際は %s" % (found if not found.is_empty() else "無し"))


## 5面は3面と同じ曲の後半。長さが「元の長さ - 6:19」と合っているかで見る。
func _check_stage5_cut() -> void:
	var whole := load(TRACKS[3]) as AudioStream
	var cut := load(TRACKS[5]) as AudioStream
	if whole == null or cut == null:
		_assert("(7) 3面と5面の曲が読める", false)
		return
	_assert("(7) 5面の長さは %.2f 秒" % STAGE5_LENGTH,
		absf(cut.get_length() - STAGE5_LENGTH) <= CUT_TOLERANCE,
		"実際は %.3f 秒" % cut.get_length())
	_assert("(7) 5面は3面の曲の 6:19 以降と同じ長さ",
		absf((whole.get_length() - STAGE5_CUT_FROM) - cut.get_length()) <= CUT_TOLERANCE,
		"3面 %.3f 秒 - %.1f 秒 = %.3f 秒" % [whole.get_length(), STAGE5_CUT_FROM,
			whole.get_length() - STAGE5_CUT_FROM])


func _check_playback() -> void:
	var one := load(TRACKS[1]) as AudioStream
	var two := load(TRACKS[2]) as AudioStream

	Bgm.play(one, 0.0, 0.0)
	await _settle()
	var playing := _playing_players()
	_assert("(3) 1曲だけ鳴っている", playing.size() == 1, "実際は %d 本" % playing.size())
	_assert("(3) 鳴っているのは1面の曲", Bgm.current_stream() == one)
	var first: AudioStreamPlayer = playing[0] if not playing.is_empty() else null

	Bgm.play(one, 0.0, 0.0)
	await _settle()
	playing = _playing_players()
	_assert("(3) 同じ曲を渡し直しても枠が変わらない",
		playing.size() == 1 and not playing.is_empty() and playing[0] == first)

	Bgm.play(two, -2.6, 0.0)
	await _settle()
	playing = _playing_players()
	_assert("(4) 違う曲に入れ替わる", Bgm.current_stream() == two)
	_assert("(4) 前の曲は止まっている", playing.size() == 1, "実際は %d 本" % playing.size())
	if not playing.is_empty():
		_assert("(5) 音量補正が乗る",
			is_equal_approx(playing[0].volume_db, Bgm.volume_db - 2.6),
			"実際は %.2f dB" % playing[0].volume_db)

	Bgm.play(null, 0.0, 0.0)
	await _settle()
	_assert("(4) null で止まる", _playing_players().is_empty())
	_assert("(4) 止まると current_stream は null", Bgm.current_stream() == null)

	# 絞っている途中に同じ曲を掛け直す。消えかけを「鳴っている」と見なして
	# 無音のままにしない（フェードは長めにして、絞りきる前に掛け直す）。
	Bgm.play(one, 0.0, 0.0)
	await _settle()
	Bgm.stop(2.0)
	await _settle()
	Bgm.play(one, 0.0, 0.0)
	await _settle()
	playing = _playing_players()
	_assert("(4) 絞っている途中に同じ曲を掛け直すと鳴り直す", Bgm.current_stream() == one)
	_assert("(4) 掛け直したあとの音量が絞られたままにならない",
		not playing.is_empty() and is_equal_approx(playing[0].volume_db, Bgm.volume_db),
		"実際は %s" % ("鳴っていない" if playing.is_empty() else "%.2f dB" % playing[0].volume_db))
	Bgm.stop(0.0)
	await _settle()


## 面を実際に開いたときに曲が掛かるところまで見る。
## 3面 → 5面は同じ曲の別の切り出しなので、繋がずに入れ替わることも見る。
func _check_stage_starts() -> void:
	for stage: int in [1, 3, 5]:
		var scene := load("res://levels/stage_%d.tscn" % stage) as PackedScene
		var node := scene.instantiate() as Node3D
		add_child(node)
		await _settle()
		var want := load(TRACKS[stage]) as AudioStream
		_assert("(6) %d面を開くとその面の曲が鳴る" % stage, Bgm.current_stream() == want)
		node.queue_free()
		await _settle()
	Bgm.stop(0.0)
	await _settle()


## フェード（長さ0）とその後の停止コールバックが片付くまで数フレーム待つ。
func _settle() -> void:
	for i: int in range(4):
		await get_tree().process_frame


func _playing_players() -> Array[AudioStreamPlayer]:
	var out: Array[AudioStreamPlayer] = []
	for child in Bgm.get_children():
		var player := child as AudioStreamPlayer
		if player != null and player.playing:
			out.append(player)
	return out


func _assert(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("[PASS] " + label)
	else:
		_fail += 1
		print("[FAIL] %s%s" % [label, ("  " + detail) if not detail.is_empty() else ""])
