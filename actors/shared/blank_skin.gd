extends Node
class_name BlankSkin

## モデルの全サーフェスを無地の白へ塗り替える（5面のニケ素体）。
## NikeSkin がシャツ1枚を差し替えるのと同じ方式を全サーフェスへ広げたもので、
## 元のマテリアルは触らず `set_surface_override_material()` に複製を置く。
## MToon はテクスチャを白にして `_Color` / `_ShadeColor` で色を出す。輪郭線
## （next_pass のアウトライン）は複製に付いたまま残るので、トゥーンの線は消えない。

## 塗り替える対象の Model（VRM のインスタンスを含むノード）。
@export var model_path: NodePath = ^"../Model"
## 明部・陰部の色。素体なので彩度は載せない。
@export var base_color: Color = Color(1.0, 1.0, 1.0)
@export var shade_color: Color = Color(0.78, 0.78, 0.80)
## 起動時に自動で適用する。Model の生成を待つため 1 フレーム遅らせる。
@export var apply_on_ready: bool = true

var _painted_count: int = 0
var _white: Texture2D = null


func _ready() -> void:
	if apply_on_ready:
		apply.call_deferred()


## 塗り替えを適用する。何度呼んでも結果は同じ。
func apply() -> void:
	var model := get_node_or_null(model_path)
	if model == null:
		push_warning("blank_skin: Model が無い")
		return
	_painted_count = 0
	_walk(model)


## 塗り替えたサーフェス数。0 ならメッシュが見つかっていない。
func painted_surface_count() -> int:
	return _painted_count


func _walk(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		for i in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(i)
			if material == null:
				continue
			mesh_instance.set_surface_override_material(i, _whitened(material))
			_painted_count += 1
	for child in node.get_children():
		_walk(child)


func _whitened(source: Material) -> Material:
	var shader_material := source as ShaderMaterial
	if shader_material == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = base_color
		return fallback
	var copy := shader_material.duplicate() as ShaderMaterial
	copy.set_shader_parameter(&"_MainTex", _white_texture())
	copy.set_shader_parameter(&"_ShadeTexture", _white_texture())
	copy.set_shader_parameter(&"_Color", base_color)
	copy.set_shader_parameter(&"_ShadeColor", shade_color)
	# MToon の加算・リムはテクスチャが残ると模様が透けるので、白と黒で潰す。
	copy.set_shader_parameter(&"_EmissionMap", _white_texture())
	copy.set_shader_parameter(&"_EmissionColor", Color(0.0, 0.0, 0.0))
	return copy


func _white_texture() -> Texture2D:
	if _white == null:
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(image)
	return _white
