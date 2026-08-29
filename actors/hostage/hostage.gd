extends CharacterBody3D
class_name Hostage

## 4面の人質（ニケ）。technical-spec §9。
## ステートは SEATED（拘束されて床に座らされている）と SHIELDED（4面ボスが正面に保持）の2つ。
## Hurtbox も Health も持たない（誰の攻撃も当たらない）。位置と向きは保持者（Shielder）が
## 毎物理フレーム更新する。開示（4面ボス撃破後）では stand_up() で立ち姿へ移る。

enum HostageState { SEATED, SHIELDED, STANDING }

signal state_changed(state: int)

@export_group("Nodes")
@export var model_path: NodePath = ^"Model"
@export var animator_path: NodePath = ^"Animator"
@export_group("")

var _animator: NpcAnimator = null
var _state: int = HostageState.SEATED


func _ready() -> void:
	add_to_group(&"hostage")
	_animator = get_node_or_null(animator_path) as NpcAnimator
	if _animator != null:
		_animator.setup()
	_apply_state(HostageState.SEATED)


func _physics_process(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func current_state() -> int:
	return _state


func is_shielded() -> bool:
	return _state == HostageState.SHIELDED


## 保持者から呼ぶ。holder は明示のため受け取るが、依存を作らないよう保存しない。
func enter_shielded(_holder: Node3D) -> void:
	if _state == HostageState.STANDING:
		return
	_apply_state(HostageState.SHIELDED)


## 保持者から呼ぶ。その場に座り込む。
func exit_shielded() -> void:
	if _state != HostageState.SHIELDED:
		return
	_apply_state(HostageState.SEATED)


## 開示で立ち上がる。以後は保持されない。
func stand_up() -> void:
	_apply_state(HostageState.STANDING)


func _apply_state(next: int) -> void:
	_state = next
	if _animator != null and _animator.is_active():
		match next:
			HostageState.SEATED:
				# 座り・跪きのクリップは未取得のため、伏せ（PRONE）の静止ポーズで代用する。
				_animator.play(NpcAnimator.Clip.PRONE, 0.15, 1.0, true)
			HostageState.SHIELDED, HostageState.STANDING:
				_animator.play(NpcAnimator.Clip.STAND, 0.15, 1.0, true)
	state_changed.emit(_state)
