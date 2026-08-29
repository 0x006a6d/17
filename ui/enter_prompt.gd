extends Control
class_name EnterPrompt

## タイトルの「押してください」表示。端末のプロンプトに見立てて、記号の `>` だけを
## カーソルのように明滅させ、文言は出したままにする。消灯側は色を変えず地の色へ
## 消す（黄緑の地に対しては黒も赤と同じくらい強く出るので、色を変えると点滅ではなく
## 色の入れ替えに見える）。

## 明滅する記号と、出したままの文言。
const CARET_TEXT: String = "> "
const BODY_TEXT: String = "はじめる"
const TEXT_RED: Color = Color(0.92, 0.0, 0.0, 1.0)
const BLINK_PERIOD: float = 1.15
const LIT_DURATION: float = 0.78
## ゲーム共通のフォント（project.godot の gui/theme/custom_font と同じもの）。
const PROMPT_FONT := preload("res://assets/fonts/ShipporiMinchoB1-ExtraBold.ttf")
## 太らせ量。Shippori Mincho B1 は ExtraBold が最大ウェイトなので、それ以上は
## FontVariation で合成する。0.0 で素のまま、上げすぎると「は」「め」の内側が潰れる。
const EMBOLDEN: float = 0.06

var _font: Font = null
var _elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if EMBOLDEN > 0.0:
		var variation := FontVariation.new()
		variation.base_font = PROMPT_FONT
		variation.variation_embolden = EMBOLDEN
		_font = variation
	else:
		_font = PROMPT_FONT
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


## 記号が出ている周期かどうか。テスト・デバッグ用。
func caret_visible() -> bool:
	return fmod(_elapsed, BLINK_PERIOD) < LIT_DURATION


func _draw() -> void:
	if _font == null:
		return
	var font_size: int = maxi(54, roundi(size.y * 0.092))
	# 記号が消えても文言が動かないよう、位置は常に全体の幅で決める。
	var total_width: float = _font.get_string_size(CARET_TEXT + BODY_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var caret_width: float = _font.get_string_size(CARET_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var origin := Vector2((size.x - total_width) * 0.5, size.y * 0.575)
	if caret_visible():
		draw_string(_font, origin, CARET_TEXT,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, TEXT_RED)
	draw_string(_font, origin + Vector2(caret_width, 0.0), BODY_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, TEXT_RED)
