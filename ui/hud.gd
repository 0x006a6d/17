extends CanvasLayer
class_name Hud

const MIN_BLINK_PERIOD: float = 0.001

## ベルトスクロール版の HUD（technical-spec §13）。表示は 6 点だけ。
##   1. プレイヤー HP（Health.hp_changed を購読。毎フレーム参照しない）
##   2. 残機（RunState.lives_changed を購読）
##   3. 現在の武器（PlayerWeapon.weapon_changed を購読）
##   4. 銃の残弾・リロード状態（PlayerWeapon の通知を購読）
##   5. ボスバー（StageDirector.boss_started で表示し、ボスの Health を購読）
##   6. GO 表示（StageDirector.lock_cleared で右端に点滅）
##   7. 面の題名（StageDirector.stage_title_shown で画面上中央に出す）
##   8. 得点（RunState.score_changed を購読。画面右上）
## 入力表示（InputLog）はデバッグ用に残し、既定では隠す。

@export_group("Connections")
@export var health_path: NodePath
@export var weapon_path: NodePath = ^"../Player/PlayerWeapon"
## 旧版との互換のために残す（使わない）。
@export var camera_path: NodePath

@export_group("Behaviour")
## GO 表示を出している秒数。
@export var go_duration: float = 2.0
## 面の題名を出している秒数。0 以下なら消さずに出し続ける。
@export var stage_title_duration: float = 3.5
## 題名が消えるときのフェード秒数。
@export var stage_title_fade: float = 0.6
## GO 表示の点滅周期（秒）。
@export var go_blink_period: float = 0.4
## 入力表示（デバッグ）を出す。
@export var debug_input_log: bool = false
## 武器欄の表示文言。
@export var weapon_none_text: String = "武器  素手"
@export var weapon_gun_text: String = "武器  銃"
@export var weapon_katana_text: String = "武器  日本刀"
@export var ammo_format: String = "残弾  %d / %d"
@export var reloading_text: String = "残弾  リロード中"
## 残弾0で空撃ちしたときの点滅時間と周期（秒）。
@export var empty_ammo_flash_duration: float = 0.4
@export var empty_ammo_flash_period: float = 0.08

@export_group("Colors")
@export var panel_color: Color = Color(0.035, 0.04, 0.07, 0.86)
@export var text_color: Color = Color(0.94, 0.95, 1.0, 1.0)
@export var accent_color: Color = Color("5A4C97")
@export var hp_background_color: Color = Color(0.11, 0.12, 0.17, 0.95)
@export var hp_fill_color: Color = Color(0.42, 0.85, 0.72, 1.0)
@export var boss_fill_color: Color = Color(0.92, 0.36, 0.32, 1.0)
@export var go_color: Color = Color(1.0, 0.86, 0.25, 1.0)
@export var score_color: Color = Color(1.0, 0.93, 0.62, 1.0)
@export var stage_title_color: Color = Color(0.94, 0.95, 1.0, 1.0)
@export var stage_title_outline_color: Color = Color(0.02, 0.02, 0.05, 1.0)
@export var empty_ammo_color: Color = Color(1.0, 0.22, 0.18, 1.0)

@export_group("Node Paths")
@export var status_panel_path: NodePath = ^"Screen/StatusPanel"
@export var hp_label_path: NodePath = ^"Screen/StatusPanel/Margin/Rows/HpLabel"
@export var hp_bar_path: NodePath = ^"Screen/StatusPanel/Margin/Rows/HpBar"
@export var lives_label_path: NodePath = ^"Screen/StatusPanel/Margin/Rows/LivesLabel"
@export var weapon_label_path: NodePath = ^"Screen/StatusPanel/Margin/Rows/WeaponLabel"
@export var ammo_label_path: NodePath = ^"Screen/StatusPanel/Margin/Rows/AmmoLabel"
@export var boss_panel_path: NodePath = ^"Screen/BossPanel"
@export var boss_name_path: NodePath = ^"Screen/BossPanel/Margin/Rows/NameLabel"
@export var boss_bar_path: NodePath = ^"Screen/BossPanel/Margin/Rows/HpBar"
@export var go_label_path: NodePath = ^"Screen/GoLabel"
@export var stage_title_label_path: NodePath = ^"Screen/StageTitleLabel"
@export var score_panel_path: NodePath = ^"Screen/ScorePanel"
@export var score_label_path: NodePath = ^"Screen/ScorePanel/Margin/Rows/ScoreLabel"
@export var score_caption_path: NodePath = ^"Screen/ScorePanel/Margin/Rows/CaptionLabel"
@export var input_log_path: NodePath = ^"Screen/InputLog"
@export_group("")

