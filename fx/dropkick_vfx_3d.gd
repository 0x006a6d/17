class_name DropkickVfx3D
extends Node3D

## △必殺専用。助走中は実ボーン軌道を非表示で採取し、PlayerAction の
## 実ダメージ発生フレームで蹴り足に沿う衝撃と短い地面爆発を同時に出す。

signal impact_spawned(center: Vector3, radius: float)

const KickTrailRibbon := preload("res://fx/kick_trail_ribbon_3d.gd")
const ElectrocutionLightning := preload("res://fx/electrocution_lightning_3d.gd")

const PUNCH_SMOKE_TEXTURE: Texture2D = preload(
	"res://assets/fx_textures/generated/left_hook_contact_smoke_v14.png")
const PUNCH_PLASMA_TEXTURE: Texture2D = preload(
	"res://assets/fx_textures/generated/left_hook_contact_plasma_v18_alpha.png")

const ADD_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.68, 0.08, 1.0);
uniform float emission_energy = 5.0;
uniform float opacity = 0.0;
void fragment() {
	ALBEDO = tint.rgb * 0.28;
	EMISSION = tint.rgb * emission_energy;
	ALPHA = tint.a * opacity;
}
"""

const IMPACT_SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled;
uniform vec4 tint : source_color = vec4(0.035, 0.012, 0.004, 0.82);
uniform float emission_energy = 0.0;
uniform float opacity = 0.0;
void fragment() {
	ALBEDO = tint.rgb;
	EMISSION = vec3(0.0);
	ALPHA = tint.a * opacity;
}
"""

const BLOOM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.76, 0.16, 1.0);
uniform float emission_energy = 7.0;
uniform float opacity = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(vec2(p.x, p.y * 1.15));
	float core = 1.0 - smoothstep(0.03, 0.34, r);
	float halo = 1.0 - smoothstep(0.18, 0.95, r);
	float angle = atan(p.y, p.x);
	float rays = pow(max(0.0, cos(angle * 9.0 + r * 7.0)), 18.0)
		* (1.0 - smoothstep(0.10, 1.0, r));
	float shape = max(core, halo * 0.48 + rays * 0.48);
	vec3 ivory = vec3(1.0, 0.995, 0.90);
	vec3 color = mix(tint.rgb, ivory, core * 0.92 + rays * 0.36);
	ALBEDO = color * 0.32;
	EMISSION = color * emission_energy;
	ALPHA = shape * tint.a * opacity;
}
"""

const BURST_SMOKE_TEXTURE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform sampler2D effect_texture : source_color;
uniform vec4 tint : source_color = vec4(0.07, 0.022, 0.004, 0.62);
uniform float emission_energy = 0.0;
uniform float opacity = 0.0;
void fragment() {
	// Mirror the punch plume around its hot end so the dark mass opens from the
	// impact center in both directions instead of becoming a rectangular card.
	float source_x = clamp(0.86 - abs(UV.x - 0.5) * 1.72, 0.0, 1.0);
	vec4 tex = texture(effect_texture, vec2(source_x, UV.y));
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	float density = smoothstep(0.006, 0.15, luminance);
	float vertical = smoothstep(0.0, 0.10, UV.y)
		* (1.0 - smoothstep(0.90, 1.0, UV.y));
	vec3 smoke = mix(tint.rgb, tex.rgb * vec3(0.30, 0.12, 0.035), 0.38);
	ALBEDO = smoke;
	ALPHA = density * vertical * tint.a * opacity;
}
"""

const BURST_PLASMA_TEXTURE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform sampler2D effect_texture : source_color;
uniform vec4 tint : source_color = vec4(1.0, 0.72, 0.18, 0.72);
uniform float emission_energy = 4.2;
uniform float opacity = 0.0;
void fragment() {
	float source_x = clamp(0.86 - abs(UV.x - 0.5) * 1.72, 0.0, 1.0);
	vec4 tex = texture(effect_texture, vec2(source_x, UV.y));
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	float density = max(tex.a, smoothstep(0.02, 0.34, luminance));
	float vertical = smoothstep(0.0, 0.08, UV.y)
		* (1.0 - smoothstep(0.92, 1.0, UV.y));
	vec3 ivory = vec3(1.0, 0.985, 0.90);
	vec3 color = mix(tex.rgb * tint.rgb, ivory,
		smoothstep(0.58, 0.96, luminance) * 0.72);
	ALBEDO = color * 0.30;
	EMISSION = color * emission_energy;
	ALPHA = density * vertical * tint.a * opacity;
}
"""

const CONTACT_BLOOM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.76, 0.16, 1.0);
uniform float emission_energy = 7.0;
uniform float opacity = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(vec2(p.x, p.y * 1.32));
	float core = 1.0 - smoothstep(0.02, 0.22, r);
	float body = 1.0 - smoothstep(0.10, 0.56, r);
	float halo = 1.0 - smoothstep(0.28, 1.0, r);
	vec3 ivory = vec3(1.0, 0.997, 0.88);
	vec3 color = mix(tint.rgb, ivory, max(core, body * 0.72));
	ALBEDO = color * 0.32;
	EMISSION = color * emission_energy;
	ALPHA = max(body, halo * 0.34) * tint.a * opacity;
}
"""

const CONTACT_CRESCENT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.78, 0.08, 1.0);
uniform float emission_energy = 12.0;
uniform float opacity = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y *= 1.06;
	float angle = atan(p.y, p.x);
	float grain = sin(angle * 13.0 + length(p) * 19.0) * 0.018
		+ sin(p.y * 31.0 - p.x * 9.0) * 0.010;
	float outer_d = length(p) + grain;
	float inner_d = length(p + vec2(0.31, -0.035)) - grain * 0.7;
	float outer = 1.0 - smoothstep(0.78, 0.91, outer_d);
	float inner = 1.0 - smoothstep(0.53, 0.66, inner_d);
	float body = clamp(outer - inner, 0.0, 1.0);
	float halo_outer = 1.0 - smoothstep(0.80, 1.03, outer_d);
	float halo_inner = 1.0 - smoothstep(0.46, 0.72, inner_d);
	float halo = clamp(halo_outer - halo_inner, 0.0, 1.0);
	// 左上の細い始点→右側→右下の太い先端だけを残す。
	// 下側から左へ一周する部分は参照に無いため切る。
	float arc_mask = smoothstep(-0.82, -0.54, angle)
		* (1.0 - smoothstep(2.16, 2.42, angle));
	body *= arc_mask;
	halo *= smoothstep(-0.92, -0.48, angle)
		* (1.0 - smoothstep(2.08, 2.52, angle));
	float front = smoothstep(-0.18, 0.82, p.x);
	float lower_tip = smoothstep(-0.52, 0.48, -p.y) * front;
	float fibre = 0.86 + 0.14 * sin(angle * 17.0 + length(p) * 24.0);
	vec3 amber = vec3(1.0, 0.40, 0.015);
	vec3 yellow = tint.rgb;
	vec3 ivory = vec3(1.0, 1.0, 0.86);
	vec3 color = mix(amber, yellow, clamp(body * 0.78 + front * 0.35, 0.0, 1.0));
	color = mix(color, ivory, clamp(lower_tip * 0.72 + body * front * 0.28, 0.0, 1.0));
	ALBEDO = color * 0.30;
	EMISSION = color * emission_energy;
	ALPHA = max(body * fibre, halo * 0.30) * tint.a * opacity;
}
"""

const TRAIL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.65, 0.08, 1.0);
uniform float emission_energy = 5.0;
uniform float opacity = 0.0;
void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float tail = smoothstep(0.0, 0.34, UV.x);
	float fibre = 0.72 + 0.28 * sin(UV.x * 41.0 + UV.y * 8.0);
	float hot = pow(clamp(across, 0.0, 1.0), 4.0);
	vec3 ivory = vec3(1.0, 0.985, 0.82);
	vec3 color = mix(tint.rgb, ivory, hot * 0.88);
	ALBEDO = color * 0.26;
	EMISSION = color * emission_energy;
	ALPHA = pow(clamp(across, 0.0, 1.0), 0.72) * tail * fibre
		* tint.a * opacity;
}
"""

