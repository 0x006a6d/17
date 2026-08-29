extends Node

## 面・画面ロック・波の進行（technical-spec §5）。
## 面内の具体的な配置（ロック地点・波・ボス）は各 levels/stage_N.tscn の BeltStage が持ち、
## ここは状態遷移と通知だけを担う。可変状態は phase（進行位置）のみで、記録は RunState が持つ。
##
## 遷移:
##   CARD    -> PLAY     : テキストカードが閉じた（カードが無い面は即 PLAY）
##   PLAY    -> LOCKED   : プレイヤーが LockPoint を通過した
##   LOCKED  -> PLAY     : その LockPoint の波が全滅した
##   PLAY    -> BOSS     : プレイヤーが BossTrigger を通過した
##   BOSS    -> CLEARED  : ボスが DOWNED
##   CLEARED -> 次の面の CARD

enum Phase { CARD, PLAY, LOCKED, BOSS, CLEARED }

signal phase_changed(phase: int)
signal lock_started(lock_index: int)
signal lock_cleared(lock_index: int)
signal boss_started(boss: Node3D)
signal boss_defeated()
signal stage_cleared(stage: int)
## 面の題名を出す（HUD が画面上中央に表示する）。カードを閉じて操作が始まる時点で送る。
signal stage_title_shown(title: String)

var phase: int = Phase.CARD


## 任意のフェーズへ移る。同じフェーズへの再移行は無視する。
func set_phase(next: int) -> void:
	if next == phase:
		return
	phase = next
	phase_changed.emit(phase)


func notify_card_closed() -> void:
	if phase == Phase.CARD:
		set_phase(Phase.PLAY)


## 面の題名を HUD へ渡す。空文字なら何も出さない。
func notify_stage_title(title: String) -> void:
	if title.is_empty():
		return
	stage_title_shown.emit(title)


func notify_lock_started(lock_index: int) -> void:
	set_phase(Phase.LOCKED)
	lock_started.emit(lock_index)


func notify_lock_cleared(lock_index: int) -> void:
	if phase == Phase.LOCKED:
		set_phase(Phase.PLAY)
	lock_cleared.emit(lock_index)


func notify_boss_started(boss: Node3D) -> void:
	set_phase(Phase.BOSS)
	boss_started.emit(boss)


func notify_boss_defeated(stage: int) -> void:
	boss_defeated.emit()
	set_phase(Phase.CLEARED)
	stage_cleared.emit(stage)


## 面の開始時に呼ぶ。カードの有無で開始フェーズを決める。
func begin_stage(stage: int, has_card: bool) -> void:
	RunState.set_stage(stage)
	phase = Phase.CARD if has_card else Phase.PLAY
	phase_changed.emit(phase)


func reset() -> void:
	phase = Phase.CARD
	phase_changed.emit(phase)