var _health: Health = null
var _weapon: PlayerWeapon = null
var _status_panel: Panel = null
var _hp_label: Label = null
var _hp_bar: ProgressBar = null
var _lives_label: Label = null
var _weapon_label: Label = null
var _ammo_label: Label = null
var _boss_panel: Panel = null
var _boss_name: Label = null
var _boss_bar: ProgressBar = null
var _go_label: Label = null
var _stage_title_label: Label = null
var _score_panel: Panel = null
var _score_label: Label = null
var _score_caption: Label = null
var _stage_title_tween: Tween = null
var _boss: Node3D = null
var _boss_health: Health = null
var _go_left: float = 0.0
var _ammo_flash_left: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_status_panel = get_node_or_null(status_panel_path) as Panel
	_hp_label = get_node_or_null(hp_label_path) as Label
	_hp_bar = get_node_or_null(hp_bar_path) as ProgressBar
	_lives_label = get_node_or_null(lives_label_path) as Label
	_weapon_label = get_node_or_null(weapon_label_path) as Label
	_ammo_label = get_node_or_null(ammo_label_path) as Label
	_boss_panel = get_node_or_null(boss_panel_path) as Panel
	_boss_name = get_node_or_null(boss_name_path) as Label
	_boss_bar = get_node_or_null(boss_bar_path) as ProgressBar
	_go_label = get_node_or_null(go_label_path) as Label
	_stage_title_label = get_node_or_null(stage_title_label_path) as Label
	_score_panel = get_node_or_null(score_panel_path) as Panel
	_score_label = get_node_or_null(score_label_path) as Label
	_score_caption = get_node_or_null(score_caption_path) as Label
	var input_log := get_node_or_null(input_log_path) as Control
	if input_log != null:
		input_log.visible = debug_input_log
	_health = get_node_or_null(health_path) as Health
	_weapon = get_node_or_null(weapon_path) as PlayerWeapon
	_apply_visual_settings()
	if _health != null:
		_health.hp_changed.connect(_on_hp_changed)
		_on_hp_changed(_health.current_hp(), _health.max_hp)
	else:
		_on_hp_changed(0.0, 0.0)
	RunState.lives_changed.connect(_on_lives_changed)
	_on_lives_changed(RunState.lives)
	RunState.score_changed.connect(_on_score_changed)
	_on_score_changed(RunState.score)
	if _weapon != null:
		_weapon.weapon_changed.connect(_on_weapon_changed)
		_weapon.ammo_changed.connect(_on_ammo_changed)
		_weapon.dry_fired.connect(_on_dry_fired)
		_weapon.reload_started.connect(_on_reload_started)
		_weapon.reload_finished.connect(_on_reload_finished)
		_on_weapon_changed(_weapon.kind())
	else:
		_on_weapon_changed(PlayerWeapon.WeaponKind.NONE)
	StageDirector.boss_started.connect(_on_boss_started)
	StageDirector.boss_defeated.connect(_on_boss_defeated)
	StageDirector.lock_cleared.connect(_on_lock_cleared)
	StageDirector.stage_title_shown.connect(show_stage_title)
	if _boss_panel != null:
		_boss_panel.visible = false
	if _go_label != null:
		_go_label.visible = false
	if _stage_title_label != null:
		_stage_title_label.visible = false