## 身体を横切る軌跡はキャラと敵の深度を受ける。接触弧と白芯だけは
## TRAIL_SHADER の手前描画を使い、参照の「背後の軌跡／敵へ食い込む先端」を分離する。
const BODY_TRAIL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0, 0.65, 0.08, 1.0);
uniform float emission_energy = 5.0;
uniform float opacity = 0.0;
void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float tapered = smoothstep(0.0, 0.20, UV.x);
	float fibres = 0.78 + 0.22 * sin(UV.x * 37.0 + UV.y * 11.0);
	float hot = pow(clamp(across, 0.0, 1.0), 5.0);
	vec3 ivory = vec3(1.0, 0.995, 0.86);
	vec3 color = mix(tint.rgb, ivory, hot * 0.82);
	ALBEDO = color * 0.24;
	EMISSION = color * emission_energy;
	ALPHA = pow(clamp(across, 0.0, 1.0), 0.62) * tapered * fibres
		* tint.a * opacity;
}
"""

const SPIKE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0, 0.68, 0.08, 1.0);
uniform float emission_energy = 6.0;
uniform float opacity = 0.0;
void fragment() {
	float edge = smoothstep(0.0, 0.20, min(UV.x, 1.0 - UV.x));
	float base = smoothstep(0.0, 0.08, UV.y);
	float tip = 1.0 - smoothstep(0.66, 1.0, UV.y);
	float turbulence = 0.76 + 0.24 * sin(UV.y * 31.0 + UV.x * 17.0);
	float hot = pow(max(0.0, 1.0 - UV.y), 2.2) * edge;
	vec3 ivory = vec3(1.0, 0.995, 0.88);
	vec3 color = mix(tint.rgb, ivory, hot * 0.88);
	ALBEDO = color * 0.25;
	EMISSION = color * emission_energy;
	ALPHA = edge * base * tip * turbulence * tint.a * opacity;
}
"""

const GROUND_FLASH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.62, 0.06, 1.0);
uniform float emission_energy = 5.0;
uniform float opacity = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float core = 1.0 - smoothstep(0.02, 0.22, r);
	float disc = (1.0 - smoothstep(0.10, 0.76, r)) * 0.018;
	float under_ring = smoothstep(0.66, 0.80, r)
		* (1.0 - smoothstep(0.86, 1.0, r));
	float rays = pow(max(0.0, cos(atan(p.y, p.x) * 11.0)), 26.0)
		* (1.0 - smoothstep(0.04, 1.0, r));
	vec3 color = mix(tint.rgb, vec3(1.0, 0.995, 0.88), core + rays * 0.7);
	ALBEDO = color * 0.24;
	EMISSION = color * emission_energy;
	ALPHA = max(core, disc + under_ring * 0.72 + rays * 0.28) * tint.a * opacity;
}
"""

const CRATER_DISC_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled;
uniform vec4 tint : source_color = vec4(0.34, 0.20, 0.055, 1.0);
uniform float emission_energy = 4.0;
uniform float opacity = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float warped_r = r + sin(angle * 7.0 + r * 10.0) * 0.018
		+ sin(angle * 13.0 - r * 7.0) * 0.010;
	float disc = 1.0 - smoothstep(0.92, 1.0, warped_r);
	float rim = smoothstep(0.80, 0.91, warped_r)
		* (1.0 - smoothstep(0.90, 1.01, warped_r));
	float sector = abs(fract(angle / 6.2831853 * 9.0
		+ sin(warped_r * 17.0 + angle * 2.0) * 0.035) - 0.5);
	float spokes = (1.0 - smoothstep(0.020, 0.052, sector))
		* smoothstep(0.12, 0.30, warped_r) * (1.0 - smoothstep(0.83, 0.94, warped_r));
	float ring_a = abs(warped_r - (0.38 + sin(angle * 5.0 + 0.7) * 0.055));
	float ring_b = abs(warped_r - (0.66 + sin(angle * 7.0 - 0.4) * 0.045));
	float broken_a = (1.0 - smoothstep(0.014, 0.038, ring_a))
		* smoothstep(-0.75, -0.15, sin(angle * 11.0 + 0.3));
	float broken_b = (1.0 - smoothstep(0.014, 0.036, ring_b))
		* smoothstep(-0.60, 0.05, sin(angle * 13.0 - 0.8));
	float cracks = max(spokes, max(broken_a, broken_b));
	float rim_breaks = 0.34 + 0.66 * smoothstep(-0.45, 0.28,
		sin(angle * 8.0 + warped_r * 5.0));
	vec3 charcoal = vec3(0.026, 0.020, 0.018);
	vec3 warm_rock = vec3(0.115, 0.068, 0.030);
	vec3 amber = vec3(1.0, 0.48, 0.025);
	float facet = 0.34 + 0.24 * sin(angle * 7.0 + floor(r * 5.0) * 1.7);
	vec3 color = mix(charcoal, warm_rock, facet);
	color = mix(color, amber, rim * rim_breaks * 0.30 + cracks * 0.18);
	ALBEDO = color;
	EMISSION = amber * (rim * rim_breaks * 0.20 + cracks * 0.22) * emission_energy;
	// Broken impact plates instead of a filled magic circle.
	float center_plate = 1.0 - smoothstep(0.16, 0.50, warped_r);
	float plate_noise = smoothstep(-0.18, 0.36,
		sin(angle * 9.0 + warped_r * 13.0)
		+ sin(angle * 4.0 - warped_r * 19.0) * 0.42);
	float outer_plates = disc * smoothstep(0.32, 0.52, warped_r)
		* (1.0 - smoothstep(0.84, 0.98, warped_r))
		* smoothstep(0.52, 0.78, plate_noise);
	ALPHA = max(center_plate * 0.68, outer_plates * 0.82) * opacity;
}
"""

