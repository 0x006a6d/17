extends Area3D
class_name LockPoint

## 画面ロック地点（technical-spec §8.4）。プレイヤーが入ると reached を送り、
## BeltStage から start() されたら waves を順に出す。同時出現は max_alive まで。
## 波の全員が DOWNED（Enemy.defeated）で次の波、最後の波が終われば cleared。
## 敵の実体化（どこに出すか）は面側の spawner に任せ、ここは数と順番だけを持つ。

## 出す波。上から順に消化する。
@export var waves: Array[WaveSpec] = []
## 同時に生きていてよい敵の上限。超える分は空きが出てから出す。
@export var max_alive: int = 4

signal reached(lock_point: LockPoint)
signal cleared(lock_point: LockPoint)

var _triggered: bool = false
var _spawner: Callable = Callable()
var _wave_index: int = -1
## 現在の波で、まだ出していない残り数。
var _pending: int = 0
var _pending_side: int = 0
var _spawn_timer: float = 0.0
var _alive: Array[Node3D] = []
var _spawn_counter: int = 0
var _done: bool = false


func _ready() -> void:
	# プレイヤー本体（layer 2）だけを検出する。
	collision_layer = 0
	collision_mask = 1 << 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	set_physics_process(false)


func _on_body_entered(body: Node3D) -> void:
	if _triggered or not body.is_in_group(&"player"):
		return
	_triggered = true
	reached.emit(self)


## 面側から呼ぶ。spawner は (scene: PackedScene, side: int) -> Node3D を受ける Callable。
func start(spawner: Callable) -> void:
	_spawner = spawner
	_wave_index = -1
	_alive.clear()
	_done = false
	set_physics_process(true)
	_advance_wave()


func is_done() -> bool:
	return _done


func alive_count() -> int:
	return _alive.size()


func _advance_wave() -> void:
	_wave_index += 1
	if _wave_index >= waves.size():
		_finish()
		return
	var wave := waves[_wave_index]
	if wave == null or wave.enemy_scene == null or wave.count <= 0:
		_advance_wave()
		return
	_pending = wave.count
	_pending_side = wave.side
	_spawn_timer = wave.delay


func _physics_process(delta: float) -> void:
	if _done:
		return
	_prune_alive()
	if _pending > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and _alive.size() < max_alive:
			_spawn_one()
			_spawn_timer = waves[_wave_index].spacing
		return
	if _alive.is_empty():
		_advance_wave()


func _spawn_one() -> void:
	var wave := waves[_wave_index]
	var side := _pending_side
	if side == 0:
		side = 1 if (_spawn_counter % 2 == 0) else -1
	_spawn_counter += 1
	_pending -= 1
	if not _spawner.is_valid():
		return
	var enemy := _spawner.call(wave.enemy_scene, side) as Node3D
	if enemy == null:
		return
	_alive.append(enemy)
	if enemy.has_signal("defeated"):
		enemy.connect("defeated", _on_enemy_defeated)
	enemy.tree_exited.connect(_on_enemy_gone.bind(enemy))


func _on_enemy_defeated(enemy: Node3D) -> void:
	_alive.erase(enemy)


func _on_enemy_gone(enemy: Node3D) -> void:
	_alive.erase(enemy)


func _prune_alive() -> void:
	for i in range(_alive.size() - 1, -1, -1):
		var e := _alive[i]
		if e == null or not is_instance_valid(e) or not e.is_inside_tree():
			_alive.remove_at(i)


func _finish() -> void:
	if _done:
		return
	_done = true
	set_physics_process(false)
	cleared.emit(self)
