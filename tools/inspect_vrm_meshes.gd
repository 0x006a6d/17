extends SceneTree

## VRM の MeshInstance3D 名・サーフェス数・マテリアル名を列挙する（technical-spec §3.5）。
## nike_skin.gd の hairpin_mesh_names / shirt_material_names を決めるための調査専用。
##   godot --path . --headless -s res://tools/inspect_vrm_meshes.gd


func _walk(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		var count := mesh_instance.mesh.get_surface_count()
		print("MESH %s  surfaces=%d  aabb=%s" % [mesh_instance.name, count, mesh_instance.get_aabb()])
		for i in range(count):
			var mat := mesh_instance.mesh.surface_get_material(i)
			var override := mesh_instance.get_surface_override_material(i)
			var mat_name := mat.resource_name if mat != null else "(null)"
			var override_name := override.resource_name if override != null else "-"
			var shader_name := ""
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
				shader_name = (mat as ShaderMaterial).shader.resource_path.get_file()
			print("   [%d] material=%s  override=%s  class=%s %s" % [i, mat_name, override_name,
				mat.get_class() if mat != null else "", shader_name])
	for c in node.get_children():
		_walk(c)


func _init() -> void:
	var packed: PackedScene = load("res://assets/vrm/nikechan_player.vrm") as PackedScene
	var inst: Node = packed.instantiate()
	_walk(inst)
	inst.free()
	quit(0)
