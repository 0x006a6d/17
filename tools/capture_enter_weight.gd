extends Control

## タイトルのプロンプトを、太らせ量を変えて並べて撮る QC 用。
## Shippori Mincho B1 の最大ウェイトは ExtraBold で、それ以上は FontVariation の
## variation_embolden で合成する。描画結果が要るので --headless では実行しない。
##   godot --path . --resolution 1280x720 res://tools/capture_enter_weight.tscn

const OUT := "res://docs/img/qc_enter_weight.png"
const BASE_FONT := preload("res://assets/fonts/ShipporiMinchoB1-ExtraBold.ttf")
const TEXT := "はじめる"
const LIME := Color(0.65098, 0.882353, 0.196078, 1.0)
const RED := Color(0.92, 0.0, 0.0, 1.0)
const EMBOLDEN: Array[float] = [0.0, 0.03, 0.06, 0.09]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_run()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), LIME)
	var font_size: int = 54
	var y: float = 90.0
	for amount: float in EMBOLDEN:
		var font: Font = BASE_FONT
		if amount > 0.0:
			var variation := FontVariation.new()
			variation.base_font = BASE_FONT
			variation.variation_embolden = amount
			font = variation
		var text_size: Vector2 = font.get_string_size(TEXT,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		draw_string(font, Vector2((size.x - text_size.x) * 0.5, y), TEXT,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, RED)
		var label: Font = BASE_FONT
		draw_string(label, Vector2(40.0, y), "embolden %.2f" % amount,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Color.BLACK)
		y += 150.0


func _run() -> void:
	for _f in range(4):
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	print("[weight] %s (%s)" % [OUT, error_string(img.save_png(OUT))])
	get_tree().quit()
