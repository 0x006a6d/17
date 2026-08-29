extends Node

## 文字送りの途中で本文の描画位置が変わらないことの検証。
##   godot --path . --headless res://tools/test_card_line_height.tscn
##
## RichTextLabel の既定 VC_CHARS_BEFORE_SHAPING は、表示済みの文字だけで行を組む。
## 行の高さはその行で使うフォントの最大 ascent で決まるので、最後に別フォントへ落ちる
## 文字（全角「？」など）が出た瞬間に行が下へずれる（1面冒頭「行ける？」で実測 5px）。
## VC_CHARS_AFTER_SHAPING は全文で組んでから表示ぶんだけ描くので、位置が動かない。

const CARD := "res://ui/text_card.tscn"
const STAGES: PackedStringArray = [
	"res://levels/stage_1.tscn", "res://levels/stage_2.tscn", "res://levels/stage_3.tscn",
	"res://levels/stage_4.tscn", "res://levels/stage_5.tscn",
]

var _pass: int = 0
var _fail: int = 0


func _ready() -> void:
	print("=== カード本文の行高 検証開始 ===")
	var lines: Array[String] = []
	for path: String in STAGES:
		var stage := (load(path) as PackedScene).instantiate()
		for line: String in stage.get("opening_lines"):
			lines.append(line)
		for line: String in stage.get("reveal_lines"):
			lines.append(line)
		stage.free()
	var card := (load(CARD) as PackedScene).instantiate() as TextCard
	card.lines = lines
	add_child(card)
	await get_tree().process_frame
	card.show_card()
	card.set_process(false)
	var label := card.get_node(^"Screen/Panel/Margin/Rows/Body/Text") as RichTextLabel
	_assert("本文は全文で組んでから表示ぶんだけ描く (VC_CHARS_AFTER_SHAPING)",
		label.visible_characters_behavior == TextServer.VC_CHARS_AFTER_SHAPING,
		"behavior=%d" % label.visible_characters_behavior)
	for page: int in range(card.page_count()):
		await get_tree().process_frame
		await get_tree().process_frame
		var text: String = label.text
		var total: int = text.length()
		label.visible_characters = -1
		await get_tree().process_frame
		var final_height: float = label.get_content_height()
		var worst_count: int = -1
		var worst_height: float = final_height
		for count: int in range(1, total + 1):
			label.visible_characters = count
			await get_tree().process_frame
			var height: float = label.get_content_height()
			if not is_equal_approx(height, final_height):
				worst_count = count
				worst_height = height
				break
		_assert("p%02d 「%s」 の行高が文字送り中も一定 (%.0f)"
			% [page, text.substr(0, 12), final_height],
			worst_count < 0, "%d 文字目で %.0f" % [worst_count, worst_height])
		label.visible_characters = -1
		if page + 1 < card.page_count():
			card._advance(true)
	print("=== 結果: PASS=%d FAIL=%d ===" % [_pass, _fail])
	print("ALL PASS" if _fail == 0 else "HAS FAILURE")
	get_tree().quit(0 if _fail == 0 else 1)


func _assert(label: String, ok: bool, detail: String) -> void:
	if ok:
		_pass += 1
		print("[PASS] " + label)
	else:
		_fail += 1
		print("[FAIL] %s : %s" % [label, detail])
