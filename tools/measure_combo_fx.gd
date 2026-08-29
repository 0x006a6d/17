extends SceneTree

## QC helper: reports warm/white/orange effect pixels and the warm bounding box.
## Usage: godot --headless --path . --script res://tools/measure_combo_fx.gd -- <frame-dir> <frame...>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		quit(2)
		return
	var directory := args[0]
	for index in range(1, args.size()):
		var frame := int(args[index])
		var current := Image.load_from_file("%s/frame%08d.png" % [directory, frame])
		var previous := Image.load_from_file("%s/frame%08d.png" % [directory, frame - 1])
		var warm := 0
		var white := 0
		var orange := 0
		var delta_warm := 0
		var min_x := current.get_width()
		var min_y := current.get_height()
		var max_x := -1
		var max_y := -1
		var band_min_x := current.get_width()
		var band_min_y := current.get_height()
		var band_max_x := -1
		var band_max_y := -1
		var contact_warm := 0
		var contact_radius := 200.0
		var contact_center := Vector2(475.0, 350.0)
		for y in current.get_height():
			for x in current.get_width():
				var c := current.get_pixel(x, y)
				var p := previous.get_pixel(x, y)
				var is_white := c.r > 0.90 and c.g > 0.90 and c.b > 0.90
				var is_orange := c.r > 0.78 and c.g > 0.40 and c.g < 0.90 and c.b < 0.55
				var is_warm := is_white or (c.r > 0.78 and c.g > 0.55 and c.b < 0.55)
				if is_white: white += 1
				if is_orange: orange += 1
				if is_warm:
					warm += 1
					if Vector2(x, y).distance_squared_to(contact_center) <= contact_radius * contact_radius:
						contact_warm += 1
					min_x = mini(min_x, x); max_x = maxi(max_x, x)
					min_y = mini(min_y, y); max_y = maxi(max_y, y)
					if y >= 315 and y <= 390:
						band_min_x = mini(band_min_x, x); band_max_x = maxi(band_max_x, x)
						band_min_y = mini(band_min_y, y); band_max_y = maxi(band_max_y, y)
					if absf(c.r-p.r) > 24.0/255.0 or absf(c.g-p.g) > 24.0/255.0 or absf(c.b-p.b) > 24.0/255.0:
						delta_warm += 1
		var width := max_x - min_x + 1 if max_x >= 0 else 0
		var height := max_y - min_y + 1 if max_y >= 0 else 0
		var band_width := band_max_x - band_min_x + 1 if band_max_x >= 0 else 0
		var band_height := band_max_y - band_min_y + 1 if band_max_y >= 0 else 0
		var contact_fill := 100.0 * float(contact_warm) / (PI * contact_radius * contact_radius)
		print("frame=%d warm=%d white=%d orange=%d delta_warm=%d bbox=%dx%d ratio=%.2f band_bbox=%dx%d band_ratio=%.2f contact_warm=%d fill=%.2f%%" % [frame, warm, white, orange, delta_warm, width, height, float(width) / maxf(height, 1.0), band_width, band_height, float(band_width) / maxf(band_height, 1.0), contact_warm, contact_fill])
	quit()
