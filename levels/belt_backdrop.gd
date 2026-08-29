extends Node3D
class_name BeltBackdrop

## ベルトスクロールの背景（technical-spec §7）。奥に横長の絵を層で立て、カメラの X 追従に
## 対して各層を異なる割合でずらしてパララックスを出す。Codex が描いた背景画像を差し込む枠。
##
## 各層は「横方向にタイル（繰り返し）できる1枚絵」を貼った板。板は毎フレーム、その層の奥行きで
## カメラ視界が横に覆う幅へ合わせて広げ、カメラの真正面に置く。UV を camera_x * parallax /
## tile_width_m だけ横へ流すことで、テクスチャが視差でスクロールする。parallax=0 で完全固定、
## 1 に近いほど手前の動き。texture_path の PNG が無い層は表示しない（絵が来るまで暗い背景のまま）。
##
## 各 layers 要素は Dictionary: {texture_path, y_center, height_m, z_depth, parallax, tile_width_m, modulate}。

@export var layers: Array[Dictionary] = []
## カメラ。空ならグループ belt_camera から探す。
@export var camera_path: NodePath
## 覆う幅に掛ける安全率（端が切れないよう少し広めに作る）。
@export var width_safety: float = 1.15

var _camera: Node3D = null
var _quads: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []
var _configs: Array[Dictionary] = []


func _ready() -> void:
	# カードでツリーが止まっている間も背景を正しく表示するため、常時更新にする。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_camera()
	_build_layers()


func _resolve_camera() -> void:
	if not camera_path.is_empty():
		_camera = get_node_or_null(camera_path) as Node3D
	if _camera == null:
		_camera = get_tree().get_first_node_in_group(&"belt_camera") as Node3D


func _build_layers() -> void:
	for data: Dictionary in layers:
		var texture := data.get("texture", null) as Texture2D
		if texture == null:
			var path := String(data.get("texture_path", ""))
			if not path.is_empty() and ResourceLoader.exists(path):
				texture = load(path) as Texture2D
		if texture == null:
			continue
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.texture_repeat = true
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		material.albedo_color = data.get("modulate", Color.WHITE)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var quad := MeshInstance3D.new()
		quad.mesh = QuadMesh.new()
		quad.material_override = material
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		quad.position = Vector3(0.0, 0.0, float(data.get("z_depth", -6.0)))
		add_child(quad)
		_quads.append(quad)
		_materials.append(material)
		_configs.append({
			"z_depth": float(data.get("z_depth", -6.0)),
			"y_center": float(data.get("y_center", 4.0)),
			"height_m": float(data.get("height_m", 12.0)),
			"parallax": float(data.get("parallax", 0.3)),
			"tile_width_m": float(data.get("tile_width_m", 24.0)),
		})
	# 初回のサイズ・位置合わせ（カメラ確定後の次フレームでも _process が上書きする）。
	_update()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	if _quads.is_empty():
		return
	# カメラは group 登録のタイミングで _ready 時に取れないことがある。取れるまで毎フレーム試す。
	if _camera == null or not is_instance_valid(_camera):
		_resolve_camera()
		if _camera == null:
			return
	var camera_x := _camera.global_position.x
	var cam_z := _camera.global_position.z
	var fov_deg := 50.0
	if _camera is Camera3D:
		fov_deg = (_camera as Camera3D).fov
	var half_fov := deg_to_rad(fov_deg) * 0.5
	var aspect := 16.0 / 9.0
	var viewport := get_viewport()
	if viewport != null:
		var size := viewport.get_visible_rect().size
		if size.y > 0.0:
			aspect = size.x / size.y
	for i in range(_quads.size()):
		var cfg: Dictionary = _configs[i]
		var z_depth: float = cfg["z_depth"]
		var tile_width: float = float(cfg["tile_width_m"])
		# その奥行きの距離で視界が横に覆う幅へ板を広げる（縦位置・高さは指定値のまま）。
		var distance := absf(cam_z - z_depth)
		var width := distance * tan(half_fov) * aspect * 2.0 * width_safety
		var quad := _quads[i]
		var mesh := quad.mesh as QuadMesh
		var height: float = float(cfg["height_m"])
		if mesh != null and (not is_equal_approx(mesh.size.x, width) or not is_equal_approx(mesh.size.y, height)):
			mesh.size = Vector2(width, height)
			_materials[i].uv1_scale = Vector3(width / tile_width, 1.0, 1.0)
		quad.global_position = Vector3(camera_x, float(cfg["y_center"]), z_depth)
		var offset := camera_x * float(cfg["parallax"]) / tile_width
		_materials[i].uv1_offset = Vector3(offset, 0.0, 0.0)
