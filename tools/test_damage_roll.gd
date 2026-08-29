extends Node

## ダメージ・回復の数字が「端数のある整数」になることの検証。
##   godot --path . --headless res://tools/test_damage_roll.tscn
##
##   (1) 出る数は必ず整数（小数点を出さない）
##   (2) 基礎値を下回らない（主人公の攻撃が4桁を割らない）
##   (3) 上振れは variance の範囲に収まる
##   (4) 同じ基礎値でも値がばらける（端数が出る）
##   (5) variance = 0 なら基礎値どおり（検証用の固定）
##   (6) 素手の最小の技（1000）でも4桁のまま

const SAMPLES: int = 400
## 既定の振れ幅（Health.damage_variance の既定値と同じ）。
const VARIANCE: float = DamageRoll.DEFAULT_VARIANCE
const BASES: Array[float] = [1000.0, 1400.0, 2600.0, 4500.0, 7000.0]

var _pass: int = 0
var _fail: int = 0


func _ready() -> void:
	print("=== ダメージの端数 検証開始 ===")
	for base: float in BASES:
		var seen: Dictionary = {}
		var minimum: float = INF
		var maximum: float = -INF
		var all_integer: bool = true
		for _i: int in range(SAMPLES):
			var value: float = DamageRoll.roll(base, VARIANCE)
			if not is_equal_approx(value, roundf(value)):
				all_integer = false
			minimum = minf(minimum, value)
			maximum = maxf(maximum, value)
			seen[value] = true
		_assert("(1) %.0f は必ず整数" % base, all_integer)
		_assert("(2) %.0f は基礎値を下回らない (最小 %.0f)" % [base, minimum], minimum >= base)
		_assert("(3) %.0f の上振れは +%.0f%% まで (最大 %.0f)" % [base, VARIANCE * 100.0, maximum],
			maximum <= base * (1.0 + VARIANCE) + 0.5)
		_assert("(4) %.0f は値がばらける (%d 通り)" % [base, seen.size()], seen.size() > 10)
		_assert("(6) %.0f は4桁のまま" % base, minimum >= 1000.0 and maximum <= 9999.0)

	_assert("(5) variance = 0 なら基礎値どおり",
		is_equal_approx(DamageRoll.roll(1234.0, 0.0), 1234.0))
	_assert("(5) variance = 0 でも小数は丸める",
		is_equal_approx(DamageRoll.roll(345.6, 0.0), 346.0))
	_finish()


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
