extends CanvasLayer
class_name ResultPanel

## 最後（最終面のクリア、またはゲームオーバー）に出す結果画面。得点と、
## その得点を X へ投稿するボタンを出す。閉じたら `closed` を送り、面側が
## タイトルへ戻す。テキストカードと同じくツリーを一時停止する。

## 閉じた（タイトルへ戻ってよい）。
signal closed()

## 投稿する文言の雛形。%s に3桁区切りの得点が入る。
@export var post_format: String = "私は #AIニケちゃん で%s回ヌキました（2025年8月からの累計）"
## 投稿先。text にエンコードした文言を付けて開く。
@export var post_url_base: String = "https://x.com/intent/post?text="
@export var score_format: String = "%d 点"
@export var cleared_caption: String = "CLEAR"
@export var game_over_caption: String = "GAME OVER"

@export_group("Colors")
@export var panel_color: Color = Color(0.035, 0.04, 0.07, 0.94)
@export var accent_color: Color = Color("5A4C97")
@export var text_color: Color = Color(0.94, 0.95, 1.0, 1.0)
@export var score_color: Color = Color(1.0, 0.93, 0.62, 1.0)

@export_group("Nodes")
@export var panel_path: NodePath = ^"Screen/Panel"
@export var caption_path: NodePath = ^"Screen/Panel/Margin/Rows/CaptionLabel"
@export var score_path: NodePath = ^"Screen/Panel/Margin/Rows/ScoreLabel"
@export var post_button_path: NodePath = ^"Screen/Panel/Margin/Rows/Buttons/PostButton"
@export var close_button_path: NodePath = ^"Screen/Panel/Margin/Rows/Buttons/CloseButton"
@export_group("")

var _panel: Panel = null
var _caption: Label = null
var _score_label: Label = null
var _post_button: Button = null
var _close_button: Button = null
var _score: int = 0
var _open: bool = false
var _was_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = get_node_or_null(panel_path) as Panel
	_caption = get_node_or_null(caption_path) as Label
	_score_label = get_node_or_null(score_path) as Label
	_post_button = get_node_or_null(post_button_path) as Button
	_close_button = get_node_or_null(close_button_path) as Button
	if _post_button != null:
		_post_button.pressed.connect(_on_post_pressed)
	if _close_button != null:
		_close_button.pressed.connect(_on_close_pressed)
	_apply_colors()
	visible = false


## 結果を出す。cleared=false ならゲームオーバーの見出しにする。
func show_result(score: int, cleared: bool) -> void:
	_score = maxi(score, 0)
	if _caption != null:
		_caption.text = cleared_caption if cleared else game_over_caption
	if _score_label != null:
		_score_label.text = score_format % _score
	visible = true
	_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	if _close_button != null:
		_close_button.grab_focus()


## 決定でタイトルへ戻る。ボタンのフォーカスに頼ると、フォーカスが外れたときに
## どのキーも効かなくなるので、ここでも受ける。投稿ボタンに合わせているときだけ
## ボタン側へ譲る（そちらは押すと投稿する）。
func _input(event: InputEvent) -> void:
	if not _open or not event.is_action_pressed(&"ui_accept"):
		return
	if _post_button != null and _post_button.has_focus():
		return
	get_viewport().set_input_as_handled()
	_on_close_pressed()


func is_open() -> bool:
	return _open


## 投稿に使う文言（検証用）。
func post_text() -> String:
	return post_format % comma_separated(_score)


## 3桁ごとにカンマを入れた数字。投稿の文言だけで使う（画面の得点表示は score_format）。
static func comma_separated(value: int) -> String:
	var digits: String = str(maxi(value, 0))
	var out: String = ""
	var placed: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		placed += 1
		if placed % 3 == 0 and i > 0:
			out = "," + out
	return out


## 実際に開く URL（検証用）。
func post_url() -> String:
	return post_url_base + post_text().uri_encode()


func _on_post_pressed() -> void:
	OS.shell_open(post_url())


func _on_close_pressed() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = _was_paused
	closed.emit()


func _apply_colors() -> void:
	if _panel != null:
		var style := StyleBoxFlat.new()
		style.bg_color = panel_color
		style.border_color = accent_color
		style.set_border_width_all(2)
		_panel.add_theme_stylebox_override(&"panel", style)
	if _caption != null:
		_caption.add_theme_color_override(&"font_color", text_color)
	if _score_label != null:
		_score_label.add_theme_color_override(&"font_color", score_color)