const CRATER_CHUNK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled;
uniform vec4 tint : source_color = vec4(0.16, 0.095, 0.035, 1.0);
uniform float emission_energy = 2.5;
uniform float opacity = 0.0;
void fragment() {
	float lower_edge = 1.0 - UV.y;
	vec3 rock = tint.rgb * (0.72 + UV.y * 0.28);
	vec3 amber = vec3(1.0, 0.43, 0.018);
	ALBEDO = mix(rock, amber, lower_edge * 0.12);
	EMISSION = amber * emission_energy * lower_edge * 0.10;
	ALPHA = tint.a * opacity;
}
"""

@export var model_path: NodePath = ^"../Model"
@export_range(6, 24, 1) var trail_max_samples: int = 14
@export var trail_min_sample_distance: float = 0.025
@export var trail_width: float = 0.24
## 命中時にだけ見せる蹴り本体。通常キック3段目と同じ太さ・白芯・黒橙の
## 素材スタックを使い、足元爆発より蹴り方向を主役にする。
@export var impact_kick_duration: float = 0.18
@export var impact_kick_fade_in: float = 0.090
@export var impact_kick_fade_out: float = 0.020
@export var impact_kick_trail_width: float = 0.41064
@export var impact_kick_contact_size: float = 0.848656
## 蹴り出し直後の帯の長さ。上の値に対する比。伸び切りに向けて 1.0 まで伸ばす。
@export_range(0.1, 1.0, 0.01) var impact_kick_start_length_ratio: float = 0.34
## 移動後半のボーン採取は命中方向の計算だけに使う。可視VFXは接触時の
## 固定爆発から始め、足へ貼った絵を画面内で引きずらない。
@export_range(0.5, 0.9, 0.01) var trail_start_ratio: float = 0.70
## 足元の範囲爆発は命中を補助する一瞬のアクセントに留める。
@export var burst_duration: float = 0.045
@export var burst_fade_in: float = 0.006
@export var burst_fade_out: float = 0.032
@export var burst_core_fade_in: float = 0.005
@export var burst_core_hold: float = 0.012
@export var burst_core_fade_out: float = 0.020
## 1 回の必殺で感電させる敵の上限。うち画面を貫く長い雷は最も近い 1 体だけ。
@export_range(1, 8, 1) var max_electrocution_bolts: int = 4

var _skeleton: Skeleton3D = null
var _hip_bone: int = -1
var _leg_bone: int = -1
var _foot_bone: int = -1
var _toe_bone: int = -1
var _samples := PackedVector3Array()
var _hip_samples := PackedVector3Array()
var _strike_axis := Vector3.RIGHT
var _windup_active: bool = false
var _windup_releasing: bool = false
var _windup_elapsed: float = 0.0
var _release_elapsed: float = 0.0
var _impact_delay: float = 0.0
var _facing: int = 1

var _windup_aura: MeshInstance3D
var _windup_band: MeshInstance3D
var _windup_core: MeshInstance3D
var _windup_lightning: MeshInstance3D
var _foot_glow: MeshInstance3D
var _foot_crescent_fill: MeshInstance3D
var _foot_crescent_aura: MeshInstance3D
var _foot_crescent: MeshInstance3D
var _foot_crescent_core: MeshInstance3D
var _windup_materials: Array[ShaderMaterial] = []
var _impact_kick_trail: Node3D = null
var _live_kick_axis: Vector3 = Vector3.RIGHT

var _burst_root: Node3D
var _crater_disc: MeshInstance3D
var _crater_chunks: MeshInstance3D
var _outer_ring: MeshInstance3D
var _inner_ring: MeshInstance3D
var _crack_shadow: MeshInstance3D
var _cracks: MeshInstance3D
var _crack_core: MeshInstance3D
var _amber_lightning_shadow: MeshInstance3D
var _amber_lightning: MeshInstance3D
var _amber_lightning_core: MeshInstance3D
var _blue_lightning_shadow: MeshInstance3D
var _blue_lightning: MeshInstance3D
var _blue_lightning_core: MeshInstance3D
var _ground_flash: MeshInstance3D
var _burst_smoke_texture: MeshInstance3D
var _burst_plasma_texture: MeshInstance3D
var _spike_glow: MeshInstance3D
var _spike_body: MeshInstance3D
var _spike_core: MeshInstance3D
var _bloom: MeshInstance3D
var _bloom_core: MeshInstance3D
var _smoke_bloom: MeshInstance3D
var _burst_materials: Array[ShaderMaterial] = []
var _burst_core_materials: Array[ShaderMaterial] = []
var _burst_active: bool = false
var _burst_elapsed: float = 0.0
var _burst_radius: float = 0.0
var _light: OmniLight3D


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_resolve_skeleton()
	_build_windup_nodes()
	_build_burst_nodes()
	set_physics_process(false)
	set_process(false)


func begin(facing: int, impact_delay: float) -> void:
	_resolve_skeleton()
	_facing = 1 if facing >= 0 else -1
	_impact_delay = maxf(impact_delay, 0.05)
	_samples.clear()
	_hip_samples.clear()
	_strike_axis = Vector3.RIGHT * float(_facing)
	_windup_elapsed = 0.0
	_release_elapsed = 0.0
	_windup_active = true
	_windup_releasing = false
	_burst_active = false
	_burst_root.visible = false
	_set_material_opacity(_windup_materials, 0.0)
	_clear_impact_kick_trail()
	set_physics_process(true)
	set_process(true)


func impact(center: Vector3, radius: float, front_distance: float = 0.0,
		_front_width: float = 0.0, facing: int = 1) -> void:
	_facing = 1 if facing >= 0 else -1
	# ダメージ発生フレームの足先と脚軸を最後に取り直す。助走中に採った
	# 1フレーム前の位置を表示すると、動作中だけ足から外れて見える。
	_append_foot_sample()
	_update_windup_geometry()
	_update_following_stage3_kick()
	_windup_active = false
	# Contact starts the fade-out, but the kick art continues following the live
	# foot through the last part of the motion instead of freezing at the hit.
	_windup_releasing = true
	_release_elapsed = 0.0
	_set_material_opacity(_windup_materials, 0.0)
	_burst_active = true
	_burst_elapsed = 0.0
	_burst_radius = maxf(radius, 0.25)
	var ground_center := center
	# CharacterBody の原点は接地中ほぼ床面にある。少しだけ上へ逃がして、
	# 地面リングと炎柱の根元が床メッシュへ埋まらないようにする。
	ground_center.y += 0.035
	_burst_root.global_position = ground_center
	_burst_root.visible = true
	_rebuild_burst(maxf(_burst_radius, front_distance), _burst_radius)
	_set_material_opacity(_burst_materials, 0.0)
	_light.light_energy = 0.0
	impact_spawned.emit(ground_center, _burst_radius)
	set_physics_process(true)
	set_process(true)


## 感電した敵の位置へ雷を立てる。敵はこの後ノックバックで動くが、雷は着弾位置に残す。
## 画面を貫く長い雷は着弾点に最も近い1体だけに立て、残りは足元の短い感電に留める。
## 全員に長い雷を立てると画面上部が雷で埋まって何も読めなくなる。
func electrocute(points: PackedVector3Array) -> void:
	if points.is_empty():
		return
	var center := _burst_root.global_position
	var ordered := Array(points)
	ordered.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))
	var spawned := 0
	for point: Vector3 in ordered:
		if spawned >= max_electrocution_bolts:
			return
		_spawn_electrocution(point, spawned == 0)
		spawned += 1


func _spawn_electrocution(point: Vector3, primary: bool) -> void:
	var bolt := ElectrocutionLightning.new() as Node3D
	bolt.name = &"ElectrocutionLightning"
	bolt.top_level = true
	if not primary:
		# 従は幹を伸ばさず、枝も出さない。感電しているのは分かるが主役を食わない。
		bolt.set(&"height_ratio", float(bolt.get(&"height_ratio")) * 0.21)
		bolt.set(&"trunk_count_min", 2)
		bolt.set(&"trunk_count_max", 3)
		bolt.set(&"branch_depth", 0)
		bolt.set(&"plasma_count", 9)
		bolt.set(&"light_energy_peak", 0.55)
		bolt.set(&"duration", 0.38)
	var ground := point
	ground.y += 0.02
	# _ready() は add_child() の中で同期実行される。そこで画面高とライトの
	# 到達範囲を決めるので、位置を先に入れておかないと原点で測ってしまう。
	bolt.position = ground
	add_child(bolt)


func cancel() -> void:
	_windup_active = false
	_windup_releasing = false
	_burst_active = false
	_samples.clear()
	_hip_samples.clear()
	_set_material_opacity(_windup_materials, 0.0)
	_set_material_opacity(_burst_materials, 0.0)
	_clear_impact_kick_trail()
	_burst_root.visible = false
	_light.light_energy = 0.0
	set_physics_process(false)
	set_process(false)


func is_burst_active() -> bool:
	return _burst_active


func burst_radius() -> float:
	return _burst_radius


func trail_endpoint() -> Vector3:
	return _samples[_samples.size() - 1] if not _samples.is_empty() \
		else Vector3.ZERO


func live_kick_axis() -> Vector3:
	return _live_kick_axis


func _physics_process(_delta: float) -> void:
	if _windup_active:
		if _windup_elapsed < _impact_delay * trail_start_ratio:
			return
		_append_foot_sample()
		_update_windup_geometry()
		_update_following_stage3_kick()
	elif _windup_releasing:
		_append_foot_sample()
		_update_following_stage3_kick()


func _process(delta: float) -> void:
	if _windup_active:
		_windup_elapsed += delta
		# The run-up remains clean. Only the last kicking phase fades in, after which
		# the third-kick material follows the live foot and leg axis.
		_set_material_opacity(_windup_materials, 0.0)
		var kick_start := _impact_delay * trail_start_ratio
		var kick_time := maxf(_windup_elapsed - kick_start, 0.0)
		_set_following_kick_opacity(_smooth(kick_time \
			/ maxf(impact_kick_fade_in, 0.001)))
	elif _windup_releasing:
		_release_elapsed += delta
		_set_following_kick_opacity(1.0 - _smooth(_release_elapsed \
			/ maxf(impact_kick_fade_out, 0.001)))
		if _release_elapsed >= impact_kick_fade_out:
			_windup_releasing = false
			_set_material_opacity(_windup_materials, 0.0)
			_clear_impact_kick_trail()

	if _burst_active:
		_burst_elapsed += delta
		var opacity := _burst_opacity(_burst_elapsed)
		_set_material_opacity(_burst_materials, opacity)
		var core_opacity := _burst_core_opacity(_burst_elapsed)
		_set_material_opacity(_burst_core_materials, core_opacity)
		# Reach almost full damage-area size in the first three frames. A long zoom
		# made the fixed explosion feel like it was chasing the dropkick forward.
		var expand := lerpf(0.82, 1.0, _smooth(_burst_elapsed / 0.025))
		_burst_root.scale = Vector3(expand, lerpf(0.72, 1.0, expand), expand)
		# Punch VFX glows inside its texture; it does not wash both fighters white.
		_light.light_energy = 0.0
		if _burst_elapsed >= burst_duration:
			_burst_active = false
			_burst_root.visible = false
			_light.light_energy = 0.0
	if not _windup_active and not _windup_releasing and not _burst_active:
		set_physics_process(false)
		set_process(false)


func _burst_opacity(time: float) -> float:
	if time < burst_fade_in:
		return _smooth(time / maxf(burst_fade_in, 0.001))
	var fade_start := burst_duration - burst_fade_out
	if time <= fade_start:
		return 1.0
	return 1.0 - _smooth((time - fade_start) / maxf(burst_fade_out, 0.001))


func _burst_core_opacity(time: float) -> float:
	if time < burst_core_fade_in:
		return _smooth(time / maxf(burst_core_fade_in, 0.001))
	if time <= burst_core_hold:
		return 1.0
	return 1.0 - _smooth((time - burst_core_hold) \
		/ maxf(burst_core_fade_out, 0.001))


func _impact_kick_opacity(time: float) -> float:
	if time < impact_kick_fade_in:
		return _smooth(time / maxf(impact_kick_fade_in, 0.001))
	var fade_start := impact_kick_duration - impact_kick_fade_out
	if time <= fade_start:
		return 1.0
	return 1.0 - _smooth((time - fade_start) \
		/ maxf(impact_kick_fade_out, 0.001))


## 蹴り区間のどこまで進んだか。0 が蹴り出し、1 が命中。
func _kick_window_progress() -> float:
	if not _windup_active:
		return 1.0
	var start := _impact_delay * trail_start_ratio
	var span := maxf(_impact_delay - start, 0.001)
	return clampf((_windup_elapsed - start) / span, 0.0, 1.0)


func _update_following_stage3_kick() -> void:
	if _samples.is_empty():
		return
	# 履歴（_samples）は trail_min_sample_distance 未満の動きを捨てるので、命中の瞬間や
	# フェード中に足が少しだけ動くと軌跡と live_kick_axis() が古い位置に残る。
	# 助走の軌跡には履歴を使い、今のキックは足の現在位置から取る。
	var foot := _foot_position()
	if not foot.is_finite():
		foot = _samples[_samples.size() - 1]
	var axis := _leg_axis(foot)
	if axis.length_squared() < 0.000001:
		axis = _strike_axis
	if axis.length_squared() < 0.000001:
		axis = Vector3.RIGHT * float(_facing)
	axis = axis.normalized()
	_live_kick_axis = axis
	# 蹴り出した直後はまだ体が水平で、脛(約0.48m)より長い帯を出すと膝より後ろへ
	# はみ出し、胴を横切る一文字に見える。窓の進みに合わせて短い状態から伸ばす。
	var length := impact_kick_contact_size * lerpf(impact_kick_start_length_ratio,
		1.0, _smooth(_kick_window_progress()))
	var impact_points := PackedVector3Array([
		foot - axis * length,
		foot,
	])
	if not is_instance_valid(_impact_kick_trail):
		var trail := KickTrailRibbon.new() as Node3D
		trail.name = &"DropkickStage3KickTrail"
		add_child(trail)
		trail.call("configure", impact_points, impact_kick_trail_width,
			length, impact_kick_duration, true, axis, false,
			&"high", axis)
		trail.call("set_external_control", true)
		trail.call("set_external_opacity", 0.0)
		_impact_kick_trail = trail
	else:
		# 接触形状も同じ比率で伸ばす。update_path が形を作り直すので、その前に入れる。
		_impact_kick_trail.set(&"_head_size", length)
		_impact_kick_trail.call("update_path", impact_points, axis)


func _set_following_kick_opacity(opacity: float) -> void:
	if is_instance_valid(_impact_kick_trail):
		_impact_kick_trail.call("set_external_opacity", opacity)


func _clear_impact_kick_trail() -> void:
	if not is_instance_valid(_impact_kick_trail):
		_impact_kick_trail = null
		return
	_impact_kick_trail.queue_free()
	_impact_kick_trail = null


func _build_windup_nodes() -> void:
	_windup_aura = _mesh_node("DropkickTrailAura", BODY_TRAIL_SHADER,
		Color(1.0, 0.48, 0.025, 0.22), 3.2, 55, _windup_materials)
	_windup_band = _mesh_node("DropkickTrailBand", BODY_TRAIL_SHADER,
		Color(1.0, 0.72, 0.10, 0.45), 4.6, 56, _windup_materials)
	_windup_core = _mesh_node("DropkickTrailCore", BODY_TRAIL_SHADER,
		Color(1.0, 0.995, 0.84, 0.55), 6.2, 57, _windup_materials)
	_windup_lightning = _mesh_node("DropkickAngularLightning", BODY_TRAIL_SHADER,
		Color(1.0, 0.82, 0.16, 0.70), 7.0, 58, _windup_materials)
	_foot_glow = _mesh_node("DropkickFootGlow", CONTACT_BLOOM_SHADER,
		Color(1.0, 0.92, 0.32, 0.92), 12.0, 59, _windup_materials)
	_foot_crescent_fill = _mesh_node("DropkickContactCrescentFill",
		CONTACT_CRESCENT_SHADER, Color(1.0, 0.82, 0.08, 1.0), 13.0, 60,
		_windup_materials)
	_foot_crescent_aura = _mesh_node("DropkickContactCrescentAura", TRAIL_SHADER,
		Color(1.0, 0.43, 0.015, 0.52), 6.0, 61, _windup_materials)
	_foot_crescent = _mesh_node("DropkickContactCrescent", TRAIL_SHADER,
		Color(1.0, 0.86, 0.12, 0.82), 9.0, 62, _windup_materials)
	_foot_crescent_core = _mesh_node("DropkickContactCrescentCore", TRAIL_SHADER,
		Color(1.0, 1.0, 0.86, 0.76), 11.0, 63, _windup_materials)
	var foot_quad := QuadMesh.new()
	foot_quad.size = Vector2(0.80, 0.54)
	_foot_glow.mesh = foot_quad
	var crescent_quad := QuadMesh.new()
	crescent_quad.size = Vector2(0.88, 0.82)
	_foot_crescent_fill.mesh = crescent_quad


func _build_burst_nodes() -> void:
	_burst_root = Node3D.new()
	_burst_root.name = &"DropkickImpactBurst"
	_burst_root.top_level = true
	add_child(_burst_root)
	_burst_root.visible = false
	_ground_flash = _mesh_node("CraterUnderGlow", GROUND_FLASH_SHADER,
		Color(1.0, 0.68, 0.08, 0.16), 3.6, 46, _burst_materials, _burst_root)
	_crater_disc = _mesh_node("BrokenImpactCrater", CRATER_DISC_SHADER,
		Color(0.10, 0.055, 0.022, 1.0), 3.8, 47, _burst_materials, _burst_root)
	_crater_chunks = _mesh_node("RaisedCraterChunks", CRATER_CHUNK_SHADER,
		Color(0.085, 0.052, 0.030, 0.98), 2.0, 48, _burst_materials, _burst_root)
	_outer_ring = _mesh_node("DamageAreaOuterRing", ADD_SHADER,
		Color(1.0, 0.58, 0.035, 0.045), 2.5, 49, _burst_materials, _burst_root)
	_inner_ring = _mesh_node("DamageAreaWhiteRing", ADD_SHADER,
		Color(1.0, 0.58, 0.035, 0.028), 2.0, 50, _burst_materials, _burst_root)
	_crack_shadow = _mesh_node("GroundCrackBlackBody", IMPACT_SHADOW_SHADER,
		Color(0.028, 0.010, 0.003, 0.88), 0.0, 50, _burst_materials, _burst_root)
	_cracks = _mesh_node("GroundLightningCracks", ADD_SHADER,
		Color(1.0, 0.45, 0.012, 0.62), 5.8, 51, _burst_materials, _burst_root)
	_crack_core = _mesh_node("GroundCrackWhiteCore", ADD_SHADER,
		Color(1.0, 0.985, 0.82, 0.72), 8.0, 52, _burst_materials, _burst_root)
	# Punch-like black/amber/ivory is the main bolt. Blue-white outer forks echo
	# the reference without replacing the established combat palette.
	_amber_lightning_shadow = _mesh_node("ImpactLightningBlackBody",
		IMPACT_SHADOW_SHADER, Color(0.025, 0.007, 0.002, 0.66), 0.0, 64,
		_burst_materials, _burst_root)
	_amber_lightning = _mesh_node("ImpactLightningAmber", ADD_SHADER,
		Color(1.0, 0.43, 0.012, 0.50), 6.5, 65, _burst_materials, _burst_root)
	_amber_lightning_core = _mesh_node("ImpactLightningIvoryCore", ADD_SHADER,
		Color(1.0, 0.995, 0.88, 0.68), 9.0, 66, _burst_materials, _burst_root)
	_blue_lightning_shadow = _mesh_node("OuterLightningBlueAura",
		ADD_SHADER, Color(0.055, 0.20, 0.72, 0.12), 3.2, 67,
		_burst_materials, _burst_root)
	_blue_lightning = _mesh_node("OuterLightningBlue", ADD_SHADER,
		Color(0.18, 0.56, 1.0, 0.52), 6.2, 68, _burst_materials, _burst_root)
	_blue_lightning_core = _mesh_node("OuterLightningWhiteCore", ADD_SHADER,
		Color(0.84, 0.96, 1.0, 0.64), 8.4, 69, _burst_materials, _burst_root)
	var ground_quad := QuadMesh.new()
	ground_quad.size = Vector2.ONE
	_ground_flash.mesh = ground_quad
	_ground_flash.basis = Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
	_ground_flash.position = Vector3.UP * 0.018
	_crater_disc.mesh = ground_quad.duplicate()
	_crater_disc.basis = Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
	_crater_disc.position = Vector3.UP * 0.052
	_burst_smoke_texture = _mesh_node("ExplosionPunchSmoke",
		BURST_SMOKE_TEXTURE_SHADER, Color(0.065, 0.018, 0.003, 0.80), 0.0,
		52, _burst_materials, _burst_root, PUNCH_SMOKE_TEXTURE)
	_burst_plasma_texture = _mesh_node("ExplosionPunchPlasma",
		BURST_PLASMA_TEXTURE_SHADER, Color(1.0, 0.72, 0.18, 0.56), 2.4,
		53, _burst_materials, _burst_root, PUNCH_PLASMA_TEXTURE)
	_spike_glow = _mesh_node("ExplosionSpikeGlow", SPIKE_SHADER,
		Color(1.0, 0.52, 0.018, 0.14), 2.0, 54, _burst_materials, _burst_root)
	_spike_body = _mesh_node("ExplosionSpikeBody", SPIKE_SHADER,
		Color(1.0, 0.78, 0.10, 0.30), 3.6, 55, _burst_materials, _burst_root)
	_spike_core = _mesh_node("ExplosionSpikeCore", SPIKE_SHADER,
		Color(1.0, 0.995, 0.82, 0.20), 3.2, 56, _burst_materials, _burst_root)
	_smoke_bloom = _mesh_node("ExplosionAmberVolume", BLOOM_SHADER,
		Color(1.0, 0.58, 0.025, 0.12), 1.8, 57, _burst_materials, _burst_root)
	_bloom = _mesh_node("ExplosionWhiteBloom", BLOOM_SHADER,
		Color(1.0, 0.76, 0.08, 0.0), 0.0, 58, _burst_materials, _burst_root)
	_bloom_core = _mesh_node("ExplosionIvoryCore", BLOOM_SHADER,
		Color(1.0, 0.99, 0.82, 0.0), 0.0, 59, _burst_materials, _burst_root)
	for core_layer: MeshInstance3D in [_spike_core, _bloom_core]:
		_burst_core_materials.append(core_layer.material_override as ShaderMaterial)
	var bloom_quad := QuadMesh.new()
	bloom_quad.size = Vector2(1.0, 1.0)
	_bloom.mesh = bloom_quad
	_smoke_bloom.mesh = bloom_quad.duplicate()
	_bloom_core.mesh = bloom_quad.duplicate()
	_light = OmniLight3D.new()
	_light.name = &"DropkickExplosionLight"
	_light.light_color = Color(1.0, 0.58, 0.10)
	_light.light_energy = 0.0
	_light.omni_range = 4.5
	_light.omni_attenuation = 1.35
	_light.shadow_enabled = false
	_burst_root.add_child(_light)


func _rebuild_burst(visual_reach: float, damage_radius: float) -> void:
	var crater_radius := damage_radius * 0.58
	_outer_ring.mesh = _ring_mesh(damage_radius, damage_radius * 0.035, 64)
	_inner_ring.mesh = _ring_mesh(crater_radius, damage_radius * 0.024, 56)
	_crack_shadow.mesh = _ground_crack_mesh(crater_radius * 1.10, 10, 3.6)
	_cracks.mesh = _ground_crack_mesh(crater_radius * 1.10, 10, 1.9)
	_crack_core.mesh = _ground_crack_mesh(crater_radius * 1.10, 10, 0.66)
	(_crater_disc.mesh as QuadMesh).size = Vector2.ONE * crater_radius * 2.05
	_crater_chunks.mesh = _crater_chunk_mesh(crater_radius, 14)
	(_ground_flash.mesh as QuadMesh).size = Vector2.ONE * crater_radius * 2.20
	# 範囲端はリングで示し、噴出は中心に密集させる。均一な三角柱ではなく、
	# 曲がりと太さが異なる炎状リボンを重ねて地面から破裂する形にする。
	_spike_glow.mesh = _spike_mesh(visual_reach * 0.66,
		damage_radius * 0.70, 4, 1.55)
	_spike_body.mesh = _spike_mesh(visual_reach * 0.56,
		damage_radius * 0.60, 5, 1.15)
	_spike_core.mesh = _spike_mesh(visual_reach * 0.34,
		damage_radius * 0.44, 3, 0.66)
	var camera := get_viewport().get_camera_3d()
	var normal := -camera.global_basis.z.normalized() if camera != null \
		else Vector3.FORWARD
	var right := camera.global_basis.x.normalized() if camera != null \
		else Vector3.RIGHT
	var up := normal.cross(right).normalized()
	if up.dot(Vector3.UP) < 0.0:
		up = -up
	var billboard_basis := Basis(right, up, normal)
	_amber_lightning_shadow.basis = billboard_basis
	_amber_lightning.basis = billboard_basis
	_amber_lightning_core.basis = billboard_basis
	_blue_lightning_shadow.basis = billboard_basis
	_blue_lightning.basis = billboard_basis
	_blue_lightning_core.basis = billboard_basis
	_amber_lightning_shadow.mesh = _impact_lightning_mesh(damage_radius, 0.035, 0)
	_amber_lightning.mesh = _impact_lightning_mesh(damage_radius, 0.018, 0)
	_amber_lightning_core.mesh = _impact_lightning_mesh(damage_radius, 0.0055, 0)
	_blue_lightning_shadow.mesh = _impact_lightning_mesh(damage_radius, 0.036, 1)
	_blue_lightning.mesh = _impact_lightning_mesh(damage_radius, 0.0125, 1)
	_blue_lightning_core.mesh = _impact_lightning_mesh(damage_radius, 0.0034, 1)
	for lightning: MeshInstance3D in [
		_amber_lightning_shadow, _amber_lightning, _amber_lightning_core,
		_blue_lightning_shadow, _blue_lightning, _blue_lightning_core,
	]:
		lightning.position = Vector3.UP * damage_radius * 0.055
	_burst_smoke_texture.basis = billboard_basis
	_burst_plasma_texture.basis = billboard_basis
	_spike_glow.basis = billboard_basis
	_spike_body.basis = billboard_basis
	_spike_core.basis = billboard_basis
	_smoke_bloom.basis = billboard_basis
	_bloom.basis = billboard_basis
	_bloom_core.basis = billboard_basis
	_burst_smoke_texture.position = Vector3.UP * damage_radius * 0.23
	_burst_plasma_texture.position = Vector3.UP * damage_radius * 0.21
	_smoke_bloom.position = Vector3.UP * damage_radius * 0.28
	_bloom.position = Vector3.UP * damage_radius * 0.23
	_bloom_core.position = Vector3.UP * damage_radius * 0.18
	(_smoke_bloom.mesh as QuadMesh).size = Vector2(damage_radius * 1.34,
		damage_radius * 0.82)
	(_bloom.mesh as QuadMesh).size = Vector2(damage_radius * 1.08,
		damage_radius * 0.52)
	(_bloom_core.mesh as QuadMesh).size = Vector2(damage_radius * 0.58,
		damage_radius * 0.32)
	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2(damage_radius * 1.42, damage_radius * 0.82)
	_burst_smoke_texture.mesh = smoke_quad
	var plasma_quad := QuadMesh.new()
	plasma_quad.size = Vector2(damage_radius * 1.20, damage_radius * 0.66)
	_burst_plasma_texture.mesh = plasma_quad
	_light.position = Vector3.UP * damage_radius * 0.42
	_light.omni_range = damage_radius * 1.25


func _update_windup_geometry() -> void:
	if _samples.size() < 2:
		return
	# 参照の主形状は細い稲妻線ではなく、身体の背後から足先まで連続する
	# 太い橙→黄→白の帯。三層すべてを同じ骨格追従パスへ重ねる。
	var body_path := _angular_path()
	_windup_aura.mesh = _ribbon_mesh(body_path, trail_width * 1.42)
	_windup_band.mesh = _ribbon_mesh(body_path, trail_width * 0.66)
	_windup_core.mesh = _ribbon_mesh(body_path, trail_width * 0.16)
	# 実際の足の移動履歴は細い残光として残し、主形状とは分離する。
	_windup_lightning.mesh = _ribbon_mesh(_samples, trail_width * 0.72)
	var foot := _samples[_samples.size() - 1]
	var contact_path := _crescent_path(foot)
	_foot_crescent_aura.mesh = _ribbon_mesh(contact_path, trail_width * 1.70)
	_foot_crescent.mesh = _ribbon_mesh(contact_path, trail_width * 0.82)
	_foot_crescent_core.mesh = _ribbon_mesh(contact_path, trail_width * 0.22)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var normal := -camera.global_basis.z.normalized()
		var contact_axis := _strike_axis - normal * _strike_axis.dot(normal)
		if contact_axis.length_squared() < 0.0001:
			contact_axis = camera.global_basis.x.normalized() * float(_facing)
		contact_axis = contact_axis.normalized()
		var contact_up := normal.cross(contact_axis).normalized()
		if contact_up.dot(Vector3.UP) < 0.0:
			contact_up = -contact_up
		var contact_basis := Basis(contact_axis, contact_up, normal)
		_foot_glow.basis = contact_basis
		_foot_crescent_fill.basis = contact_basis
		_foot_crescent_fill.position = foot + contact_axis * 0.22
	_foot_glow.position = foot


func _append_foot_sample() -> void:
	var point := _foot_position()
	if not point.is_finite():
		return
	if not _samples.is_empty() and _samples[_samples.size() - 1].distance_to(point) \
			< trail_min_sample_distance:
		return
	_samples.append(point)
	_hip_samples.append(_bone_position(_hip_bone, point - Vector3.UP * 0.85))
	var live_axis := _leg_axis(point)
	var facing_axis := Vector3.RIGHT * float(_facing)
	# 回転後半で足が下を向いても、敵へ最も深く入った水平軸を接触方向として保持する。
	if live_axis.dot(facing_axis) > maxf(_strike_axis.dot(facing_axis), 0.20):
		_strike_axis = live_axis
	while _samples.size() > trail_max_samples:
		_samples.remove_at(0)
		_hip_samples.remove_at(0)


func _foot_position() -> Vector3:
	if _skeleton == null or _foot_bone < 0:
		return global_position
	var foot := (_skeleton.global_transform \
		* _skeleton.get_bone_global_pose(_foot_bone)).origin
	if _toe_bone >= 0:
		var toe := (_skeleton.global_transform \
			* _skeleton.get_bone_global_pose(_toe_bone)).origin
		foot = foot.lerp(toe, 0.62)
	return foot


func _resolve_skeleton() -> void:
	if _skeleton != null and is_instance_valid(_skeleton):
		return
	_skeleton = null
	var model := get_node_or_null(model_path)
	if model == null:
		return
	for node: Node in _descendants(model):
		var skeleton := node as Skeleton3D
		if skeleton != null:
			_skeleton = skeleton
			break
	if _skeleton != null:
		_hip_bone = _skeleton.find_bone(&"Hips")
		# VRM humanoid uses RightLowerLeg. The old non-existent RightLeg lookup
		# silently fell back to a horizontal vector, so the art reached the foot but
		# never rotated with the kicking shin.
		_leg_bone = _skeleton.find_bone(&"RightLowerLeg")
		_foot_bone = _skeleton.find_bone(&"RightFoot")
		_toe_bone = _skeleton.find_bone(&"RightToeBase")
		if _toe_bone < 0:
			_toe_bone = _skeleton.find_bone(&"RightToes")


func _descendants(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child: Node in root.get_children():
		result.append_array(_descendants(child))
	return result


func _angular_path() -> PackedVector3Array:
	if _samples.is_empty():
		return _samples
	var camera := get_viewport().get_camera_3d()
	var normal := -camera.global_basis.z.normalized() if camera != null \
		else Vector3.FORWARD
	var axis := _strike_axis
	axis -= normal * axis.dot(normal)
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT * float(_facing)
	axis = axis.normalized()
	var up := normal.cross(axis).normalized()
	if up.dot(Vector3.UP) < 0.0:
		up = -up
	var foot := _samples[_samples.size() - 1]
	var hip := _hip_samples[_hip_samples.size() - 1] if not _hip_samples.is_empty() \
		else foot - axis * 0.75
	# 固定テンプレートではなく、現在の腰→蹴り足を骨格にする。後方の二点だけを
	# 実移動方向へ折り、参照の身体を包む角張った残光へする。
	var result := PackedVector3Array()
	result.append(hip - axis * 1.48 - up * 0.34)
	result.append(hip - axis * 1.22 + up * 0.56)
	result.append(hip - axis * 0.54 + up * 0.32)
	result.append(hip - axis * 0.18 + up * 0.58)
	result.append(hip + axis * 0.20 + up * 0.20)
	result.append(foot - axis * 0.42 + up * 0.25)
	result.append(foot - axis * 0.12)
	result.append(foot + axis * 0.16)
	return result


func _crescent_path(foot: Vector3) -> PackedVector3Array:
	var camera := get_viewport().get_camera_3d()
	var normal := -camera.global_basis.z.normalized() if camera != null \
		else Vector3.FORWARD
	var axis := _strike_axis
	axis -= normal * axis.dot(normal)
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT * float(_facing)
	axis = axis.normalized()
	var up := normal.cross(axis).normalized()
	if up.dot(Vector3.UP) < 0.0:
		up = -up
	# 半月の中心を敵側へ入れ、表面に貼らず内部を貫く見え方にする。
	var center := foot + axis * 0.10
	var result := PackedVector3Array()
	# 上側の細い導線から始まり、敵へ食い込む下側の黄白い先端へ太くなる。
	# _ribbon_mesh は終点ほど太くなるため、参照どおり上→下の順で並べる。
	for index: int in 12:
		var angle := lerpf(PI * 0.56, -PI * 0.36, float(index) / 11.0)
		result.append(center + axis * cos(angle) * 0.40 + up * sin(angle) * 0.36)
	return result


func _leg_axis(foot: Vector3) -> Vector3:
	var leg := _bone_position(_leg_bone, foot - Vector3.RIGHT * float(_facing) * 0.45)
	var axis := foot - leg
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var normal := -camera.global_basis.z.normalized()
		axis -= normal * axis.dot(normal)
	if axis.length_squared() < 0.0001:
		return Vector3.RIGHT * float(_facing)
	return axis.normalized()


func _bone_position(bone: int, fallback: Vector3) -> Vector3:
	if _skeleton == null or bone < 0:
		return fallback
	return (_skeleton.global_transform * _skeleton.get_bone_global_pose(bone)).origin


func _ribbon_mesh(points: PackedVector3Array, width: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if points.size() < 2:
		return mesh
	var camera := get_viewport().get_camera_3d()
	var normal := -camera.global_basis.z.normalized() if camera != null \
		else Vector3.FORWARD
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for index: int in points.size():
		var tangent := points[mini(index + 1, points.size() - 1)] \
			- points[maxi(index - 1, 0)]
		tangent -= normal * tangent.dot(normal)
		if tangent.length_squared() < 0.000001:
			tangent = Vector3.RIGHT
		var side := normal.cross(tangent.normalized()).normalized()
		var ratio := float(index) / float(points.size() - 1)
		var half_width := width * 0.5 * lerpf(0.18, 1.0, ratio)
		vertices.append(points[index] + side * half_width)
		vertices.append(points[index] - side * half_width)
		uvs.append(Vector2(ratio, 0.0))
		uvs.append(Vector2(ratio, 1.0))
	for index: int in points.size() - 1:
		var base := index * 2
		indices.append_array(PackedInt32Array([
			base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _crater_chunk_mesh(radius: float, count: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for index: int in count:
		# Missing sectors keep the rubble from reading as a manufactured ring.
		if index % 4 == 1:
			continue
		var step := TAU / float(count)
		var gap := step * (0.10 + 0.035 * float(index % 3))
		var angle_a := float(index) * step + gap
		var angle_b := float(index + 1) * step - gap
		var wobble := sin(float(index) * 2.31 + 0.4)
		var outer := radius * (0.78 + wobble * 0.16
			+ 0.08 * sin(float(index) * 4.07))
		var inner_a := radius * (0.30 + 0.16 * sin(float(index) * 3.17))
		var inner_b := radius * (0.34 + 0.14 * cos(float(index) * 2.73))
		var inner_angle_a := angle_a + step * (0.06 + 0.035 * float(index % 2))
		var inner_angle_b := angle_b - step * (0.05 + 0.025 * float((index + 1) % 2))
		var top_y := radius * (0.055
			+ 0.085 * absf(sin(float(index) * 1.91 + 0.2)))
		var outer_a := Vector3(cos(angle_a) * outer, top_y, sin(angle_a) * outer)
		var outer_b := Vector3(cos(angle_b) * outer, top_y, sin(angle_b) * outer)
		var inner_point_a := Vector3(cos(inner_angle_a) * inner_a, top_y * 0.62,
			sin(inner_angle_a) * inner_a)
		var inner_point_b := Vector3(cos(inner_angle_b) * inner_b, top_y * 0.62,
			sin(inner_angle_b) * inner_b)
		var base := vertices.size()
		# 不揃いな台形の上面。
		vertices.append(inner_point_a)
		vertices.append(outer_a)
		vertices.append(inner_point_b)
		vertices.append(outer_b)
		uvs.append_array(PackedVector2Array([
			Vector2(0.0, 1.0), Vector2(0.0, 1.0),
			Vector2(1.0, 1.0), Vector2(1.0, 1.0)]))
		indices.append_array(PackedInt32Array([
			base, base + 1, base + 2, base + 1, base + 3, base + 2]))
		# 外周の垂直面を足し、平面デカールではない厚みを見せる。
		var side_base := vertices.size()
		vertices.append(Vector3(outer_a.x, 0.015, outer_a.z))
		vertices.append(outer_a)
		vertices.append(Vector3(outer_b.x, 0.015, outer_b.z))
		vertices.append(outer_b)
		uvs.append_array(PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(0.0, 1.0),
			Vector2(1.0, 0.0), Vector2(1.0, 1.0)]))
		indices.append_array(PackedInt32Array([
			side_base, side_base + 1, side_base + 2,
			side_base + 1, side_base + 3, side_base + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _ring_mesh(radius: float, width: float, segments: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var inner := maxf(radius - width, 0.01)
	for index: int in segments + 1:
		var angle := TAU * float(index) / float(segments)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		vertices.append(direction * inner + Vector3.UP * 0.025)
		vertices.append(direction * radius + Vector3.UP * 0.025)
	for index: int in segments:
		var base := index * 2
		indices.append_array(PackedInt32Array([
			base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _spike_mesh(half_width: float, height: float, count: int,
		width_scale: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	const SEGMENTS := 4
	for index: int in count:
		var ratio := (float(index) + 0.5) / float(count)
		var centered := ratio * 2.0 - 1.0
		var jitter := sin(float(index) * 5.17 + 0.8) * half_width * 0.09
		# 根元は着弾中心へ集め、先端だけを範囲方向へ広げる。
		# これで縦炎の柵ではなく、参照の中心から外へ裂ける放射形になる。
		var base_x := centered * half_width * 0.16 + jitter * 0.24
		var tip_x := centered * half_width + jitter
		var cadence := 0.56 + 0.44 * absf(sin(float(index) * 2.173 + 0.6))
		var edge_falloff := 0.68 + 0.32 * (1.0 - absf(centered))
		var spike_height := height * cadence * edge_falloff
		var bend := sin(float(index) * 4.13 + 0.4) * half_width * 0.055
		var base_half := half_width / float(count) * width_scale \
			* (0.64 + 0.36 * absf(sin(float(index) * 1.71 + 0.3)))
		var strip_start := vertices.size()
		for segment: int in SEGMENTS + 1:
			var t := float(segment) / float(SEGMENTS)
			var curve := pow(t, 0.82)
			var center_x := lerpf(base_x, tip_x, curve) + bend * sin(t * PI) \
				+ sin(t * PI) * sin(float(index) * 2.8) * base_half * 0.34
			var center_y := spike_height * t
			var half := base_half * pow(1.0 - t, 0.72) + 0.008
			vertices.append(Vector3(center_x - half, center_y + 0.02, 0.0))
			vertices.append(Vector3(center_x + half, center_y + 0.02, 0.0))
			uvs.append(Vector2(0.0, t))
			uvs.append(Vector2(1.0, t))
		for segment: int in SEGMENTS:
			var base := strip_start + segment * 2
			indices.append_array(PackedInt32Array([
				base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _impact_lightning_mesh(radius: float, width_ratio: float,
		branch_group: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var paths: Array[PackedVector2Array] = []
	if branch_group == 0:
		# Main punch-coloured discharge: a tall broken trunk with two short forks.
		paths = [
			PackedVector2Array([Vector2(0.00, 0.00), Vector2(0.08, 0.18),
				Vector2(-0.03, 0.34), Vector2(0.09, 0.52),
				Vector2(0.01, 0.72), Vector2(0.13, 0.96)]),
			PackedVector2Array([Vector2(-0.01, 0.06), Vector2(-0.17, 0.15),
				Vector2(-0.12, 0.29), Vector2(-0.38, 0.39)]),
			PackedVector2Array([Vector2(0.04, 0.04), Vector2(0.16, 0.12),
				Vector2(0.12, 0.23), Vector2(0.31, 0.33)]),
		]
	else:
		# The reference's blue-white forks spread beyond the rubble and frame the
		# amber center. Their paths are intentionally asymmetric and angular.
		paths = [
			PackedVector2Array([Vector2(-0.03, 0.03), Vector2(-0.17, 0.12),
				Vector2(-0.21, 0.22), Vector2(-0.31, 0.29),
				Vector2(-0.27, 0.38), Vector2(-0.48, 0.46),
				Vector2(-0.56, 0.58), Vector2(-0.72, 0.65),
				Vector2(-0.83, 0.77), Vector2(-1.12, 0.84)]),
			PackedVector2Array([Vector2(0.02, 0.03), Vector2(0.18, 0.11),
				Vector2(0.26, 0.20), Vector2(0.22, 0.29),
				Vector2(0.40, 0.35), Vector2(0.48, 0.45),
				Vector2(0.64, 0.49), Vector2(0.73, 0.61),
				Vector2(0.91, 0.66), Vector2(1.08, 0.72)]),
			PackedVector2Array([Vector2(-0.48, 0.46), Vector2(-0.43, 0.60),
				Vector2(-0.55, 0.67), Vector2(-0.66, 0.76)]),
			PackedVector2Array([Vector2(0.48, 0.45), Vector2(0.68, 0.51),
				Vector2(0.73, 0.63), Vector2(0.91, 0.69)]),
		]
	var width := radius * width_ratio
	var path_index := 0
	for path: PackedVector2Array in paths:
		for index: int in path.size() - 1:
			var segment_ratio := (float(index) + 0.5) \
				/ maxf(float(path.size() - 1), 1.0)
			var taper := 0.50 + 0.50 * sin(segment_ratio * PI)
			var irregular := 0.82 + 0.22 \
				* absf(sin(float(index) * 2.37 + float(path_index) * 1.73))
			_append_billboard_segment(vertices, indices,
				path[index] * radius, path[index + 1] * radius,
				width * taper * irregular)
		path_index += 1
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _append_billboard_segment(vertices: PackedVector3Array,
		indices: PackedInt32Array, from: Vector2, to: Vector2, width: float) -> void:
	var direction := to - from
	if direction.length_squared() < 0.000001:
		return
	var side := Vector2(-direction.y, direction.x).normalized() * width * 0.5
	var base := vertices.size()
	vertices.append(Vector3(from.x - side.x, from.y - side.y, 0.0))
	vertices.append(Vector3(from.x + side.x, from.y + side.y, 0.0))
	vertices.append(Vector3(to.x - side.x, to.y - side.y, 0.0))
	vertices.append(Vector3(to.x + side.x, to.y + side.y, 0.0))
	indices.append_array(PackedInt32Array([
		base, base + 1, base + 2, base + 1, base + 3, base + 2]))


func _ground_crack_mesh(radius: float, ray_count: int,
		width_scale: float = 1.0) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for index: int in ray_count:
		var angle := TAU * float(index) / float(ray_count) \
			+ sin(float(index) * 1.91) * 0.16
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-direction.z, 0.0, direction.x)
		var start := direction * radius * (0.10 + 0.07 * float(index % 3))
		var bend := direction * radius * 0.54 \
			+ side * radius * (0.09 if index % 2 == 0 else -0.09)
		var finish := direction * radius * (0.82 + 0.14 * float(index % 2))
		_append_ground_segment(vertices, indices, start, bend,
			radius * 0.018 * width_scale)
		_append_ground_segment(vertices, indices, bend, finish,
			radius * 0.012 * width_scale)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _append_ground_segment(vertices: PackedVector3Array,
		indices: PackedInt32Array, from: Vector3, to: Vector3, width: float) -> void:
	var direction := to - from
	if direction.length_squared() < 0.000001:
		return
	var side := Vector3(-direction.z, 0.0, direction.x).normalized() * width * 0.5
	var base := vertices.size()
	vertices.append(from - side + Vector3.UP * 0.035)
	vertices.append(from + side + Vector3.UP * 0.035)
	vertices.append(to - side + Vector3.UP * 0.035)
	vertices.append(to + side + Vector3.UP * 0.035)
	indices.append_array(PackedInt32Array([
		base, base + 1, base + 2, base + 1, base + 3, base + 2]))


func _mesh_node(node_name: StringName, shader_code: String, tint: Color,
		energy: float, priority: int, materials: Array[ShaderMaterial],
		parent: Node = null, texture: Texture2D = null) -> MeshInstance3D:
	var shader := Shader.new()
	shader.code = shader_code
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = priority
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("emission_energy", energy)
	material.set_shader_parameter("opacity", 0.0)
	if texture != null:
		material.set_shader_parameter("effect_texture", texture)
	materials.append(material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.material_override = material
	var actual_parent: Node = parent if parent != null else self
	actual_parent.add_child(instance)
	return instance


func _set_material_opacity(materials: Array[ShaderMaterial], opacity: float) -> void:
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("opacity", clampf(opacity, 0.0, 1.0))


func _smooth(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
