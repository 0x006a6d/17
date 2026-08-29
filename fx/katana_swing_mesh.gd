extends RefCounted

## 刀身の実軌道と、フィニッシュ用の円弧を動的メッシュへ変換する。


static func make_additive_material(render_priority: int, energy: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled;

uniform float energy = 1.0;

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float feather = smoothstep(0.0, 0.58, across);
	ALBEDO = COLOR.rgb * energy;
	EMISSION = COLOR.rgb * max(energy - 0.45, 0.0);
	ALPHA = COLOR.a * feather;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("energy", energy)
	material.render_priority = render_priority
	return material


static func arc(center: Vector3, right: Vector3, up: Vector3,
		inner_radius: float, outer_radius: float, start_angle: float,
		sweep_angle: float, inner_color: Color, outer_color: Color,
		opacity: float) -> ArrayMesh:
	if absf(sweep_angle) < 0.01 or opacity <= 0.001:
		return null
	var segment_count: int = maxi(2, ceili(absf(sweep_angle) / deg_to_rad(4.0)))
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for index: int in segment_count + 1:
		var ratio: float = float(index) / float(segment_count)
		var angle: float = start_angle + sweep_angle * ratio
		var direction: Vector3 = right * cos(angle) + up * sin(angle)
		var center_radius: float = (inner_radius + outer_radius) * 0.5
		var half_width: float = (outer_radius - inner_radius) * 0.5
		var taper_wave: float = maxf(sin(PI * ratio), 0.0)
		var taper: float = 0.14 + 0.86 * pow(taper_wave, 0.58)
		vertices.append(center + direction * (center_radius - half_width * taper))
		vertices.append(center + direction * (center_radius + half_width * taper))
		uvs.append(Vector2(0.0, ratio))
		uvs.append(Vector2(1.0, ratio))
		var head_fade: float = smoothstep(0.0, 0.08, ratio)
		var tail_fade: float = 1.0 - smoothstep(0.92, 1.0, ratio)
		var edge_fade: float = minf(head_fade, tail_fade)
		colors.append(_with_alpha(inner_color,
			inner_color.a * opacity * edge_fade))
		colors.append(_with_alpha(outer_color,
			outer_color.a * opacity * edge_fade))
		if index == 0:
			continue
		var previous: int = (index - 1) * 2
		var current: int = index * 2
		indices.append_array(PackedInt32Array([
			previous, current, previous + 1,
			previous + 1, current, current + 1,
		]))
	return _mesh(vertices, colors, uvs, indices)


static func spokes(center: Vector3, right: Vector3, up: Vector3,
		angles: Array[float], radius: float, width: float, color: Color,
		opacity: float) -> ArrayMesh:
	if opacity <= 0.001:
		return null
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for angle: float in angles:
		var direction: Vector3 = right * cos(angle) + up * sin(angle)
		var perpendicular: Vector3 = -right * sin(angle) + up * cos(angle)
		var start: Vector3 = center - direction * radius * 0.18
		var end: Vector3 = center + direction * radius
		var first: int = vertices.size()
		vertices.append(start - perpendicular * width)
		vertices.append(start + perpendicular * width)
		vertices.append(end - perpendicular * width * 0.15)
		vertices.append(end + perpendicular * width * 0.15)
		uvs.append_array(PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(1.0, 0.0),
			Vector2(0.0, 1.0), Vector2(1.0, 1.0),
		]))
		var faded_color: Color = _with_alpha(color, color.a * opacity)
		colors.append_array(PackedColorArray([
			faded_color, faded_color, Color(faded_color, 0.0), Color(faded_color, 0.0),
		]))
		indices.append_array(PackedInt32Array([
			first, first + 2, first + 1,
			first + 1, first + 2, first + 3,
		]))
	return _mesh(vertices, colors, uvs, indices)


static func _mesh(vertices: PackedVector3Array, colors: PackedColorArray,
		uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	if vertices.is_empty() or indices.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


static func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
