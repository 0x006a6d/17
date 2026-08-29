extends Node

## テキストカードの検証。
##   godot --path . --headless res://tools/test_text_card.tscn
##
##   (1) show_card() でツリーが止まり、文字が経過時間に応じて増える
##   (2) ui_accept 1 回目で全文表示、2 回目で閉じてツリーが再開し closed が出る
##   (3) BeltStage の opening_lines があると StageDirector が CARD で始まり、閉じると PLAY
##   (4) `名前「…」` の行は話者ごとにページに分かれ、話者のタイルが side の側に出る。
##       ui_accept でページが進み、最後のページで閉じる

const CARD := "res://ui/text_card.tscn"
const STAGE := "res://levels/belt_test.tscn"

var _pass: int = 0
var _fail: int = 0
var _card: CanvasLayer = null
var _closed: int = 0
var _frames: int = 0
var _phase: int = 0
var _phase_started: int = 0
var _shown_early: int = -1
var _label: RichTextLabel = null
var _tile_left: Control = null
var _tile_right: Control = null


func _ready() -> void:
	print("=== テキストカード 検証開始 ===")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_card = (load(CARD) as PackedScene).instantiate() as CanvasLayer
	add_child(_card)
	# 1行=1ページなので、この節は1行だけのカードで見る（全文表示 → 閉じる）。
	var card_lines: Array[String] = ["一行だけのテキストです。"]
	_card.set("lines", card_lines)
	_card.set("chars_per_second", 20.0)
	_card.connect("closed", func() -> void: _closed += 1)
	_label = _card.get_node("Screen/Panel/Margin/Rows/Body/Text") as RichTextLabel
	_card.call("show_card")


func _accept() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)


func _process(_delta: float) -> void:
	_frames += 1
	var local := _frames - _phase_started
	match _phase:
		0:
			if local == 10:
				_assert("(1) 表示中はツリーが止まる", get_tree().paused)
				# 文字送りの途中でも送れるので、案内は最初から出しておく。
				var prompt := _card.get_node_or_null(
					"Screen/Panel/Margin/Rows/Footer/Prompt") as Label
				_assert("(1) 送り方の案内は文字送りの途中から出ている (%s)"
					% ("表示" if prompt != null and prompt.visible else "非表示"),
					prompt != null and prompt.visible
					and _label.visible_characters >= 0)
				_shown_early = _label.visible_characters
			if local == 40:
				var now := _label.visible_characters
				_assert("(1) 文字が経過時間で増える (%d → %d)" % [_shown_early, now],
					now > _shown_early and now >= 0)
				_accept()
			if local == 44:
				_assert("(2) ui_accept 1 回目で全文表示 (visible_characters=%d)" %
					_label.visible_characters, _label.visible_characters < 0)
				_assert("(2) まだ閉じていない", _closed == 0)
				_accept()
			if local == 48:
				_assert("(2) ui_accept 2 回目で閉じる (closed=%d)" % _closed, _closed == 1)
				_assert("(2) 閉じるとツリーが再開する", not get_tree().paused)
				_start_stage_case()
				_advance(1)
		1:
			if local == 6:
				_assert("(3) opening_lines がある面は CARD で始まる (phase=%d)" % StageDirector.phase,
					StageDirector.phase == StageDirector.Phase.CARD)
				_accept()
			if local == 10:
				_accept()
			if local == 16:
				_assert("(3) カードを閉じると PLAY (phase=%d)" % StageDirector.phase,
					StageDirector.phase == StageDirector.Phase.PLAY)
				_start_paging_case()
				_advance(2)
		2:
			if local == 4:
				_assert("(4) 1行が1ページになる (pages=%d)" % _card.call("page_count"),
					_card.call("page_count") == 4)
				var sp: SpeakerProfile = _card.call("current_speaker")
				_assert("(4) 1 ページ目の話者はミカゼ", sp != null and sp.speaker_name == "ミカゼ")
				_assert("(4) ミカゼのタイルは右、左は非表示",
					_tile_right.visible and not _tile_left.visible)
				_assert("(4) 1行ぶんなので本文に改行が入らない",
					_label.text.find("\n") < 0)
				_assert("(4) 名前と「」は本文から外れる", not _label.text.contains("「"))
				_accept()
			if local == 8:
				_assert("(4) 1 回目は全文表示で、まだ 1 ページ目", _label.visible_characters < 0
					and _card.call("page_index") == 0)
				_accept()
			if local == 12:
				var sp: SpeakerProfile = _card.call("current_speaker")
				_assert("(4) 2 ページ目もミカゼ", _card.call("page_index") == 1
					and sp != null and sp.speaker_name == "ミカゼ")
				_assert("(4) まだ閉じていない", _closed == 1)
				_accept()
			if local == 16:
				_accept()
			if local == 20:
				var sp: SpeakerProfile = _card.call("current_speaker")
				_assert("(4) 3 ページ目は AIニケ", _card.call("page_index") == 2
					and sp != null and sp.speaker_name == "AIニケ")
				_assert("(4) AIニケのタイルは左、右は非表示",
					_tile_left.visible and not _tile_right.visible)
				_accept()
			if local == 24:
				_accept()
			if local == 28:
				var sp: SpeakerProfile = _card.call("current_speaker")
				_assert("(4) 4 ページ目は地の文（話者なし・タイルなし）", _card.call("page_index") == 3
					and sp == null and not _tile_left.visible and not _tile_right.visible)
				_accept()
			if local == 32:
				_accept()
			if local == 36:
				_assert("(4) 最後のページで閉じる (closed=%d)" % _closed, _closed == 2)
				_finish()


func _start_stage_case() -> void:
	var stage := (load(STAGE) as PackedScene).instantiate() as Node3D
	# belt_test.gd は BeltStage ではないので、BeltStage を直接組む。
	var belt := BeltStage.new()
	belt.opening_lines = ["出動。"] as Array[String]
	belt.player_path = ^"Player"
	belt.camera_path = ^"BeltCamera"
	for child in stage.get_children():
		stage.remove_child(child)
		belt.add_child(child)
	stage.queue_free()
	add_child(belt)


func _start_paging_case() -> void:
	_tile_left = _card.get_node("Screen/Panel/Margin/Rows/Body/TileLeft") as Control
	_tile_right = _card.get_node("Screen/Panel/Margin/Rows/Body/TileRight") as Control
	var card_lines: Array[String] = [
		"ミカゼ「ニケちゃん！」",
		"ミカゼ「……ニケが、連れていかれた」",
		"AIニケ「はい。行きます」",
		"",
		"男は呻きながら言った。",
	]
	_card.set("lines", card_lines)
	_card.set("chars_per_second", 1.0)
	_card.call("show_card")


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
	set_process(false)
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)
