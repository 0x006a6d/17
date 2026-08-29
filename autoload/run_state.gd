extends Node

## 唯一のグローバル可変状態（technical-spec §4）。残機・コンティニュー・進行中の面と、
## 表示用の撃破数だけを持つ。進行判定（波の全滅・面の終了）は StageDirector が担い、
## ここは _process() を持たない。

signal lives_changed(lives: int)
signal continues_changed(continues: int)
signal stage_changed(stage: int)
signal score_changed(score: int)

## 開始時の残機。
@export var initial_lives: int = 3
## 無限に生き返る（残機を減らさず、必ず立ち上がる）。playtest 用。提出時は false にする。
@export var infinite_lives: bool = true
## 開始時のコンティニュー回数。
@export var initial_continues: int = 3

@export_group("Score")
## 1発当てるごとの基礎点。素手が一番高く、日本刀・銃の順に下げる。
@export var score_hit_unarmed: int = 100
@export var score_hit_katana: int = 60
@export var score_hit_gun: int = 30
## コンボの段数を基礎点に掛ける。段が進むほど1発の価値が上がり、繋げるほど有利になる
## （素手7段なら 100×(1+2+…+7)=2800 で、単発7回の 700 の4倍）。
@export var score_combo_multiplier: bool = true
## 敵を1体倒したときの加点。武器によらず同じ。
@export var score_defeat_bonus: int = 200
## 死亡（残機を1つ失う）ごとの減点。0 未満にはしない。
@export var score_death_penalty: int = 500
@export_group("")

var lives: int = 3
var continues: int = 3
var current_stage: int = GameTypes.Stage.STAGE_1
## 表示用。進行判定には使わない。
var enemies_downed: int = 0
## 得点。HUD の右上に出し、ゲーム終了時の結果画面で使う。
var score: int = 0


func _ready() -> void:
	reset()


## 残機を 1 減らす。まだ残っていれば true、尽きていれば false（コンティニュー待ち）。
## infinite_lives のときは減らさず、必ず true（無限に生き返る）。
func lose_life() -> bool:
	if infinite_lives:
		lives_changed.emit(lives)
		return true
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)
	return lives > 0


## コンティニューを 1 消費して残機を初期値へ戻す。残っていなければ false。
func use_continue() -> bool:
	if continues <= 0:
		return false
	continues -= 1
	continues_changed.emit(continues)
	lives = initial_lives
	lives_changed.emit(lives)
	return true


## 攻撃が当たったときの加点。combo_stage は1始まりの段数（銃は常に1）。
func add_hit_score(weapon_kind: int, combo_stage: int = 1) -> void:
	var base: int = score_hit_unarmed
	match weapon_kind:
		GameTypes.ScoreWeapon.KATANA:
			base = score_hit_katana
		GameTypes.ScoreWeapon.GUN:
			base = score_hit_gun
	var multiplier: int = maxi(combo_stage, 1) if score_combo_multiplier else 1
	_add_score(base * multiplier)


## 敵を1体倒したときの加点。
func add_defeat_score() -> void:
	_add_score(score_defeat_bonus)


## 死亡の減点。0 未満にはしない。
func apply_death_penalty() -> void:
	_add_score(-score_death_penalty)


func _add_score(delta: int) -> void:
	var next: int = maxi(score + delta, 0)
	if next == score:
		return
	score = next
	score_changed.emit(score)


func set_stage(stage: int) -> void:
	if stage == current_stage:
		return
	current_stage = stage
	stage_changed.emit(current_stage)


## 全フィールドを初期状態へ戻す。新規ゲーム開始時に呼ぶ。
func reset() -> void:
	lives = initial_lives
	continues = initial_continues
	current_stage = GameTypes.Stage.STAGE_1
	enemies_downed = 0
	score = 0
	lives_changed.emit(lives)
	continues_changed.emit(continues)
	stage_changed.emit(current_stage)
	score_changed.emit(score)
