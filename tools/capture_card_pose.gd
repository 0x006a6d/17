extends Node3D

## 冒頭カード表示中（ツリー停止中）のプレイヤーの姿勢を、開始直後から連続で撮る検証用。
##   godot --path . --resolution 1280x720 res://tools/capture_card_pose.tscn -- --stage 1 --tag before

const OUT_DIR := "res://docs/img"
const SHOT_FRAMES: Array[int] = [1, 2, 3, 4, 6, 10, 20, 60, 120]

var _stage_index: int = 1
var _tag: String = "before"
var _stage: BeltStage = null
var _frames: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--stage":
			_stage_index = int(args[i + 1])
		elif args[i] == "--tag":
			_tag = args[i + 1]
	RunState.reset()
	_stage = (load("res://levels/stage_%d.tscn" % _stage_index) as PackedScene).instantiate() as BeltStage
	# この検証ノードは ALWAYS なので、そのまま子にすると面全体がポーズを無視する。
	# 実機と同じ扱いにするため、面には PAUSABLE を明示する。
	_stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_stage)
	_run()


func _run() -> void:
	while _frames <= SHOT_FRAMES[SHOT_FRAMES.size() - 1]:
		await RenderingServer.frame_post_draw
		_frames += 1
		if SHOT_FRAMES.has(_frames):
			var path := "%s/qc_cardpose_%s_%03d.png" % [OUT_DIR, _tag, _frames]
			var img := get_viewport().get_texture().get_image()
			var player := _stage.get_node_or_null(^"Player")
			var melee := _stage.get_node_or_null(^"Player/PlayerMelee")
			var state: String = ""
			if melee != null:
				var sm = melee.get("_state_machine")
				if sm != null:
					state = str(sm.get_current_node())
			print("[card_pose] %s (%s) paused=%s state=%s pos=%s" % [path,
				error_string(img.save_png(path)), str(get_tree().paused), state,
				str(player.global_position) if player != null else "?"])
	get_tree().quit()
