extends CanvasLayer
class_name TextCard

## OP / 幕間 / 開示 / ED で共用するテキストカード（technical-spec §11）。
## 表示中は SceneTree を止め、自分だけ PROCESS_MODE_ALWAYS で動く。
## 文言は lines（面側の @export）で受け取り、ここには直書きしない。
##
## 台本の `名前「…」` 形式の行は話者付きとして扱い、通話画面の体裁で出す。
##   - 話者のタイル（立ち絵・名前）を SpeakerProfile.side の側、文章を反対側に置く
##   - 話者が変わる行、または空行 "" でページを切る
##   - 名前の無い行は地の文としてタイル無しで出す（左揃え）
## タイプ表示はタイマーを持たず、経過時間から visible_characters を算出する。
## ui_accept: 表示途中なら全文を出し、出し終わっていれば次のページ、無ければ閉じる。

signal closed()

@export var lines: Array[String] = []
## 左に出す立ち絵（話者の無い地の文で使う。OP の捜索写真など）。無ければ非表示。
@export var portrait: Texture2D
## 受信記録の体裁（等幅・緑）。地の文に効く。
@export var monospace_green: bool = false
## 1 秒あたりに表示する文字数。
@export var chars_per_second: float = 45.0
## 0 より大きければ、表示完了からこの秒数後に自動で閉じる。0 なら ui_accept 待ち。
@export var auto_close_after: float = 0.0
## 表示開始時にツリーを止める。
@export var pause_tree: bool = true
## 話者の定義。台本の名前で引く。
@export var speakers: Array[SpeakerProfile] = []
## 文字色。
@export var text_color: Color = Color(0.94, 0.95, 1.0, 1.0)
@export var green_color: Color = Color(0.45, 0.95, 0.55, 1.0)
@export var panel_color: Color = Color(0.02, 0.02, 0.04, 0.92)
## 話者タイルの地色（通話画面の参加者枠）。
@export var tile_color: Color = Color(0.18, 0.19, 0.21, 1.0)
## タイルの枠線の太さ・角の丸み。
@export var tile_border_width: int = 3
@export var tile_corner_radius: int = 10

@export_group("Node Paths")
@export var panel_path: NodePath = ^"Screen/Panel"
@export var label_path: NodePath = ^"Screen/Panel/Margin/Rows/Body/Text"
@export var portrait_path: NodePath = ^"Screen/Panel/Margin/Rows/Body/Portrait"
## ページの区切りに使う行。台本（`nike_story_design.md`）の区切りと同じ書き方にする。
const PAGE_BREAK: String = "---"

@export var prompt_path: NodePath = ^"Screen/Panel/Margin/Rows/Footer/Prompt"
## スキップの案内。カードを出している間は常に見せる。
@export var skip_path: NodePath = ^"Screen/Panel/Margin/Rows/Footer/Skip"
@export var tile_left_path: NodePath = ^"Screen/Panel/Margin/Rows/Body/TileLeft"
@export var tile_right_path: NodePath = ^"Screen/Panel/Margin/Rows/Body/TileRight"
@export_group("")

## 1 ページぶんの内容。speaker が null なら地の文。
class Page:
	var speaker: SpeakerProfile = null
	var text: String = ""

var _label: RichTextLabel = null
var _portrait: TextureRect = null
var _prompt: Label = null
var _skip: Label = null
var _panel: Panel = null
var _tiles: Dictionary = {}
var _elapsed: float = 0.0
var _total_chars: int = 0
var _open: bool = false
var _finished_at: float = -1.0
var _was_paused: bool = false
var _pages: Array[Page] = []
var _page_index: int = 0
var _avatar_cache: Dictionary = {}
## 直近の close が ui_accept によるものか（false なら auto_close_after による）。
var closed_by_accept: bool = false
## 同一フレームで入力経路（_input/_unhandled_input/_process ポーリング）が二重発火しないためのロック。
var _accept_lock: bool = false
var _skip_lock: bool = false
var _skip_down: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	_panel = get_node_or_null(panel_path) as Panel
	_label = get_node_or_null(label_path) as RichTextLabel
	_portrait = get_node_or_null(portrait_path) as TextureRect
	_prompt = get_node_or_null(prompt_path) as Label
	_skip = get_node_or_null(skip_path) as Label
	_tiles[SpeakerProfile.Side.LEFT] = get_node_or_null(tile_left_path) as PanelContainer
	_tiles[SpeakerProfile.Side.RIGHT] = get_node_or_null(tile_right_path) as PanelContainer
	visible = false
	set_process(false)


## 表示を開始する。lines を差し替えてから呼んでよい。
func show_card() -> void:
	if _label == null:
		push_warning("text_card: Text ラベルが無い")
		closed.emit()
		return
	_pages = _build_pages(lines)
	if _pages.is_empty():
		var empty := Page.new()
		_pages.append(empty)
	_page_index = 0
	_open = true
	visible = true
	if pause_tree:
		_was_paused = get_tree().paused
		get_tree().paused = true
	_show_page(_pages[0])
	set_process(true)
	# ゲームウィンドウにキーボードフォーカスを取りに行く（エディタ側にフォーカスが残ると
	# キー入力が届かないため）。
	var window := get_window()
	if window != null:
		window.grab_focus()


