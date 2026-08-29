extends SceneTree

const NAMES: Array[String] = ["melee_1", "melee_2", "melee_3",
	"kick_1", "kick_2", "kick_3"]


func _init() -> void:
	for n: String in NAMES:
		var anim := load("res://actors/player/anim/%s.res" % n) as Animation
		if anim == null:
			print("[MISS] ", n)
			continue
		var enable_t := -1.0
		var disable_t := -1.0
		for t: int in anim.get_track_count():
			if anim.track_get_type(t) != Animation.TYPE_METHOD:
				continue
			for k: int in anim.track_get_key_count(t):
				var key: Dictionary = anim.track_get_key_value(t, k)
				var time := anim.track_get_key_time(t, k)
				if String(key.get("method", "")) == "_enable_hitbox":
					enable_t = time
				elif String(key.get("method", "")) == "_disable_hitbox":
					disable_t = time
		print("%-8s len=%.3f  enable=%.3f (%.1f%%)  disable=%.3f (%.1f%%)  window=%.3f"
			% [n, anim.length, enable_t, enable_t / anim.length * 100.0,
			disable_t, disable_t / anim.length * 100.0, disable_t - enable_t])
	quit()