func _process(delta: float) -> void:
	if _go_left > 0.0:
		_go_left -= delta
		if _go_label != null:
			var blink_on := fmod(go_duration - _go_left, go_blink_period) < go_blink_period * 0.5
			_go_label.visible = _go_left > 0.0 and blink_on
	if _ammo_flash_left > 0.0:
		_ammo_flash_left = maxf(_ammo_flash_left - delta, 0.0)
		if _ammo_label != null:
			var period: float = maxf(empty_ammo_flash_period, MIN_BLINK_PERIOD)
			var elapsed: float = empty_ammo_flash_duration - _ammo_flash_left
			var flash_on: bool = fmod(elapsed, period) < period * 0.5
			_ammo_label.add_theme_color_override(&"font_color",
				empty_ammo_color if flash_on else text_color)
		if _ammo_flash_left <= 0.0:
			_reset_ammo_flash()


func _on_hp_changed(current: float, maximum: float) -> void:
	if _hp_label != null:
		_hp_label.text = "HP   %d / %d" % [roundi(current), roundi(maximum)]
	if _hp_bar != null:
		_hp_bar.max_value = maxf(maximum, 1.0)
		_hp_bar.value = clampf(current, 0.0, _hp_bar.max_value)


func _on_score_changed(score: int) -> void:
	if _score_label != null:
		_score_label.text = str(score)


func _on_lives_changed(lives: int) -> void:
	if _lives_label != null:
		_lives_label.text = "残機  ×無限" if RunState.infinite_lives else "残機  ×%d" % lives


func _on_weapon_changed(kind: int) -> void:
	if _weapon_label != null:
		match kind:
			PlayerWeapon.WeaponKind.GUN:
				_weapon_label.text = weapon_gun_text
			PlayerWeapon.WeaponKind.KATANA:
				_weapon_label.text = weapon_katana_text
			_:
				_weapon_label.text = weapon_none_text
	_update_ammo_display()
	if kind != PlayerWeapon.WeaponKind.GUN:
		_reset_ammo_flash()


func _on_ammo_changed(_ammo: int, _kind: int) -> void:
	_update_ammo_display()


func _on_dry_fired() -> void:
	_update_ammo_display()
	_ammo_flash_left = maxf(empty_ammo_flash_duration, 0.0)
	if _ammo_label != null and _ammo_flash_left > 0.0:
		_ammo_label.add_theme_color_override(&"font_color", empty_ammo_color)


func _on_reload_started() -> void:
	_reset_ammo_flash()
	_update_ammo_display()


func _on_reload_finished() -> void:
	_update_ammo_display()


func _update_ammo_display() -> void:
	if _ammo_label == null:
		return
	var gun_equipped: bool = _weapon != null \
		and _weapon.kind() == PlayerWeapon.WeaponKind.GUN
	_ammo_label.visible = gun_equipped
	if not gun_equipped:
		return
	if _weapon.is_reloading():
		_ammo_label.text = reloading_text
	else:
		_ammo_label.text = ammo_format % [_weapon.ammo(), _weapon.max_ammo()]


func _reset_ammo_flash() -> void:
	_ammo_flash_left = 0.0
	if _ammo_label != null:
		_ammo_label.add_theme_color_override(&"font_color", text_color)


func _on_boss_started(boss: Node3D) -> void:
	_boss = boss
	_boss_health = boss.get_node_or_null(^"Health") as Health if boss != null else null
	if _boss_name != null and boss != null:
		_boss_name.text = String(boss.call("display_name")) \
			if boss.has_method("display_name") else String(boss.name)
	if _boss_health != null:
		_boss_health.hp_changed.connect(_on_boss_hp_changed)
		_on_boss_hp_changed(_boss_health.current_hp(), _boss_health.max_hp)
	if _boss_panel != null:
		_boss_panel.visible = _boss_health != null
	# ボスバーと同じ画面上中央に出るので、ボス戦に入ったら題名は消す。
	_hide_stage_title()


func _on_boss_hp_changed(current: float, maximum: float) -> void:
	if _boss_bar != null:
		_boss_bar.max_value = maxf(maximum, 1.0)
		_boss_bar.value = clampf(current, 0.0, _boss_bar.max_value)


func _on_boss_defeated() -> void:
	if _boss_health != null and _boss_health.hp_changed.is_connected(_on_boss_hp_changed):
		_boss_health.hp_changed.disconnect(_on_boss_hp_changed)
	_boss = null
	_boss_health = null
	if _boss_panel != null:
		_boss_panel.visible = false


