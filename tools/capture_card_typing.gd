extends Node

## 文字送り中と全文表示で本文の位置がずれないかを、同じページで文字数ごとに撮る検証用。
##   godot --path . --resolution 1280x720 res://tools/capture_card_typing.tscn -- --page 2
## 背景は無地（3D の動きが差分に混ざらないようにする）。

const OUT_DIR := "res://docs/img"
const LINES: Array[String] = [
	"ミカゼ「ニケちゃん！」",
	"ミカゼ「……ニケが、連れていかれた。」",
	"ミカゼ「場所は追える。わたしが案内する。行ける？」",
	"AIニケ「行きます。」",
]

var _card: TextCard = null
var _page: int = 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--page":
			_page = int(args[i + 1])
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_card = (load("res://ui/text_card.tscn") as PackedScene).instantiate() as TextCard
	_card.lines = LINES
	add_child(_card)
	_run()


func _label() -> RichTextLabel:
	return _card.get_node(^"Screen/Panel/Margin/Rows/Body/Text") as RichTextLabel


func _shoot(name: String) -> void:
	for _f in range(2):
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/qc_typing_p%d_%s.png" % [OUT_DIR, _page, name]
	print("[typing] %s (%s)" % [path, error_string(img.save_png(path))])


func _run() -> void:
	_card.show_card()
	await get_tree().process_frame
	# 送り操作を全部止める（撮影中にウィンドウが実キー入力を拾ってページが進まないように）。
	_card.set_process(false)
	_card.set_process_input(false)
	_card.set_process_unhandled_input(false)
	for _p in range(_page):
		_card._advance(true)
		await get_tree().process_frame
	var label := _label()
	var total: int = label.text.length()
	print("[typing] page=%d text=%s total=%d" % [_page, label.text, total])
	for count in [4, total - 1, total]:
		if count <= 0:
			continue
		label.visible_characters = count
		await _shoot("n%02d" % count)
	label.visible_characters = -1
	await _shoot("full")
	get_tree().quit()
