extends Node
class_name PaletteSwap

## 色違いの雑魚。`ToonSkin` が張った MToon の上書きマテリアルを複製し、指定した服の色
## だけを差し替える。元のマテリアルと元のメッシュ資源は触らない（複製にだけ書く）。
##
## キャラによって服の入り方が違うので、指定の仕方を2つ持つ。
##   - メッシュ単位（Ch01 / Ch28 / Ch08）: 服が `Ch01_Shirt` のような MeshInstance3D
##     で分かれているので、`target_mesh_names` に名前を並べる
##   - 上半身の暗い部分だけ（Ch06）: 体も服も1メッシュにまとまっているので、三角形の
##     重心 Y と、その UV のテクセルの明るさで服だけを切り出して専用サーフェスへ分ける
##
## 塗り方は2つ。元が明るい服を暗くするなら `tint`（テクスチャを残して掛ける。皺が残る）、
## 元が暗い服を明るくするなら `flat`（テクスチャを白にして単色。掛け算では明るくできない）。
##
## `ToonSkin.apply()` は親（Enemy）の `_ready()` で走るため、ここは 1 フレーム遅らせる。

enum Mode { TINT, FLAT }

## 切り出したメッシュの共有キャッシュ。同じキャラを何体出しても 1 回で済ませる。
static var _split_cache: Dictionary = {}

## 塗り替える MeshInstance3D の名前。
@export var target_mesh_names: Array[StringName] = []
## 明部・陰部の色。陰部が黒（既定）なら明部から自動で作る。
@export var color: Color = Color(1.0, 1.0, 1.0)
@export var shade_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export_enum("Tint", "Flat") var mode: int = Mode.TINT

@export_group("Upper Dark Split")
## 体と服が1メッシュのキャラで、上半身の暗い部分だけを切り出す。
@export var split_mesh_name: StringName = &""
## 切り出す対象のサーフェス番号。
@export var split_surface: int = 0
## 三角形の重心 Y の範囲（メッシュのローカル座標、バインドポーズ）。
@export var split_y_min: float = 0.95
@export var split_y_max: float = 1.62
## この明るさ未満のテクセルを「服」とみなす。
@export_range(0.0, 1.0) var split_darkness: float = 0.22
## 切り出し後に ToonSkin を張り直す。`Enemy.toon_skin` を切っている個体では false。
@export var reapply_toon_skin: bool = true

@export_group("Nodes")
@export var model_path: NodePath = ^"../Model"
## 起動時に自動で適用する。
@export var apply_on_ready: bool = true
@export_group("")

var _painted_count: int = 0
var _split_triangles: int = 0
var _white: Texture2D = null


func _ready() -> void:
	if apply_on_ready:
		apply.call_deferred()


func apply() -> void:
	var model := get_node_or_null(model_path) as Node3D
	if model == null:
		push_warning("palette_swap: Model が無い")
		return
	_painted_count = 0
	_split_triangles = 0
	if not split_mesh_name.is_empty():
		_apply_upper_dark_split(model)
	if not target_mesh_names.is_empty():
		_walk(model)


## 塗り替えたサーフェス数（検証用）。0 なら名前が合っていない。
func painted_surface_count() -> int:
	return _painted_count


## 切り出した三角形の数（検証用）。
func split_triangle_count() -> int:
	return _split_triangles