func is_open() -> bool:
	return _open


func is_fully_shown() -> bool:
	return _open and _label != null and _label.visible_characters < 0


func page_count() -> int:
	return _pages.size()


func page_index() -> int:
	return _page_index


## 今のページの話者。地の文なら null。
func current_speaker() -> SpeakerProfile:
	if _pages.is_empty():
		return null
	return _pages[_page_index].speaker


# --- ページ分割 ---------------------------------------------------------------

## `名前「本文」` を話者と本文に分ける。名前が speakers に無ければ地の文として扱う。
func _split_line(line: String) -> Array:
	var open_at := line.find("「")
	if open_at <= 0:
		return [null, line]
	var speaker_name := line.substr(0, open_at).strip_edges()
	var profile := _find_speaker(speaker_name)
	if profile == null:
		return [null, line]
	var body := line.substr(open_at + 1)
	if body.ends_with("」"):
		body = body.substr(0, body.length() - 1)
	return [profile, body]


func _find_speaker(speaker_name: String) -> SpeakerProfile:
	for profile in speakers:
		if profile != null and profile.speaker_name == speaker_name:
			return profile
	return null


## 1行が1ページ。空行と "---" は台本上の区切りで、画面には出さない。
func _build_pages(source: Array[String]) -> Array[Page]:
	var pages: Array[Page] = []
	for line: String in source:
		if line.is_empty() or line.strip_edges() == PAGE_BREAK:
			continue
		var parts := _split_line(line)
		var page := Page.new()
		page.speaker = parts[0] as SpeakerProfile
		page.text = String(parts[1])
		pages.append(page)
	return pages


# --- ページの表示 ---------------------------------------------------------------

func _show_page(page: Page) -> void:
	_apply_style(page.speaker)
	_label.text = page.text
	# RichTextLabel.get_total_character_count() はレイアウト後でないと 0 を返すことがあるため、
	# 文字列長から数える（タグは使わないので一致する）。
	_total_chars = page.text.length()
	_label.visible_characters = 0
	_elapsed = 0.0
	_finished_at = -1.0
	if _portrait != null:
		_portrait.texture = portrait
		_portrait.visible = portrait != null and page.speaker == null
	for side: int in _tiles:
		var tile := _tiles[side] as PanelContainer
		if tile == null:
			continue
		var active: bool = page.speaker != null and page.speaker.side == side
		tile.visible = active
		if active:
			_fill_tile(tile, page.speaker)
	if _prompt != null:
		# 送り方の案内は最初から出す。文字送りの途中でも送れるので、出ていないと
		# 「まだ押せない」ように見える。自動で閉じるカードは操作が要らないので出さない。
		_prompt.visible = auto_close_after <= 0.0


func _fill_tile(tile: PanelContainer, speaker: SpeakerProfile) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = tile_color
	style.border_color = speaker.color
	style.set_border_width_all(tile_border_width)
	style.set_corner_radius_all(tile_corner_radius)
	tile.add_theme_stylebox_override(&"panel", style)
	var avatar := tile.get_node_or_null(^"Frame/Avatar") as TextureRect
	if avatar != null:
		avatar.texture = _avatar_for(speaker)
		avatar.visible = avatar.texture != null
	var name_label := tile.get_node_or_null(^"Frame/Name") as Label
	if name_label != null:
		name_label.text = speaker.label()
		name_label.add_theme_color_override(&"font_color", speaker.color)


## 立ち絵から顔の正方形を切り出したテクスチャ。無ければ null。話者ごとにキャッシュする。
func _avatar_for(speaker: SpeakerProfile) -> Texture2D:
	var key := speaker.portrait_path
	if key.is_empty():
		return null
	if _avatar_cache.has(key):
		return _avatar_cache[key] as Texture2D
	var result: Texture2D = null
	if ResourceLoader.exists(key):
		var source := load(key) as Texture2D
		if source != null:
			var image := source.get_image()
			if image != null:
				var region := speaker.portrait_region
				if region.size.x > 0 and region.size.y > 0:
					image = image.get_region(region)
				result = ImageTexture.create_from_image(image)
	_avatar_cache[key] = result
	return result


