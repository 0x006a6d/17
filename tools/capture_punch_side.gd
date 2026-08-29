extends "res://tools/capture_kick_side.gd"

## 現行ベルト方向（攻撃 +X）のパンチ3段を、蹴りQCと同じ横画角・照明で撮る。


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	scenario = "punch_side"
	_build_stage()
	_key = KEY_J
	_press_times = [1.0, 1.35, 1.70]
	_end_time = 3.35
	_pressed = [false, false, false]
	_csv.append("frame,time,state,node,pos,hitbox_monitoring")
