class_name ElectrocutionLightning3D
extends Node3D

## 感電した敵に憑く雷。着弾位置へ置いて数フレームごとに形を引き直す。
## 幹の長さと折れの細かさはカメラから求めた画面高で決めるので、
## ステージやカメラ距離が変わっても画面上の見え方が保たれる。

const BOLT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.30, 0.58, 1.0, 1.0);
uniform float core_width = 0.17;
uniform float glow_falloff = 1.7;
uniform float energy = 9.0;
uniform float opacity = 0.0;
void fragment() {
	// UV.x はリボンの幅方向、UV.y は根元から先端への進み。
	float across = abs(UV.x * 2.0 - 1.0);
	float core = 1.0 - smoothstep(0.0, core_width, across);
	float glow = pow(max(1.0 - across, 0.0), glow_falloff);
	float taper = 1.0 - smoothstep(0.86, 1.0, UV.y);
	vec3 color = mix(glow_color.rgb, core_color.rgb, core);
	ALBEDO = color * 0.24;
	EMISSION = color * energy * (core + glow * 0.42);
	ALPHA = clamp(core + glow * 0.52, 0.0, 1.0) * taper * opacity;
}
"""

## 消えるまでの秒数。
@export var duration: float = 0.55
## 幹の長さ。画面高に対する比。1.0 を超えると画面外へ抜ける。
@export var height_ratio: float = 0.50
## 幹の本数。引き直すたびにこの範囲で選ぶ。
@export var trunk_count_min: int = 2
@export var trunk_count_max: int = 3
## 折れの間隔。画面高に対する比。小さいほどギザギザが細かくなる。
@export var kink_ratio: float = 0.010
## リボンの幅。画面高に対する比。
@export var bolt_width_ratio: float = 0.019
## 形を引き直す頻度（回/秒）。
@export var regenerate_hz: float = 30.0
## 幹の初期角度の広がり（真上からの度数）。
@export var spread_degrees: float = 46.0
## 1 折れあたりの向きの振れ幅（ラジアン）。
@export var kink_amplitude: float = 0.74
## 幹全体の蛇行の強さ（ラジアン/折れ）。
@export var wander_amplitude: float = 0.022
## 枝分かれの深さ。0 で枝なし。
@export var branch_depth: int = 1
## 着弾点に居座るプラズマの高さ。画面高に対する比。
@export var plasma_height_ratio: float = 0.085
## プラズマの本数。
@export var plasma_count: int = 8
## 雷が周囲を照らす明るさの頂点。
@export var light_energy_peak: float = 0.45

var _rng := RandomNumberGenerator.new()
var _bolts: MeshInstance3D
var _plasma: MeshInstance3D
var _bolt_material: ShaderMaterial
var _plasma_material: ShaderMaterial
var _light: OmniLight3D
var _elapsed: float = 0.0
var _regen_timer: float = 0.0
var _screen_height: float = 5.0
var _amplitude: float = 1.0


func _ready() -> void:
	_rng.randomize()
	_bolts = _build_layer(&"Bolts", Color(0.24, 0.52, 1.0), 0.17, 11.0)
	_bolt_material = _bolts.material_override as ShaderMaterial
	_plasma = _build_layer(&"BasePlasma", Color(0.38, 0.66, 1.0), 0.20, 8.0)
	_plasma_material = _plasma.material_override as ShaderMaterial
	_light = OmniLight3D.new()
	_light.name = &"ElectrocutionLight"
	_light.light_color = Color(0.58, 0.78, 1.0)
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.omni_attenuation = 1.2
	add_child(_light)
	_measure_screen_height()
	_light.position = Vector3.UP * _screen_height * height_ratio * 0.35
	_light.omni_range = _screen_height * height_ratio * 0.55
	_regenerate()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	_measure_screen_height()
	_face_camera()
	_regen_timer -= delta
	if _regen_timer <= 0.0:
		_regen_timer = 1.0 / maxf(regenerate_hz, 1.0)
		_regenerate()
	var opacity := _envelope(_elapsed) * _amplitude
	_bolt_material.set_shader_parameter(&"opacity", opacity)
	_plasma_material.set_shader_parameter(&"opacity", opacity)
	_light.light_energy = light_energy_peak * opacity


## 明滅しつつ終盤で落ちる。参照の発光量は途中まで一定に近く、最後だけ急に減る。
func _envelope(time: float) -> float:
	var fade_in := 0.02
	if time < fade_in:
		return time / fade_in
	var hold := duration * 0.62
	if time <= hold:
		return 1.0
	var t := (time - hold) / maxf(duration - hold, 0.001)
	return 1.0 - t * t


func _build_layer(layer_name: StringName, glow: Color, core_width: float,
		energy: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = layer_name
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = BOLT_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"core_color", Color(1.0, 1.0, 1.0, 1.0))
	material.set_shader_parameter(&"glow_color", glow)
	material.set_shader_parameter(&"core_width", core_width)
	material.set_shader_parameter(&"energy", energy)
	material.set_shader_parameter(&"opacity", 0.0)
	node.material_override = material
	node.sorting_offset = 60.0
	add_child(node)
	return node


## カメラ位置と画角から、この場所での画面高（ワールド単位）を求める。
func _measure_screen_height() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var distance := maxf(camera.global_position.distance_to(global_position), 0.1)
	_screen_height = 2.0 * distance * tan(deg_to_rad(camera.fov) * 0.5)


func _face_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var normal := -camera.global_basis.z.normalized()
	var right := camera.global_basis.x.normalized()
	var up := normal.cross(right).normalized()
	if up.dot(Vector3.UP) < 0.0:
		up = -up
	global_basis = Basis(right, up, normal)


func _regenerate() -> void:
	_amplitude = _rng.randf_range(0.62, 1.0)
	var step := maxf(_screen_height * kink_ratio, 0.002)
	var width := _screen_height * bolt_width_ratio
	_bolts.mesh = _trunk_mesh(step, width)
	_plasma.mesh = _plasma_mesh(step, width)


func _trunk_mesh(step: float, width: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var trunks := _rng.randi_range(trunk_count_min, maxi(trunk_count_max,
		trunk_count_min))
	var reach := _screen_height * height_ratio
	for index: int in trunks:
		# 左右の本数はそろえない。真上寄りに偏らせて、扇ではなく束に見せる。
		var bias := _rng.randf_range(-1.0, 1.0)
		var angle := deg_to_rad(spread_degrees * bias * absf(bias))
		_append_bolt(vertices, uvs, indices, Vector2.ZERO, angle,
			reach * _rng.randf_range(0.72, 1.15), step, width, branch_depth)
	return _build_mesh(vertices, uvs, indices)


## 着弾点に密集する短い放電。雷が消えるまで根元に居座る。
func _plasma_mesh(step: float, width: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var reach := _screen_height * plasma_height_ratio
	var plasma_step := maxf(step * 0.55, 0.001)
	for index: int in plasma_count:
		var angle := _rng.randf_range(-0.62, 0.62)
		_append_bolt(vertices, uvs, indices, Vector2.ZERO, angle,
			reach * _rng.randf_range(0.35, 1.0), plasma_step, width * 0.38, 0)
	return _build_mesh(vertices, uvs, indices)


## 1 本の雷を折れ線で歩き、リボンとして積む。depth が残っていれば途中から枝を出す。
func _append_bolt(vertices: PackedVector3Array, uvs: PackedVector2Array,
		indices: PackedInt32Array, from: Vector2, heading: float,
		length: float, step: float, width: float, depth: int) -> void:
	if length <= step:
		return
	var points := PackedVector2Array([from])
	var position := from
	var direction := heading
	var travelled := 0.0
	while travelled < length:
		direction += _rng.randf_range(-1.0, 1.0) * wander_amplitude
		var kinked := direction + _rng.randf_range(-1.0, 1.0) * kink_amplitude
		position += Vector2(sin(kinked), cos(kinked)) * step
		points.append(position)
		travelled += step
	_append_ribbon(vertices, uvs, indices, points, width)
	if depth <= 0 or points.size() < 6:
		return
	var branches := _rng.randi_range(1, 2)
	for index: int in branches:
		var at := _rng.randi_range(int(points.size() * 0.25),
			int(points.size() * 0.80))
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var branch_heading := heading + side * _rng.randf_range(0.60, 1.20)
		_append_bolt(vertices, uvs, indices, points[at], branch_heading,
			length * _rng.randf_range(0.16, 0.30), step, width * 0.58, depth - 1)


func _append_ribbon(vertices: PackedVector3Array, uvs: PackedVector2Array,
		indices: PackedInt32Array, points: PackedVector2Array,
		width: float) -> void:
	var last := points.size() - 1
	if last < 1:
		return
	# 折れ点では前後の法線を平均して継ぎ、セグメントの角に隙間や重なりを作らない。
	var base := vertices.size()
	for index: int in points.size():
		var ahead := points[mini(index + 1, last)]
		var behind := points[maxi(index - 1, 0)]
		var tangent := ahead - behind
		if tangent.length_squared() < 0.0000001:
			tangent = Vector2.UP
		var side := Vector2(-tangent.y, tangent.x).normalized()
		var v := float(index) / float(last)
		# 先端をわずかに細める。参照の幹は根元から先まで太さがほぼ変わらない。
		var half := width * (1.0 - 0.28 * v) * 0.5
		vertices.append(Vector3(points[index].x - side.x * half,
			points[index].y - side.y * half, 0.0))
		vertices.append(Vector3(points[index].x + side.x * half,
			points[index].y + side.y * half, 0.0))
		uvs.append(Vector2(0.0, v))
		uvs.append(Vector2(1.0, v))
	for index: int in last:
		var a := base + index * 2
		indices.append_array(PackedInt32Array([
			a, a + 1, a + 2, a + 1, a + 3, a + 2]))


func _build_mesh(vertices: PackedVector3Array, uvs: PackedVector2Array,
		indices: PackedInt32Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if indices.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