# --- 進行 ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _open:
		return
	# 実キーボードは Input シングルトンのポーリングで拾う（ポーズ中も OS 駆動で更新され、
	# _input/_unhandled_input が届かない環境でも確実）。合成入力（テスト）は _input 経路が拾う。
	# エッジ検出は毎フレーム回す。ロックで短絡させると押した状態を取り込めず、
	# 次のフレームで「今押された」と誤検出して、1回の押しで文字送りの完了と
	# ページ送りが両方起きてしまう。
	var edge: bool = _accept_edge()
	var polled: bool = Input.is_action_just_pressed("ui_accept")
	if not _accept_lock and (polled or edge):
		_do_accept()
	_accept_lock = false
	if _skip_edge() and not _skip_lock:
		skip()
	_skip_lock = false
	_elapsed += delta
	if _label.visible_characters >= 0:
		var shown := int(_elapsed * chars_per_second)
		if shown >= _total_chars:
			_complete_text()
		else:
			_label.visible_characters = shown
	elif auto_close_after > 0.0 and _finished_at >= 0.0 \
			and _elapsed - _finished_at >= auto_close_after:
		_advance(false)


## 入力は _unhandled_input と _input の両方で受ける。ポーズ中も ALWAYS で届き、
## _input 側は他ノードが握る前に拾えるため、環境差で取りこぼしにくい。
func _unhandled_input(event: InputEvent) -> void:
	_from_event(event)


func _input(event: InputEvent) -> void:
	_from_event(event)


func _from_event(event: InputEvent) -> void:
	if not _open or _accept_lock:
		return
	var accept := event.is_action_pressed("ui_accept")
	if not accept and event is InputEventKey and event.pressed and not event.echo:
		var kc: int = (event as InputEventKey).physical_keycode
		accept = kc == KEY_ENTER or kc == KEY_KP_ENTER or kc == KEY_SPACE
	if not accept and event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		accept = true
	# パッド: ○（PS）/ B（Xbox 配列）で進む。
	if not accept and event is InputEventJoypadButton and event.pressed \
			and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		accept = true
	var skip_pressed: bool = event is InputEventKey and event.pressed \
		and not (event as InputEventKey).echo \
		and (event as InputEventKey).physical_keycode == KEY_ESCAPE
	if not skip_pressed and event is InputEventJoypadButton and event.pressed \
			and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y:
		skip_pressed = true
	if skip_pressed:
		get_viewport().set_input_as_handled()
		skip()
		return
	if not accept:
		return
	get_viewport().set_input_as_handled()
	_do_accept()


## 押しっぱなしで連続発火しないためのエッジ検出（直接ポーリング版）。
## Enter / KP Enter / Space / 左クリック / パッドの ○ を OS 状態から直接読む（フォーカス配下で確実）。
var _accept_down: bool = false
func _accept_edge() -> bool:
	var down := Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER) \
		or Input.is_key_pressed(KEY_SPACE) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not down:
		for device in Input.get_connected_joypads():
			if Input.is_joy_button_pressed(device, JOY_BUTTON_B):
				down = true
				break
	var edge := down and not _accept_down
	_accept_down = down
	return edge


## スキップの押し下がりを見る（Esc / パッドの △）。
func _skip_edge() -> bool:
	var down: bool = Input.is_key_pressed(KEY_ESCAPE)
	if not down:
		for device: int in Input.get_connected_joypads():
			if Input.is_joy_button_pressed(device, JOY_BUTTON_Y):
				down = true
				break
	var edge: bool = down and not _skip_down
	_skip_down = down
	return edge


## 残りのページを飛ばしてカードを閉じる。閉じ方は最後まで送ったときと同じ扱いにする。
func skip() -> void:
	if not _open:
		return
	_skip_lock = true
	_page_index = maxi(_pages.size() - 1, 0)
	close(true)


## 受理を1回だけ処理する（同一フレームの他経路はロックで弾く）。
func _do_accept() -> void:
	_accept_lock = true
	if _label.visible_characters >= 0:
		_complete_text()
	else:
		_advance(true)


## 次のページがあれば進み、無ければ閉じる。
func _advance(by_accept: bool) -> void:
	if _page_index + 1 < _pages.size():
		_page_index += 1
		_show_page(_pages[_page_index])
		return
	close(by_accept)


func _complete_text() -> void:
	_label.visible_characters = -1
	_finished_at = _elapsed
	if _prompt != null and auto_close_after <= 0.0:
		_prompt.visible = true


func close(by_accept: bool = false) -> void:
	if not _open:
		return
	closed_by_accept = by_accept
	_open = false
	visible = false
	set_process(false)
	if pause_tree:
		get_tree().paused = _was_paused
	closed.emit()


func _apply_style(speaker: SpeakerProfile) -> void:
	var green := monospace_green and speaker == null
	if _panel != null:
		var style := StyleBoxFlat.new()
		style.bg_color = panel_color
		style.border_color = green_color if green else Color("5A4C97")
		style.set_border_width_all(2)
		_panel.add_theme_stylebox_override(&"panel", style)
	if _label != null:
		_label.add_theme_color_override(&"default_color", green_color if green else text_color)
		if green:
			var mono := SystemFont.new()
			mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Courier New", "monospace"])
			_label.add_theme_font_override(&"normal_font", mono)
		else:
			_label.remove_theme_font_override(&"normal_font")
		# 地の文も話者付きも左揃え。
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _prompt != null:
		_prompt.add_theme_color_override(&"font_color", text_color)
