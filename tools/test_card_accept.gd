extends Node

## テキストカードの送りとスキップの検証。
##   godot --path . --headless res://tools/test_card_accept.tscn
##
##   (1) 押している間の1回の押し下がりで、起きるのは1回だけ
##       （文字送りの完了とページ送りが同時に起きない）
##   (2) 離して押し直すと次のページへ進む
##   (3) "---" の行はページの区切りになり、画面には出さない
##   (4) スキップ（Esc / △）で残りを飛ばして閉じる

const CARD: String = "res://ui/text_card.tscn"
const LINES: Array[String] = [
	"ミカゼ「ニケちゃん！」",
	"ミカゼ「……ニケが、連れていかれた。」",
	"---",
	"ミカゼ「場所は追える。」",
	"---",
	"AIニケ「行きます。」",
]

var _pass: int = 0
var _fail: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== カードの送りとスキップ 検証開始 ===")
	_run()


func _run() -> void:
	var card := (load(CARD) as PackedScene).instantiate() as TextCard
	add_child(card)
	card.lines = LINES
	card.show_card()
	await _wait_frames(2)

	_assert("(3) 1行が1ページになる（\"---\" と空行は数えない、%d ページ）" % card.page_count(),
		card.page_count() == 4)
	var label := card.get_node(^"Screen/Panel/Margin/Rows/Body/Text") as RichTextLabel
	_assert("(3) \"---\" は本文に出ない", not label.text.contains("---"))

	# 押しっぱなしにする（人の指は数フレーム押し続ける）。
	_key(KEY_ENTER, true)
	await _wait_frames(8)
	_assert("(1) 押している間はページが変わらない (page=%d)" % card.page_index(),
		card.page_index() == 0)
	_assert("(1) 文字は全部出ている", label.visible_characters < 0)

	_key(KEY_ENTER, false)
	await _wait_frames(2)
	_key(KEY_ENTER, true)
	await _wait_frames(4)
	_assert("(2) 離して押し直すと次のページへ (page=%d)" % card.page_index(),
		card.page_index() == 1)
	_key(KEY_ENTER, false)
	await _wait_frames(2)

	var closed: Array[bool] = [false]
	card.closed.connect(func() -> void: closed[0] = true)
	card.skip()
	await _wait_frames(2)
	_assert("(4) スキップで閉じる", closed[0] and not card.is_open())
	_assert("(4) スキップ後はツリーが動く", not get_tree().paused)
	card.queue_free()
	await _wait_frames(2)
	_finish()


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _assert(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[PASS] " + label)
	else:
		_fail += 1
		print("[FAIL] " + label)


func _finish() -> void:
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)
