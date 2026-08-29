extends Node

## 結果画面の見た目を撮る（ウィンドウありで実行）。
##   godot --path . --resolution 1280x720 res://tools/capture_result_panel.tscn

const OUT_PATH: String = "res://docs/img/qc_result_panel.png"


func _ready() -> void:
	var panel := (load("res://ui/result_panel.tscn") as PackedScene).instantiate() as ResultPanel
	add_child(panel)
	panel.show_result(4820, true)
	for _i in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	print("[result] %s (%s)" % [OUT_PATH, error_string(image.save_png(OUT_PATH))])
	get_tree().paused = false
	get_tree().quit()
