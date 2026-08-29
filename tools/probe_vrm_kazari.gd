extends SceneTree

## NikeChanKazari（髪飾り）サーフェスの頂点分布を調べる（NikeSkin のヘアピン切り出し範囲の決定用）。
##   godot --path . --headless -s res://tools/probe_vrm_kazari.gd
## 三角形ごとの重心を、前後（z の符号）と左右（x の符号）で分けて AABB と個数を出す。


func _walk(node: Node) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		for i in range(mi.mesh.get_surface_count()):
			var mat := mi.mesh.surface_get_material(i)
			if mat == null or mat.resource_name != "NikeChanKazari":
				continue
			var arrays := mi.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			print("MESH %s surface %d verts=%d tris=%d blend_shapes=%d" % [mi.name, i, verts.size(), idx.size() / 3, mi.mesh.get_blend_shape_count()])
			var buckets := {}
			for t in range(0, idx.size(), 3):
				var c := (verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0
				var key := "%s%s" % ["front" if c.z >= 0.0 else "back", "R(x<0)" if c.x < 0.0 else "L(x>=0)"]
				if not buckets.has(key):
					buckets[key] = {"n": 0, "min": c, "max": c}
				var b: Dictionary = buckets[key]
				b["n"] += 1
				b["min"] = Vector3(minf(b["min"].x, c.x), minf(b["min"].y, c.y), minf(b["min"].z, c.z))
				b["max"] = Vector3(maxf(b["max"].x, c.x), maxf(b["max"].y, c.y), maxf(b["max"].z, c.z))
			for key in buckets:
				var b: Dictionary = buckets[key]
				print("   %-14s tris=%4d  min=%s  max=%s" % [key, b["n"], b["min"], b["max"]])
			# y で細かく分ける（前面のみ）
			var hist := {}
			for t in range(0, idx.size(), 3):
				var c := (verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0
				var k := "z%+.2f y%.2f x%+.2f" % [snappedf(c.z, 0.05), snappedf(c.y, 0.05), snappedf(c.x, 0.05)]
				hist[k] = hist.get(k, 0) + 1
			var keys := hist.keys()
			keys.sort()
			for k in keys:
				print("      %s : %d" % [k, hist[k]])
	for c in node.get_children():
		_walk(c)


func _init() -> void:
	var inst: Node = (load("res://assets/vrm/nikechan_player.vrm") as PackedScene).instantiate()
	_walk(inst)
	inst.free()
	quit(0)
