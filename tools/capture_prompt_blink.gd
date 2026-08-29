extends Control

## タイトルのプロンプトの点滅案を、消灯側の絵と一緒に撮る QC 用。
## 描画結果が要るので --headless では実行しない。
##   godot --path . --resolution 1280x300 res://tools/capture_prompt_blink.tscn
##
## 案: A 全体 赤⇄黒 / B 全体 赤⇄消える / C 「>」だけ 赤⇄消える / D 「>」だけ 赤⇄黒

const OUT_DIR := "res://docs/img"
const BASE_FONT := preload("res://assets/fonts/ShipporiMinchoB1-ExtraBold.ttf")
const EMBOLDEN: float = 0.06
const CARET := "> "
const BODY := "はじめる"
const LIME := Color(0.65098, 0.882353, 0.196078, 1.0)
const RED := Color(0.92, 0.0, 0.0, 1.0)
const BLACK := Color(0.0, 0.0, 0.0, 1.0)
const FONT_SIZE: int = 66

var _font: Font = null
## 撮る絵: [案, 灯り, キャレット色, 本文色]
var _shots: Array = []
var _index: int = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var variation := FontVariation.new()
	variation.base_font = BASE_FONT
	variation.variation_embolden = EMBOLDEN
	_font = variation
	_shots = [
		["a", "lit", RED, RED], ["a", "unlit", BLACK, BLACK],
		["b", "lit", RED, RED], ["b", "unlit", Color.TRANSPARENT, Color.TRANSPARENT],
		["c", "lit", RED, RED], ["c", "unlit", Color.TRANSPARENT, RED],
		["d", "lit", RED, RED], ["d", "unlit", BLACK, RED],
	]
	_run()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), LIME)
	if _index < 0:
		return
	var caret_color: Color = _shots[_index][2]
	var body_color: Color = _shots[_index][3]
	var caret_width: float = _font.get_string_size(CARET,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x
	var total: float = _font.get_string_size(CARET + BODY,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x
	var x: float = (size.x - total) * 0.5
	var y: float = size.y * 0.62
	if caret_color.a > 0.0:
		draw_string(_font, Vector2(x, y), CARET,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, caret_color)
	if body_color.a > 0.0:
		draw_string(_font, Vector2(x + caret_width, y), BODY,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, body_color)


func _run() -> void:
	for i in range(_shots.size()):
		_index = i
		queue_redraw()
		for _f in range(3):
			await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s/qc_blink_%s_%s.png" % [OUT_DIR, _shots[i][0], _shots[i][1]]
		print("[blink] %s (%s)" % [path, error_string(img.save_png(path))])
	get_tree().quit()
