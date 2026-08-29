class_name DamageRoll

## ダメージと回復の数字を「端数のある整数」にするための揺らぎ。
##
## 基礎値へ 1%〜variance の上振れを掛けて整数へ丸める。上へだけ振るのは、
## 主人公の攻撃を常に4桁に保つため（基礎値 1000 の左ジャブが 3桁へ落ちない）。
## 丸めるのは小数点付きの表示を出さないため。
##
## 振れ幅は呼び出し側が渡す（`Health.damage_variance`）。0 を渡すと丸めだけを行い、
## 基礎値どおりの数になる。検証で厳密な値を見たいときはそちらを使う。

## 上振れの上限の既定値（0.12 なら +1%〜+12%）。
const DEFAULT_VARIANCE: float = 0.12


static func roll(base: float, variance: float = DEFAULT_VARIANCE) -> float:
	if base <= 0.0:
		return 0.0
	if variance <= 0.0:
		return roundf(base)
	return roundf(base * (1.0 + randf_range(0.01, variance)))
