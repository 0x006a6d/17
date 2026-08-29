class_name ModelBlink
extends Node

## 消滅・復帰の直前だけモデルを薄く明滅させる共通部品。
## 色は触らず GeometryInstance3D.transparency だけを ModelTint 経由で変えるため、
## material_overlay を使う被弾フラッシュとは競合しない。

signal blink_started()
signal opacity_changed(opacity: float)

@export_group("Blink")
## 終了予定の何秒前から点滅を始めるか。
@export var start_before_end: float = 0.60
## 1回の明滅周期（秒）。
@export var period: float = 0.16
## 最も薄くなったときの不透明度。完全には消さない。
@export_range(0.0, 1.0, 0.01) var minimum_opacity: float = 0.82
@export_group("")

const HALF: float = 0.5
const OPACITY_EPSILON: float = 0.0001

var _tint: ModelTint = null
var _remaining: float = 0.0
var _blink_elapsed: float = 0.0
var _running: bool = false
var _blinking: bool = false
var _opacity: float = 1.0


func _ready() -> void:
	# TextCard がツリーを止めても、撃破後の消滅カウントと同じ実時間で進める。
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


## ModelTint は表示モデルを差し込んだ本体側から注入する。
func setup(tint: ModelTint) -> void:
	_tint = tint


## total_duration の終端を消滅または復帰開始時刻としてカウントする。
func begin(total_duration: float) -> void:
	finish()
	if _tint == null or total_duration <= 0.0:
		return
	_remaining = total_duration
	_running = true
	set_process(true)
	if _remaining <= maxf(start_before_end, 0.0):
		_begin_blink()


func finish() -> void:
	_running = false
	_blinking = false
	_remaining = 0.0
	_blink_elapsed = 0.0
	set_process(false)
	_set_opacity(1.0)


func _process(delta: float) -> void:
	if not _running:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	if not _blinking and _remaining <= maxf(start_before_end, 0.0):
		_begin_blink()
	if _blinking:
		_blink_elapsed += delta
		var safe_period: float = maxf(period, OPACITY_EPSILON)
		var phase: float = fposmod(_blink_elapsed, safe_period) / safe_period
		var pulse: float = (1.0 - cos(phase * TAU)) * HALF
		_set_opacity(lerpf(1.0, clampf(minimum_opacity, 0.0, 1.0), pulse))
	if _remaining <= 0.0:
		_running = false
		set_process(false)


func _begin_blink() -> void:
	if _blinking:
		return
	_blinking = true
	_blink_elapsed = 0.0
	blink_started.emit()


func _set_opacity(value: float) -> void:
	var next: float = clampf(value, 0.0, 1.0)
	if absf(next - _opacity) <= OPACITY_EPSILON:
		return
	_opacity = next
	if _tint != null:
		_tint.apply_opacity(_opacity)
	opacity_changed.emit(_opacity)


## headless 検証用。
func is_blinking() -> bool:
	return _blinking


## headless 検証用。
func current_opacity() -> float:
	return _opacity
