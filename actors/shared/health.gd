extends Node
class_name Health

## NPC/プレイヤー共通の体力・よろけ管理。technical-spec §7.1。
##
## 意味論:
## - staggered: ダウンに至らない被弾のたびに発火する
## - downed: HP が 0 まで削られたときに発火する。致死かどうかは攻撃側が持ち、
##   take_hit() の lethal 引数をそのまま通知する。ただし被弾回数が
##   stagger_threshold に達するまではダウンさせない（客の「規定回数叩かないと
##   ダウンしない」誤爆防止ルールはこの下限として機能する。HP が先に尽きても
##   回数未達なら HP 0 のまま耐えてよろけ扱いになる）。ただし、これは近接の
##   誤爆で客がダウンするのを防ぐための下限であり、
##   狙って撃つ銃撃には適用しない。

## 最大HP。
@export var max_hp: float = 10000.0
## ダメージ・回復の端数の振れ幅（`DamageRoll`）。0 にすると基礎値どおりになる。
@export var damage_variance: float = DamageRoll.DEFAULT_VARIANCE
## ダウンに要する最低被弾回数。客は 2（誤爆防止）、犯人・ダミーは 1。
@export var stagger_threshold: int = 1
## ダウン後に追い打ち成立とする命中回数。
@export var finish_hits: int = 2
## よろけ（ダウンには至らない被弾）が発生した。
signal staggered()
## HP が変化した。HUD などの表示側は毎フレーム参照せず、この通知を購読する。
signal hp_changed(current: float, maximum: float)

## 回復した。実際に増えたぶんだけを載せる（上限で切られた分は含めない）。
signal healed(amount: float)
## ダウンした。lethal=true なら致死（攻撃側の Hitbox.lethal から渡される）。
signal downed(lethal: bool)
## ダウン後の追い打ちが規定回数に達した。attacker は成立させた加害者。
signal finished(attacker: Node3D)

var _hp: float = 0.0
var _stagger_count: int = 0
var _is_downed: bool = false
var _finish_hit_count: int = 0
var _finished_emitted: bool = false


func _ready() -> void:
	_hp = max_hp


## ダメージを受ける。ダウン済みなら何もしない。
## 実際に引く量は `DamageRoll` が端数のある整数へ丸める。表示側は HP の差分から
## 数字を作るので、画面に出る数と減る量は必ず一致する。
## 既定は非致死（近接）。銃撃側は lethal=true と
## ignore_stagger_threshold=true を明示する。両方の既定を false に保つため、
## 既存の呼び出しの挙動は変わらない。
func take_hit(damage: float, lethal: bool = false,
		ignore_stagger_threshold: bool = false) -> void:
	if _is_downed:
		return
	var hp_before := _hp
	_hp = maxf(_hp - DamageRoll.roll(damage, damage_variance), 0.0)
	if not is_equal_approx(_hp, hp_before):
		hp_changed.emit(_hp, max_hp)
	_stagger_count += 1

	var threshold_met: bool = ignore_stagger_threshold or _stagger_count >= stagger_threshold
	if _hp <= 0.0 and threshold_met:
		_is_downed = true
		downed.emit(lethal)
	else:
		staggered.emit()


## 自分で払うコストを引く（必殺の消費 HP）。被弾ではないので staggered を出さない。
## これを take_hit で代用すると、掛け声（VoiceReactions）が「やられた」側で鳴る。
## 端数の揺らぎも掛けない（消費量は決まった値のほうが読みやすい）。
func spend(amount: float) -> void:
	if _is_downed or amount <= 0.0:
		return
	var hp_before := _hp
	_hp = maxf(_hp - roundf(amount), 0.0)
	if is_equal_approx(_hp, hp_before):
		return
	hp_changed.emit(_hp, max_hp)
	if _hp <= 0.0:
		_is_downed = true
		downed.emit(false)


## ダウン後の追い打ちを1回受ける。通常被弾とは独立させ、規定回数に
## 達した瞬間だけ finished を通知する。
func take_finish_hit(attacker: Node3D = null) -> bool:
	if not _is_downed or _finished_emitted:
		return false
	_finish_hit_count += 1
	if _finish_hit_count >= finish_hits:
		_finished_emitted = true
		finished.emit(attacker)
	return true


func current_hp() -> float:
	return _hp


func is_downed() -> bool:
	return _is_downed


## HP を amount だけ回復する。ダウン中は回復せず、よろけ回数も変更しない。
## 全快に加えて全カウンタを初期化する revive() とは別の通常回復処理。
func heal(amount: float) -> void:
	if _is_downed or amount <= 0.0:
		return
	var hp_before := _hp
	_hp = minf(_hp + DamageRoll.roll(amount, damage_variance), max_hp)
	if not is_equal_approx(_hp, hp_before):
		hp_changed.emit(_hp, max_hp)
		healed.emit(_hp - hp_before)


## HP・よろけ回数・追い打ち状態を初期状態へ戻す。
## 通常回復だけを行う heal() とは異なり、ダウンからの復帰専用。
func revive() -> void:
	var hp_before := _hp
	_hp = max_hp
	_stagger_count = 0
	_is_downed = false
	_finish_hit_count = 0
	_finished_emitted = false
	if not is_equal_approx(_hp, hp_before):
		hp_changed.emit(_hp, max_hp)
