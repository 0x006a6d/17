extends Node
class_name NikeSkin

## ニケ（4面の人質・5面のボス）の外見を、公式 VRM を改変せずランタイムに上書きする
## （technical-spec §3.5）。Model 以下の MeshInstance3D を走査し、
##   - hidden_material_names に当たるサーフェスを不可視にする（ヘアピン＝髪飾り）
##   - shirt_material_names に当たるサーフェスのマテリアルを複製して色を差し替える
## マテリアル名は tools/inspect_vrm_meshes.gd の出力から決める（直書きしない）。
## 元のマテリアルリソースは触らない（複製に対してだけパラメータを書く）。

## 上書き対象の Model（VRM のインスタンスを含むノード）。
@export var model_path: NodePath = ^"../Model"
## 不可視にするサーフェスのマテリアル名（サーフェス単位で消したいものがあれば）。
## 髪飾りのマテリアル NikeChanKazari はヘアピン・シュシュ・イヤリングを兼ねるため、ここでは
## 使わず、ヘアピンだけを下の AABB で三角形単位に切り出す。
@export var hidden_material_names: Array[StringName] = []
@export_group("Hairpin Cut")
## ヘアピンを含むメッシュ名・マテリアル名（tools/probe_vrm_kazari.gd の出力から）。
@export var hairpin_mesh_name: StringName = &"NikeFace"
@export var hairpin_material_name: StringName = &"NikeChanKazari"
## ヘアピンの三角形（重心）が入る範囲（メッシュのローカル座標、バインドポーズ）。
## 同じサーフェスのイヤリング（y≈1.39、z<0）と重ならないように取る。
@export var hairpin_aabb_min: Vector3 = Vector3(0.03, 1.395, 0.0)
@export var hairpin_aabb_max: Vector3 = Vector3(0.12, 1.55, 0.12)
@export_group("")
## 色を差し替えるサーフェスのマテリアル名。
@export var shirt_material_names: Array[StringName] = [&"NikeChanTshirt"]
## シャツを差し替えるか。4面の人質は false（ヘアピン非表示のみ）、5面のボスは true。
@export var recolor_shirt: bool = true
## シャツの色（明部・陰部）。
@export var shirt_color: Color = Color(0.80, 0.10, 0.12)
@export var shirt_shade_color: Color = Color(0.45, 0.05, 0.07)
## 起動時に自動で適用する。Model の生成を待つため 1 フレーム遅らせる。
@export var apply_on_ready: bool = true

var _hidden_count: int = 0
var _recolored_count: int = 0
var _cut_triangles: int = 0
var _white: Texture2D = null


func _ready() -> void:
	if apply_on_ready:
		apply.call_deferred()


## 上書きを適用する。何度呼んでも結果は同じ（複製済みの上書きはそのまま）。
func apply() -> void:
	var model := get_node_or_null(model_path)
	if model == null:
		push_warning("nike_skin: Model が無い")
		return
	_hidden_count = 0
	_recolored_count = 0
	_cut_triangles = 0
	_walk(model)


func hidden_surface_count() -> int:
	return _hidden_count


func recolored_surface_count() -> int:
	return _recolored_count


## ヘアピンとして切り出した三角形の数。0 なら範囲か名前が合っていない。
func cut_triangle_count() -> int:
	return _cut_triangles


func _walk(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		if StringName(mesh_instance.name) == hairpin_mesh_name:
			_cut_hairpin(mesh_instance)
		for i in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(i)
			if material == null:
				continue
			var material_name := StringName(material.resource_name)
			if hidden_material_names.has(material_name):
				mesh_instance.set_surface_override_material(i, _invisible_material())
				_hidden_count += 1
			elif recolor_shirt and shirt_material_names.has(material_name):
				mesh_instance.set_surface_override_material(i, _recolored(material))
				_recolored_count += 1
	for child in node.get_children():
		_walk(child)


## 完全透明で深度も書かないマテリアル。サーフェス単位で「消す」ために使う。
func _invisible_material() -> Material:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## MToon のシャツを無地の単色に差し替える。テクスチャを白にし、_Color / _ShadeColor で色を出す。
func _recolored(source: Material) -> Material:
	var shader_material := source as ShaderMaterial
	if shader_material == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = shirt_color
		return fallback
	var copy := shader_material.duplicate() as ShaderMaterial
	copy.set_shader_parameter(&"_MainTex", _white_texture())
	copy.set_shader_parameter(&"_ShadeTexture", _white_texture())
	copy.set_shader_parameter(&"_Color", shirt_color)
	copy.set_shader_parameter(&"_ShadeColor", shirt_shade_color)
	return copy


func _white_texture() -> Texture2D:
	if _white == null:
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(image)
	return _white


## ヘアピンの三角形だけをサーフェスから除く。メッシュは共有資源なので複製してから触る。
## 頂点配列とブレンドシェイプはそのまま、インデックスだけを間引く。
func _cut_hairpin(mesh_instance: MeshInstance3D) -> void:
	var source := mesh_instance.mesh as ArrayMesh
	if source == null:
		return
	var target := -1
	for i in range(source.get_surface_count()):
		var material := source.surface_get_material(i)
		if material != null and StringName(material.resource_name) == hairpin_material_name:
			target = i
			break
	if target < 0:
		return
	var arrays := source.surface_get_arrays(target)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		return
	var aabb := AABB(hairpin_aabb_min, hairpin_aabb_max - hairpin_aabb_min)
	var kept := PackedInt32Array()
	var removed := 0
	for t in range(0, indices.size() - 2, 3):
		var a := vertices[indices[t]]
		var b := vertices[indices[t + 1]]
		var c := vertices[indices[t + 2]]
		if aabb.has_point((a + b + c) / 3.0):
			removed += 1
			continue
		kept.append(indices[t])
		kept.append(indices[t + 1])
		kept.append(indices[t + 2])
	if removed == 0:
		return
	var copy := source.duplicate() as ArrayMesh
	var material := copy.surface_get_material(target)
	var surface_name := copy.surface_get_name(target)
	var blend_shapes := copy.surface_get_blend_shape_arrays(target)
	var format := copy.surface_get_format(target)
	var flags := format & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS | Mesh.ARRAY_FLAG_USE_2D_VERTICES \
		| Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	arrays[Mesh.ARRAY_INDEX] = kept
	copy.surface_remove(target)
	copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blend_shapes, {}, flags)
	var new_index := copy.get_surface_count() - 1
	copy.surface_set_material(new_index, material)
	copy.surface_set_name(new_index, surface_name)
	# サーフェス順が変わるので、同じ順でサーフェス上書きマテリアルを持ち直す。
	var overrides: Array[Material] = []
	for i in range(source.get_surface_count()):
		overrides.append(mesh_instance.get_surface_override_material(i))
	mesh_instance.mesh = copy
	var k := 0
	for i in range(source.get_surface_count()):
		if i == target:
			continue
		mesh_instance.set_surface_override_material(k, overrides[i])
		k += 1
	mesh_instance.set_surface_override_material(new_index, overrides[target])
	_cut_triangles += removed