## 面の題名を画面上中央に出す。stage_title_duration が正なら、その秒数でフェードして消す。
func show_stage_title(title: String) -> void:
	if _stage_title_label == null or title.is_empty():
		return
	if _stage_title_tween != null and _stage_title_tween.is_valid():
		_stage_title_tween.kill()
	_stage_title_tween = null
	_stage_title_label.text = title
	_stage_title_label.modulate.a = 1.0
	_stage_title_label.visible = true
	if stage_title_duration <= 0.0:
		return
	_stage_title_tween = create_tween()
	_stage_title_tween.tween_interval(stage_title_duration)
	_stage_title_tween.tween_property(_stage_title_label, "modulate:a", 0.0,
		maxf(stage_title_fade, 0.0))
	_stage_title_tween.tween_callback(_hide_stage_title)


func _hide_stage_title() -> void:
	if _stage_title_tween != null and _stage_title_tween.is_valid():
		_stage_title_tween.kill()
	_stage_title_tween = null
	if _stage_title_label != null:
		_stage_title_label.visible = false
		_stage_title_label.modulate.a = 1.0


## 題名が出ているか（検証用）。
func stage_title_visible() -> bool:
	return _stage_title_label != null and _stage_title_label.visible


func _on_lock_cleared(_lock_index: int) -> void:
	_go_left = go_duration
	if _go_label != null:
		_go_label.visible = true


func _apply_visual_settings() -> void:
	if _status_panel != null:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = panel_color
		panel_style.border_color = accent_color
		panel_style.set_border_width_all(2)
		_status_panel.add_theme_stylebox_override(&"panel", panel_style)
	for label: Label in [_hp_label, _lives_label, _weapon_label, _ammo_label, _boss_name,
			_score_caption]:
		if label != null:
			label.add_theme_color_override(&"font_color", text_color)
	if _score_label != null:
		_score_label.add_theme_color_override(&"font_color", score_color)
	if _score_panel != null:
		var score_style := StyleBoxFlat.new()
		score_style.bg_color = panel_color
		score_style.border_color = accent_color
		score_style.set_border_width_all(2)
		_score_panel.add_theme_stylebox_override(&"panel", score_style)
	if _boss_panel != null:
		var boss_style := StyleBoxFlat.new()
		boss_style.bg_color = panel_color
		boss_style.border_color = accent_color
		boss_style.set_border_width_all(2)
		_boss_panel.add_theme_stylebox_override(&"panel", boss_style)
	for bar: ProgressBar in [_hp_bar, _boss_bar]:
		if bar == null:
			continue
		var background_style := StyleBoxFlat.new()
		background_style.bg_color = hp_background_color
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = hp_fill_color if bar == _hp_bar else boss_fill_color
		bar.add_theme_stylebox_override(&"background", background_style)
		bar.add_theme_stylebox_override(&"fill", fill_style)
	if _go_label != null:
		_go_label.add_theme_color_override(&"font_color", go_color)
	if _stage_title_label != null:
		# 背景の板に重なっても読めるよう、題名だけ縁取りを付ける。
		_stage_title_label.add_theme_color_override(&"font_color", stage_title_color)
		_stage_title_label.add_theme_color_override(&"font_outline_color",
			stage_title_outline_color)
		_stage_title_label.add_theme_constant_override(&"outline_size", 8)


func hp_display_text() -> String:
	return _hp_label.text if _hp_label != null else ""


func hp_bar_value() -> float:
	return _hp_bar.value if _hp_bar != null else 0.0


func weapon_display_text() -> String:
	return _weapon_label.text if _weapon_label != null else ""


func ammo_display_text() -> String:
	return _ammo_label.text if _ammo_label != null else ""


func ammo_label_visible() -> bool:
	return _ammo_label != null and _ammo_label.visible


func ammo_flash_active() -> bool:
	return _ammo_flash_left > 0.0


func boss_panel_visible() -> bool:
	return _boss_panel != null and _boss_panel.visible


func go_label_visible() -> bool:
	return _go_label != null and _go_label.visible
