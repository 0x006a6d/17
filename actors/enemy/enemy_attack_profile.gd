class_name EnemyAttackProfile
extends Resource

## 敵の攻撃1種に必要なアニメーション・判定時間・威力・移動量をまとめた設定。

@export_enum("Cross Punch", "Left Jab", "Hook") var animation_variant: int = 0
@export var clip: PackedScene
## NPCモデル上で実測した、元クリップの打撃ピークと全長（秒）。
@export var measured_peak_time: float = 0.0
@export var source_clip_length: float = 0.0
@export var min_distance: float = 0.0
@export var max_distance: float = 1.35
@export var telegraph: float = 0.45
@export var active: float = 0.18
@export var recovery: float = 0.35
@export var damage: float = 1200.0
@export var knockback: float = 3.0
@export var lunge_speed: float = 1.2


func scaled_peak_time() -> float:
	if source_clip_length <= 0.0:
		return 0.0
	return measured_peak_time / source_clip_length * (telegraph + active + recovery)
