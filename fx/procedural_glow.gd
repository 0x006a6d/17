class_name ProceduralGlow
extends RefCounted

## 外部画像を使わず、加算発光エフェクト用のソフトマスクを生成する。


static func make_radial_texture(texture_size: int, edge_power: float) -> ImageTexture:
	var size: int = maxi(texture_size, 8)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in size:
		for x: int in size:
			var uv := Vector2(float(x), float(y)) / float(size - 1)
			var distance: float = (uv - Vector2(0.5, 0.5)).length() * 2.0
			var alpha: float = pow(clampf(1.0 - distance, 0.0, 1.0), edge_power)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


static func make_streak_texture(texture_length: int, texture_width: int,
		edge_power: float) -> ImageTexture:
	var width: int = maxi(texture_length, 8)
	var height: int = maxi(texture_width, 4)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		for x: int in width:
			var along: float = float(x) / float(width - 1)
			var across: float = absf(float(y) / float(height - 1) * 2.0 - 1.0)
			var tip_fade: float = sin(PI * along)
			var alpha: float = pow(clampf(1.0 - across, 0.0, 1.0), edge_power)
			alpha *= pow(maxf(tip_fade, 0.0), 0.55)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


static func make_material(texture: Texture2D, color: Color,
		emission_energy: float, billboard: bool = true) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.albedo_texture = texture
	material.albedo_color = color
	material.emission_enabled = true
	material.emission_texture = texture
	material.emission = Color(color.r * emission_energy, color.g * emission_energy,
		color.b * emission_energy, color.a)
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return material


static func make_quad(texture: Texture2D, size: Vector2, color: Color,
		emission_energy: float, billboard: bool = true) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = make_material(texture, color, emission_energy, billboard)
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	return mesh