func _walk(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null \
			and target_mesh_names.has(StringName(mesh_instance.name)):
		for i in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(i)
			if material == null:
				continue
			mesh_instance.set_surface_override_material(i, _recolored(material))
			_painted_count += 1
	for child in node.get_children():
		_walk(child)


## MToon の色を差し替える。tint は元テクスチャを残して掛け、flat は白へ置いて単色にする。
func _recolored(source: Material) -> Material:
	var shader_material := source as ShaderMaterial
	if shader_material == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = color
		return fallback
	var copy := shader_material.duplicate() as ShaderMaterial
	if mode == Mode.FLAT:
		copy.set_shader_parameter(&"_MainTex", _white_texture())
		copy.set_shader_parameter(&"_ShadeTexture", _white_texture())
	copy.set_shader_parameter(&"_Color", color)
	copy.set_shader_parameter(&"_ShadeColor", _shade())
	return copy


func _shade() -> Color:
	if shade_color.a > 0.0:
		return shade_color
	# ToonSkin と同じ作り方（アルベドを暗くしたものを陰色にする）。
	return Color(color.r * 0.62, color.g * 0.62, color.b * 0.62, 1.0)


func _white_texture() -> Texture2D:
	if _white == null:
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(image)
	return _white


# --- 上半身の暗い部分の切り出し --------------------------------------------

## 対象メッシュを、切り出し済みのメッシュへ差し替えて、増えたサーフェスだけを塗る。
func _apply_upper_dark_split(model: Node3D) -> void:
	var mesh_instance := _find_mesh(model, split_mesh_name)
	if mesh_instance == null or mesh_instance.mesh == null:
		push_warning("palette_swap: %s が無い" % split_mesh_name)
		return
	var built: Dictionary = _build_split(mesh_instance.mesh as ArrayMesh)
	if built.is_empty():
		return
	mesh_instance.mesh = built["mesh"] as ArrayMesh
	_split_triangles = int(built["triangles"])
	# サーフェスが増えるので、上書きマテリアルを ToonSkin にもう一度作らせてから塗る。
	# 先に外さないと、古い上書き（MToon）を素材と誤読して真っ白なマテリアルになる。
	if reapply_toon_skin:
		ToonSkin.clear(model)
		ToonSkin.apply(model)
	var index: int = int(built["surface"])
	var material := mesh_instance.get_active_material(index)
	if material != null:
		mesh_instance.set_surface_override_material(index, _recolored(material))
		_painted_count += 1


func _find_mesh(node: Node, mesh_name: StringName) -> MeshInstance3D:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and StringName(mesh_instance.name) == mesh_name:
		return mesh_instance
	for child in node.get_children():
		var found := _find_mesh(child, mesh_name)
		if found != null:
			return found
	return null


## 指定サーフェスを「上半身の暗い三角形」と「それ以外」の2枚へ分けたメッシュを作る。
## 同じ元メッシュ・同じ条件なら 1 度だけ作って共有する（形は個体によらない）。
func _build_split(source: ArrayMesh) -> Dictionary:
	if source == null or split_surface >= source.get_surface_count():
		return {}
	var arrays: Array = source.surface_get_arrays(split_surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# インポート済みメッシュの resource_path が空でも衝突しないよう、頂点数も鍵に混ぜる。
	var key: String = "%s|%s|%d|%d|%.3f|%.3f|%.3f" % [source.resource_path,
		source.surface_get_name(split_surface), split_surface, vertices.size(),
		split_y_min, split_y_max, split_darkness]
	if _split_cache.has(key):
		return _split_cache[key] as Dictionary
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var image: Image = _albedo_image(source.surface_get_material(split_surface))
	if indices.is_empty() or uvs.is_empty() or image == null:
		return {}
	var picked := PackedInt32Array()
	var rest := PackedInt32Array()
	var width: int = image.get_width()
	var height: int = image.get_height()
	for t in range(0, indices.size() - 2, 3):
		var a: int = indices[t]
		var b: int = indices[t + 1]
		var c: int = indices[t + 2]
		var center_y: float = (vertices[a].y + vertices[b].y + vertices[c].y) / 3.0
		var is_upper: bool = center_y >= split_y_min and center_y <= split_y_max
		var dark: bool = false
		if is_upper:
			var uv: Vector2 = (uvs[a] + uvs[b] + uvs[c]) / 3.0
			var x: int = clampi(int(fposmod(uv.x, 1.0) * float(width)), 0, width - 1)
			# Godot の UV は上が 0。画像も同じ向きなのでそのまま使う。
			var y: int = clampi(int(fposmod(uv.y, 1.0) * float(height)), 0, height - 1)
			var texel: Color = image.get_pixel(x, y)
			dark = maxf(maxf(texel.r, texel.g), texel.b) < split_darkness
		var target := picked if (is_upper and dark) else rest
		target.append(a)
		target.append(b)
		target.append(c)
	if picked.is_empty():
		push_warning("palette_swap: %s の上半身の暗い部分が見つからない" % split_mesh_name)
		return {}

	var copy := ArrayMesh.new()
	copy.resource_name = source.resource_name
	for surface in range(source.get_surface_count()):
		if surface == split_surface:
			continue
		var other: Array = source.surface_get_arrays(surface)
		copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, other, [], {},
			source.surface_get_format(surface) & _SURFACE_FLAGS)
		var last: int = copy.get_surface_count() - 1
		copy.surface_set_material(last, source.surface_get_material(surface))
		copy.surface_set_name(last, source.surface_get_name(surface))
	var format: int = source.surface_get_format(split_surface) & _SURFACE_FLAGS
	var material: Material = source.surface_get_material(split_surface)
	var surface_name: String = source.surface_get_name(split_surface)
	for part: PackedInt32Array in [rest, picked]:
		if part.is_empty():
			continue
		var part_arrays: Array = arrays.duplicate()
		part_arrays[Mesh.ARRAY_INDEX] = part
		copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part_arrays, [], {}, format)
		var last: int = copy.get_surface_count() - 1
		copy.surface_set_material(last, material)
		copy.surface_set_name(last, surface_name)
	var built := {
		"mesh": copy,
		"surface": copy.get_surface_count() - 1,
		"triangles": picked.size() / 3,
	}
	_split_cache[key] = built
	return built


const _SURFACE_FLAGS: int = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS \
	| Mesh.ARRAY_FLAG_USE_2D_VERTICES | Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE \
	| Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES


## マテリアルのアルベド画像。切り出しの明るさ判定に使う。
func _albedo_image(material: Material) -> Image:
	var standard := material as StandardMaterial3D
	if standard == null or standard.albedo_texture == null:
		return null
	var image: Image = standard.albedo_texture.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image = image.duplicate() as Image
		if image.decompress() != OK:
			return null
	return image
