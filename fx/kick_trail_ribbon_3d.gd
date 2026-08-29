class_name KickTrailRibbon3D
extends Node3D

## 命中後だけ可視化する、実際の脚ボーン軌道から組み立てるリボン。
## 頂点は世界座標で保持し、このNodeをtop_levelの単位Transformにすることで、
## プレイヤーの踏み込み後も過去の尾が足と一緒にずれないようにする。

const TRAIL_BRIGHT: Texture2D = preload(
	"res://assets/fx_textures/generated/right_straight_trail_plasma_v14_alpha.png")
const TRAIL_CORE: Texture2D = preload(
	"res://assets/fx_textures/generated/right_straight_trail_core_v10.png")
const TRAIL_VOLUME: Texture2D = preload(
	"res://assets/fx_textures/generated/right_straight_trail_volume_v12.png")
const TRAIL_SMOKE: Texture2D = preload(
	"res://assets/fx_textures/generated/right_straight_trail_smoke_v7.png")
const FINISHER_BRIGHT: Texture2D = preload(
	"res://assets/fx_textures/generated/left_hook_contact_plasma_v18_alpha.png")
const FINISHER_VOLUME: Texture2D = preload(
	"res://assets/fx_textures/generated/left_hook_contact_volume_v17.png")
const FINISHER_SMOKE: Texture2D = preload(
	"res://assets/fx_textures/generated/left_hook_contact_smoke_v14.png")
const MIDDLE_PLASMA: Texture2D = preload(
	"res://assets/fx_textures/generated/jab_lead_plasma_v11.png")
const TRAIL_CONTACT: Texture2D = preload(
	"res://assets/fx_textures/generated/right_straight_contact_v4.png")
const CONTACT_CORE_U: float = 0.66
const IMPACT_PLUME_CORE_U: float = 0.89
const HIGH_REAR_AMBER_LENGTH_SCALE: float = 0.42
const HIGH_REAR_WEDGE_LENGTH_SCALE: float = 0.60
## パンチより横へ長い脚軌道は維持し、縦方向の量感だけを揃える。
const TRAIL_MASS_SCALE: float = 1.24
const PLUME_HEIGHT_SCALE: float = 1.22
const CONTACT_HEIGHT_SCALE: float = 1.18

@export_group("Timing")
@export var regular_fade_in_time: float = 0.045
@export var finisher_fade_in_time: float = 0.026
@export var body_fade_out_time: float = 0.10
@export var regular_contact_time: float = 0.105
@export var finisher_contact_time: float = 0.090
@export var scene_light_time: float = 0.10
@export var regular_contact_fade_in_time: float = 0.032
@export var finisher_contact_fade_in_time: float = 0.020
@export var regular_contact_hold_time: float = 0.045
@export var finisher_contact_hold_time: float = 0.036
@export var finisher_outline_fade_in_time: float = 0.030
@export var finisher_outline_hold_time: float = 0.050
@export var finisher_outline_dim_time: float = 0.085
@export var finisher_core_fade_in_time: float = 0.022
@export var finisher_core_hold_time: float = 0.045
@export var finisher_core_fade_out_time: float = 0.055
@export var finisher_band_fade_in_time: float = 0.026
@export var finisher_band_hold_time: float = 0.052
@export var finisher_band_fade_out_time: float = 0.070
@export_group("")

const BRIGHT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D trail_texture : source_color;
uniform vec4 tint : source_color = vec4(1.0, 0.78, 0.24, 0.95);
uniform float emission_energy = 1.8;
uniform float opacity = 0.0;
uniform float ivory_mix = 0.34;

void fragment() {
	vec4 tex = texture(trail_texture, UV);
	float tail = smoothstep(0.0, 0.22, UV.x);
	float head = smoothstep(0.52, 1.0, UV.x);
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 warm = mix(tex.rgb * tint.rgb,
		vec3(luminance) * vec3(1.0, 0.985, 0.88), ivory_mix);
	ALBEDO = warm * 0.32;
	EMISSION = warm * emission_energy * mix(0.72, 1.24, head);
	ALPHA = min(tex.a * 1.12, 1.0) * tint.a * tail * opacity;
}
"""

const SMOKE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D trail_texture : source_color;
uniform vec4 tint : source_color = vec4(0.09, 0.028, 0.006, 0.32);
uniform float opacity = 0.0;

void fragment() {
	vec4 tex = texture(trail_texture, UV);
	float tail = smoothstep(0.0, 0.20, UV.x);
	float density = max(tex.a, dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722)) * 0.72);
	ALBEDO = tint.rgb;
	ALPHA = density * tint.a * tail * opacity;
}
"""

const PLUME_SMOKE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D trail_texture : source_color;
uniform vec4 tint : source_color = vec4(0.06, 0.018, 0.004, 0.40);
uniform float opacity = 0.0;

void fragment() {
	vec4 tex = texture(trail_texture, UV);
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	// The punch smoke atlas has an opaque near-black background. Derive coverage
	// from its painted plume so the kick retains black-brown mass without showing
	// a rectangular card over the fighter.
	float density = smoothstep(0.006, 0.16, luminance);
	float tail = smoothstep(0.0, 0.18, UV.x);
	vec3 smoke_color = mix(tint.rgb, tex.rgb * vec3(0.34, 0.14, 0.045), 0.34);
	ALBEDO = smoke_color;
	ALPHA = density * tint.a * tail * opacity;
}
"""

const PUNCH_STACK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D trail_texture : source_color;
uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.36, 0.9);
uniform float emission_energy = 1.8;
uniform float opacity = 0.0;
uniform float warmth = 0.72;

void fragment() {
	vec4 tex = texture(trail_texture, UV);
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 ivory = vec3(luminance) * vec3(1.0, 0.985, 0.93);
	vec3 colored = mix(ivory, tex.rgb, warmth) * tint.rgb;
	float highlight = smoothstep(0.50, 0.90, luminance);
	ALBEDO = colored * 0.58;
	EMISSION = colored * emission_energy * mix(0.55, 1.25, highlight);
	ALPHA = tex.a * tint.a * opacity;
}
"""

const AURA_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D trail_texture : source_color;
uniform vec4 tint : source_color = vec4(1.0, 0.48, 0.06, 0.52);
uniform float emission_energy = 2.6;
uniform float opacity = 0.0;

void fragment() {
	vec4 tex = texture(trail_texture, UV);
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	float density = max(tex.a, luminance);
	float tail = smoothstep(0.0, 0.20, UV.x);
	float head = smoothstep(0.48, 1.0, UV.x);
	vec3 amber = mix(tint.rgb, vec3(1.0, 0.82, 0.30),
		smoothstep(0.38, 0.92, luminance) * 0.46);
	ALBEDO = amber * 0.22;
	EMISSION = amber * emission_energy * mix(0.64, 1.24, head);
	ALPHA = density * tint.a * tail * opacity;
}
"""

const TRAIL_AURA_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D trail_texture : source_color;
uniform vec4 tint : source_color = vec4(1.0, 0.48, 0.06, 0.52);
uniform float emission_energy = 3.0;
uniform float opacity = 0.0;

void fragment() {
	vec4 tex = texture(trail_texture, UV);
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	float texture_density = max(tex.a, luminance);
	float across = clamp(1.0 - abs(UV.y * 2.0 - 1.0), 0.0, 1.0);
	float soft_band = pow(across, 2.25);
	float fibre = 0.58 + 0.42 * luminance;
	float density = max(texture_density * 0.82, soft_band * fibre * 0.50);
	float tail = smoothstep(0.0, 0.22, UV.x);
	float head = smoothstep(0.44, 1.0, UV.x);
	vec3 amber = mix(tint.rgb, vec3(1.0, 0.88, 0.42),
		clamp(luminance * 0.48 + head * 0.18, 0.0, 0.62));
	ALBEDO = amber * 0.24;
	EMISSION = amber * emission_energy * mix(0.62, 1.22, head);
	ALPHA = density * tint.a * tail * opacity;
}
"""

const BAND_CORE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D trail_texture : source_color;
uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.22, 0.92);
uniform float emission_energy = 5.0;
uniform float opacity = 0.0;

void fragment() {
	vec4 tex = texture(trail_texture, UV);
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	float texture_density = max(tex.a, luminance);
	float across = clamp(1.0 - abs(UV.y * 2.0 - 1.0), 0.0, 1.0);
	float fibre = 0.88 + 0.12 * sin(UV.x * 46.0 + UV.y * 9.0);
	float body = pow(across, 1.45) * fibre;
	float hot = pow(across, 5.2);
	float tail = smoothstep(0.02, 0.24, UV.x);
	float head = smoothstep(0.46, 1.0, UV.x);
	vec3 gold = tint.rgb;
	vec3 ivory = vec3(1.0, 0.985, 0.84);
	vec3 color = mix(gold, ivory,
		clamp(hot * 0.72 + luminance * 0.24 + head * 0.18, 0.0, 0.92));
	float density = max(body * 0.88, texture_density * 0.70);
	ALBEDO = color * 0.34;
	EMISSION = color * emission_energy * mix(0.76, 1.18, head);
	ALPHA = density * tint.a * tail * opacity;
}
"""

const CONTACT_FLASH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.34, 0.9);
uniform float emission_energy = 6.0;
uniform float opacity = 0.0;
uniform float orb_x_scale = 1.0;
uniform float positive_ray_scale = 1.55;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float orb_x = (p.x < 0.0 ? p.x * 0.68 : p.x * 1.70)
		* orb_x_scale;
	float radius = length(vec2(orb_x, p.y * 1.18));
	float orb = 1.0 - smoothstep(0.055, 0.30, radius);
	// The reference impact is a wedge: long toward the attacker (negative X),
	// compact into the enemy. Keep the white core on the foot while warping
	// only the radiating fracture lines.
	float ray_x = p.x < 0.0 ? abs(p.x) * 0.70
		: abs(p.x) * positive_ray_scale;
	float horizontal = (1.0 - smoothstep(0.018, 0.082, abs(p.y)))
		* (1.0 - smoothstep(0.16, 0.48, ray_x));
	float diagonal_a = (1.0 - smoothstep(0.015, 0.055,
		abs(p.y - p.x * 0.48))) * (1.0 - smoothstep(0.14, 0.46, ray_x));
	float diagonal_b = (1.0 - smoothstep(0.015, 0.055,
		abs(p.y + p.x * 0.48))) * (1.0 - smoothstep(0.14, 0.46, ray_x));
	float shape = max(orb, max(horizontal * 0.84,
		max(diagonal_a * 0.72, diagonal_b * 0.20)));
	float white_core = 1.0 - smoothstep(0.025, 0.15,
		length(p * vec2(orb_x_scale, 1.18)));
	vec3 color = mix(tint.rgb, vec3(1.0, 0.995, 0.92), white_core);
	ALBEDO = color * 0.36;
	EMISSION = color * emission_energy;
	ALPHA = shape * tint.a * opacity;
}
"""

const LIGHTNING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.91, 0.55, 0.94);
uniform float emission_energy = 4.8;
uniform float opacity = 0.0;
uniform float albedo_strength = 0.28;

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float needle = pow(clamp(across, 0.0, 1.0), 0.42);
	float tail = smoothstep(0.06, 0.30, UV.x);
	float broken = step(0.12, fract(UV.x * 8.0 + UV.y * 0.31));
	ALBEDO = tint.rgb * albedo_strength;
	EMISSION = tint.rgb * emission_energy;
	ALPHA = needle * tail * mix(0.72, 1.0, broken) * tint.a * opacity;
}
"""

var _smoke: MeshInstance3D
var _aura: MeshInstance3D
var _band_core: MeshInstance3D
var _bright: MeshInstance3D
var _core: MeshInstance3D
var _plume_smoke: MeshInstance3D
var _plume_aura: MeshInstance3D
var _plume_bright: MeshInstance3D
var _plume_core: MeshInstance3D
var _lightning_outer: MeshInstance3D
var _lightning_inner: MeshInstance3D
var _lightning_glow: MeshInstance3D
var _lightning_branch_outer: MeshInstance3D
var _lightning_branch_inner: MeshInstance3D
var _lightning_branch_glow: MeshInstance3D
var _head_glow: MeshInstance3D
var _head: MeshInstance3D
var _flash_halo: MeshInstance3D
var _flash_core: MeshInstance3D
var _foot_light: OmniLight3D
var _materials: Array[ShaderMaterial] = []
var _contact_materials: Array[ShaderMaterial] = []
var _outline_materials: Array[ShaderMaterial] = []
var _outline_core_materials: Array[ShaderMaterial] = []
var _finisher_band_materials: Array[ShaderMaterial] = []
var _width: float = 0.24
var _head_size: float = 0.42
var _duration: float = 0.18
var _fade_in_duration: float = 0.045
var _fade_out_duration: float = 0.10
var _contact_duration: float = 0.115
var _light_duration: float = 0.10
var _elapsed: float = 0.0
var _latest_position: Vector3 = Vector3.ZERO
var _impact_position: Vector3 = Vector3.ZERO
var _latest_direction: Vector3 = Vector3.RIGHT
var _impact_direction: Vector3 = Vector3.RIGHT
var _strike_axis: Vector3 = Vector3.RIGHT
var _base_light_energy: float = 3.4
var _finisher: bool = false
var _technique: StringName = &""
var _external_control: bool = false


func configure(points: PackedVector3Array, width: float, head_size: float,
		duration: float, finisher: bool = false,
		impact_direction: Vector3 = Vector3.RIGHT,
		real_light_enabled: bool = true,
		technique: StringName = &"",
		strike_axis: Vector3 = Vector3.RIGHT) -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_width = width
	_head_size = head_size
	_finisher = finisher
	_technique = technique
	_duration = maxf(duration, 0.08)
	# Build for about three 60 Hz frames, then immediately fade away. The compact
	# white contact leads the amber body and dies first, preserving a readable hit
	# without leaving a long after-image behind the returning leg.
	_fade_in_duration = minf(finisher_fade_in_time if finisher \
		else regular_fade_in_time, _duration * 0.32)
	_fade_out_duration = minf(body_fade_out_time, _duration * 0.56)
	# Punches shed their white contact before the smoky coloured body. Give the
	# final kick the same two-phase read instead of holding one bright picture.
	_contact_duration = minf(finisher_contact_time if finisher \
		else regular_contact_time, _duration * 0.64)
	_light_duration = minf(scene_light_time, _contact_duration)
	_impact_direction = impact_direction
	_impact_direction.y = 0.0
	if _impact_direction.length_squared() < 0.000001:
		_impact_direction = Vector3.RIGHT
	_impact_direction = _impact_direction.normalized()
	_strike_axis = strike_axis
	if _strike_axis.length_squared() < 0.000001:
		_strike_axis = _impact_direction
	_strike_axis = _strike_axis.normalized()
	# Low foot contacts cross close enough to the floor that an OmniLight creates
	# an unrelated orange pool. Their emissive meshes retain the same energy;
	# only stages safely above the floor enable real scene lighting.
	_base_light_energy = (0.8 if _technique == &"middle" else 1.2) \
		if real_light_enabled else 0.0
	var tracked_trail_scale := 0.06 if _technique == &"middle" else 1.0

	_smoke = _new_layer("KickTrailSmoke", SMOKE_SHADER, TRAIL_BRIGHT,
		Color(0.075, 0.020, 0.004,
			(0.28 if finisher else 0.50) * tracked_trail_scale), 0.0, 43)
	_aura = _new_layer("KickTrailAura", TRAIL_AURA_SHADER, TRAIL_BRIGHT,
		Color(1.0, 0.48, 0.045,
			(0.16 if finisher else 0.36) * tracked_trail_scale),
		2.80 if finisher else 2.40, 44)
	_band_core = _new_layer("KickTrailBandCore", BAND_CORE_SHADER, TRAIL_BRIGHT,
		Color(1.0, 0.80, 0.16,
			(0.38 if finisher else 0.66) * tracked_trail_scale),
		4.20 if finisher else 3.50, 45)
	_bright = _new_layer("KickTrailBright", BRIGHT_SHADER, TRAIL_BRIGHT,
		Color(1.0, 0.86, 0.30,
			(0.40 if finisher else 0.72) * tracked_trail_scale),
		3.60 if finisher else 2.80, 46)
	_core = _new_layer("KickTrailCore", BRIGHT_SHADER, TRAIL_BRIGHT,
		Color(1.0, 0.99, 0.88,
			(0.34 if finisher else 0.55) * tracked_trail_scale),
		5.0 if finisher else 4.20, 47)
	# The tracked ribbon supplies motion, while this compact rear-facing plume
	# gives the hit one dense silhouette like the punch family. Its hot end is
	# anchored to the live foot; it never appears on a miss.
	# Mirror the accepted punch material stack: painted dark smoke, soft volume,
	# irregular plasma, then a narrow white-gold core. Reusing only the core atlas
	# made the previous kick look like a fan of loose rays.
	# Each kick mirrors a different accepted punch family instead of stamping one
	# picture three times: compact jab fracture, horizontal straight plasma, then
	# the broad hook material aligned to the final kicking leg.
	var plume_smoke_texture := TRAIL_SMOKE
	var plume_volume_texture := TRAIL_VOLUME
	var plume_bright_texture := TRAIL_BRIGHT
	if _technique == &"middle":
		plume_smoke_texture = MIDDLE_PLASMA
		plume_volume_texture = MIDDLE_PLASMA
		plume_bright_texture = MIDDLE_PLASMA
	elif finisher:
		plume_smoke_texture = FINISHER_SMOKE
		plume_volume_texture = FINISHER_VOLUME
		plume_bright_texture = FINISHER_BRIGHT
	_plume_smoke = _new_layer("KickImpactPlumeSmoke", PLUME_SMOKE_SHADER,
		plume_smoke_texture,
		Color(0.052, 0.014, 0.002,
			0.75 if finisher else (0.78 if _technique == &"middle" else 0.70)),
		0.0, 47)
	_plume_aura = _new_layer("KickImpactPlumeAura", PUNCH_STACK_SHADER,
		plume_volume_texture,
		Color(1.0, 0.76, 0.42, 0.40) if finisher \
		else Color(1.0, 0.82, 0.36, 0.30),
		0.84 if finisher else 0.72, 48)
	_plume_bright = _new_layer("KickImpactPlumeBright", PUNCH_STACK_SHADER,
		plume_bright_texture,
		Color(1.05, 0.92, 0.68, 0.82) if finisher \
		else Color(1.0, 0.82, 0.36, 0.88),
		1.38 if finisher else 1.32, 49)
	_plume_core = _new_layer("KickImpactPlumeCore", PUNCH_STACK_SHADER,
		TRAIL_CORE,
		Color(1.0, 0.96, 0.78, 0.18) if finisher \
		else Color(1.0, 0.98, 0.88, 0.12),
		1.35 if finisher else 0.58, 50)
	_set_layer_shader_float(_plume_aura, &"warmth", 0.82)
	_set_layer_shader_float(_plume_bright, &"warmth", 0.88)
	_set_layer_shader_float(_plume_core, &"warmth", 0.24)
	if finisher:
		_lightning_glow = _new_solid_layer("KickTrailLightningGlow",
		Color(1.0, 0.38, 0.010, 0.08), 2.4, 47)
	_lightning_outer = _new_solid_layer("KickTrailLightningOuter",
		Color(1.0, 0.52, 0.025, 0.18) if finisher \
		else Color(1.0, 0.62, 0.11,
			0.05 if _technique == &"middle" else 0.12),
		4.3 if finisher else 2.40, 48)
	_lightning_inner = _new_solid_layer("KickTrailLightningInner",
		Color(1.0, 0.98, 0.72, 0.26) if finisher \
		else Color(1.0, 0.95, 0.66,
			0.07 if _technique == &"middle" else 0.16),
		6.8 if finisher else 3.20, 49)
	if finisher:
		_lightning_branch_glow = _new_solid_layer(
			"KickTrailLightningBranchGlow", Color(1.0, 0.34, 0.008, 0.06),
			2.2, 47)
		_lightning_branch_outer = _new_solid_layer(
			"KickTrailLightningBranchOuter", Color(1.0, 0.48, 0.020, 0.16),
			3.0, 48)
		_lightning_branch_inner = _new_solid_layer(
			"KickTrailLightningBranchInner", Color(1.0, 0.95, 0.60, 0.24),
			4.4, 49)
	_head_glow = _new_layer("KickFootContactGlow", AURA_SHADER, TRAIL_CONTACT,
		Color(1.0, 0.55, 0.055, 0.34), 3.4 if finisher else 2.9, 50)
	_head = _new_layer("KickFootContact", BRIGHT_SHADER, TRAIL_CONTACT,
		Color(1.0, 0.99, 0.88, 0.62), 5.4 if finisher else 4.8, 51)
	_flash_halo = _new_contact_layer("KickFootFlashHalo",
		Color(1.0, 0.60, 0.10, 0.27), 3.5 if finisher else 3.2, 52)
	_flash_core = _new_contact_layer("KickFootFlashCore",
		Color(1.0, 0.97, 0.76, 0.60), 6.8 if finisher else 5.8, 53)
	if finisher:
		# The final kick keeps a compact fixed trail. Its local fracture rays alone
		# widen toward the attacker while the white orb and enemy side stay fixed.
		_set_layer_shader_float(_flash_halo, &"orb_x_scale", 1.20)
		_set_layer_shader_float(_flash_core, &"orb_x_scale", 1.20)
		_set_layer_shader_float(_flash_halo, &"positive_ray_scale", 1.86)
		_set_layer_shader_float(_flash_core, &"positive_ray_scale", 1.86)
		_set_layer_shader_float(_lightning_glow, &"albedo_strength", 0.18)
		_set_layer_shader_float(_lightning_outer, &"albedo_strength", 0.42)
		_set_layer_shader_float(_lightning_inner, &"albedo_strength", 0.72)
		_set_layer_shader_float(
			_lightning_branch_glow, &"albedo_strength", 0.16)
		_set_layer_shader_float(
			_lightning_branch_outer, &"albedo_strength", 0.38)
		_set_layer_shader_float(
			_lightning_branch_inner, &"albedo_strength", 0.66)
		_track_material(_lightning_glow, _outline_materials)
		_track_material(_lightning_outer, _outline_materials)
		_track_material(_lightning_branch_glow, _outline_materials)
		_track_material(_lightning_branch_outer, _outline_materials)
		_track_material(_lightning_inner, _outline_core_materials)
		_track_material(_lightning_branch_inner, _outline_core_materials)
		_track_material(_smoke, _finisher_band_materials)
		_track_material(_aura, _finisher_band_materials)
		_track_material(_band_core, _finisher_band_materials)
		_track_material(_plume_smoke, _finisher_band_materials)
		_track_material(_plume_aura, _finisher_band_materials)
	_mark_contact_material(_plume_bright)
	_mark_contact_material(_plume_core)
	_mark_contact_material(_head_glow)
	_mark_contact_material(_head)
	if finisher:
		# Reference high: the white/yellow outline and broad white trail die with
		# contact, leaving the amber frame and band as the last image.
		_mark_contact_material(_bright)
		_mark_contact_material(_core)
	_foot_light = OmniLight3D.new()
	_foot_light.name = "KickFootLight"
	_foot_light.light_color = Color(1.0, 0.62, 0.16)
	_foot_light.light_energy = 0.0
	_foot_light.omni_range = 1.15 if finisher else 0.95
	_foot_light.omni_attenuation = 1.55
	_foot_light.shadow_enabled = false
	add_child(_foot_light)
	update_path(points)


func update_path(points: PackedVector3Array,
		strike_axis_update: Vector3 = Vector3.ZERO) -> void:
	if points.is_empty():
		return
	if strike_axis_update.length_squared() > 0.000001:
		_strike_axis = strike_axis_update.normalized()
	_latest_position = points[points.size() - 1]
	if _finisher:
		_impact_position = _latest_position
	if points.size() >= 2:
		var direction := points[points.size() - 1] - points[points.size() - 2]
		if direction.length_squared() > 0.000001:
			_latest_direction = direction.normalized()
	if _finisher:
		_update_finisher_band()
		_update_finisher_lightning()
	elif points.size() >= 2:
		var amber_points := _scaled_rear_points(
			points, HIGH_REAR_AMBER_LENGTH_SCALE)
		_smoke.mesh = _build_ribbon(amber_points,
			_width * 1.34 * TRAIL_MASS_SCALE)
		_aura.mesh = _build_ribbon(amber_points,
			_width * 1.68 * TRAIL_MASS_SCALE)
		_band_core.mesh = _build_ribbon(amber_points,
			_width * 0.56 * TRAIL_MASS_SCALE)
		var white_wedge_points := _scaled_rear_points(
			points, HIGH_REAR_WEDGE_LENGTH_SCALE)
		_bright.mesh = _build_ribbon(white_wedge_points,
			_width * 1.08 * TRAIL_MASS_SCALE)
		_core.mesh = _build_ribbon(white_wedge_points,
			_width * 0.46 * TRAIL_MASS_SCALE)
		_lightning_outer.mesh = _build_ribbon(
			_jagged_path(points, _width * 1.72, 1.0),
			_width * 0.075 * TRAIL_MASS_SCALE)
		_lightning_inner.mesh = _build_ribbon(
			_jagged_path(points, _width * 1.18, -1.0),
			_width * 0.045 * TRAIL_MASS_SCALE)
	_update_head()


func _update_finisher_band() -> void:
	var camera := get_viewport().get_camera_3d()
	var normal := -camera.global_basis.z.normalized() if camera != null \
		else Vector3.FORWARD
	var axis := _strike_axis - normal * _strike_axis.dot(normal)
	if axis.length_squared() < 0.000001:
		axis = _impact_direction - normal * _impact_direction.dot(normal)
	if axis.length_squared() < 0.000001:
		axis = camera.global_basis.x if camera != null else Vector3.RIGHT
	axis = axis.normalized()
	var up_axis := normal.cross(axis).normalized()
	if up_axis.dot(Vector3.UP) < 0.0:
		up_axis = -up_axis
	# The reference is an open energy band laid directly over the extended leg.
	# It starts behind the thigh and ends at the live foot; nothing wraps around
	# the enemy side. A shallow arch keeps the band readable without becoming a C.
	var offsets := PackedVector2Array([
		Vector2(-3.15, -0.20),
		Vector2(-2.66, -0.02),
		Vector2(-2.12, 0.14),
		Vector2(-1.52, 0.20),
		Vector2(-1.08, 0.20),
		Vector2(-0.43, 0.09),
		Vector2(0.0, 0.0),
	])
	var path := PackedVector3Array()
	for offset: Vector2 in offsets:
		path.append(_latest_position \
			+ axis * offset.x * _head_size \
			+ up_axis * offset.y * _head_size)
	_impact_position = _latest_position
	_smoke.mesh = _build_ribbon(path, _width * 1.10 * TRAIL_MASS_SCALE)
	_aura.mesh = _build_ribbon(path, _width * 0.85 * TRAIL_MASS_SCALE)
	_band_core.mesh = _build_ribbon(path, _width * 0.48 * TRAIL_MASS_SCALE)
	_bright.mesh = _build_ribbon(path, _width * 0.32 * TRAIL_MASS_SCALE)
	_core.mesh = _build_ribbon(path, _width * 0.12 * TRAIL_MASS_SCALE)


func _scaled_rear_points(points: PackedVector3Array,
		length_scale: float) -> PackedVector3Array:
	if points.is_empty():
		return points
	var anchor := points[points.size() - 1]
	var stretched := PackedVector3Array()
	for point: Vector3 in points:
		var from_anchor := point - anchor
		var adjusted := point
		var rear_distance := from_anchor.dot(_impact_direction)
		if rear_distance < 0.0:
			adjusted = anchor + from_anchor * length_scale
		stretched.append(adjusted)
	return stretched


func follow_endpoint(_position: Vector3,
		_strike_axis_update: Vector3 = Vector3.ZERO) -> void:
	# Kept as a compatibility entry point for callers created before impacts were
	# locked. Moving this node after contact is exactly what made the effect sweep
	# across the screen with the recovering foot, unlike every accepted punch.
	# The configured contact transform is intentionally immutable.
	return


func latest_position() -> Vector3:
	return _latest_position


func set_external_control(enabled: bool) -> void:
	_external_control = enabled


func set_external_opacity(opacity: float) -> void:
	var clamped := clampf(opacity, 0.0, 1.0)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("opacity", clamped)
	for material: ShaderMaterial in _outline_materials:
		material.set_shader_parameter("opacity", clamped)
	for material: ShaderMaterial in _outline_core_materials:
		material.set_shader_parameter("opacity", clamped)
	for material: ShaderMaterial in _finisher_band_materials:
		material.set_shader_parameter("opacity", clamped)
	for material: ShaderMaterial in _contact_materials:
		material.set_shader_parameter("opacity", clamped)
	if _foot_light != null:
		_foot_light.light_energy = _base_light_energy * clamped


func _process(delta: float) -> void:
	if _external_control:
		return
	_elapsed += delta
	var opacity := _opacity_at(_elapsed)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("opacity", opacity)
	if _finisher:
		var outline_opacity := _finisher_outline_opacity_at(_elapsed)
		for material: ShaderMaterial in _outline_materials:
			material.set_shader_parameter("opacity", outline_opacity)
		var outline_core_opacity := _finisher_outline_core_opacity_at(_elapsed)
		for material: ShaderMaterial in _outline_core_materials:
			material.set_shader_parameter("opacity", outline_core_opacity)
		var band_opacity := _finisher_band_opacity_at(_elapsed)
		for material: ShaderMaterial in _finisher_band_materials:
			material.set_shader_parameter("opacity", band_opacity)
	var contact_opacity := _contact_opacity_at(_elapsed)
	for material: ShaderMaterial in _contact_materials:
		material.set_shader_parameter("opacity", contact_opacity)
	if _foot_light != null:
		# Real light sells the initial impact, but must be gone before the foot
		# returns to the floor or it turns into an unrelated orange floor pool.
		var light_fade_start := 0.05 if _light_duration <= 0.14 else 0.075
		var light_life := 1.0 - _smooth_unit((_elapsed - light_fade_start) \
			/ maxf(_light_duration - light_fade_start, 0.001))
		_foot_light.light_energy = _base_light_energy * contact_opacity * light_life
	if _elapsed >= _duration:
		queue_free()


func _opacity_at(time: float) -> float:
	if time < _fade_in_duration:
		return _smooth_unit(time / maxf(_fade_in_duration, 0.001))
	var fade_out_start := _duration - _fade_out_duration
	if time <= fade_out_start:
		return 1.0
	return 1.0 - _smooth_unit((time - fade_out_start) \
		/ maxf(_fade_out_duration, 0.001))


func _smooth_unit(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _contact_opacity_at(time: float) -> float:
	# The compact white contact leads the wider amber glow by roughly one frame.
	# Both still ramp from zero, but the whole contact is over in a short pulse.
	var fade_in := minf(finisher_contact_fade_in_time if _finisher \
		else regular_contact_fade_in_time,
		_contact_duration * 0.36)
	var fade_out_start := minf(finisher_contact_hold_time if _finisher \
		else regular_contact_hold_time,
		_contact_duration * 0.52)
	if time < fade_in:
		return _smooth_unit(time / fade_in)
	if time <= fade_out_start:
		return 1.0
	return 1.0 - _smooth_unit((time - fade_out_start) \
		/ maxf(_contact_duration - fade_out_start, 0.001))


func _finisher_outline_opacity_at(time: float) -> float:
	if time < finisher_outline_fade_in_time:
		return _smooth_unit(time / finisher_outline_fade_in_time)
	if time <= finisher_outline_hold_time:
		return 1.0
	if time <= finisher_outline_dim_time:
		return lerpf(1.0, 0.35, _smooth_unit(
			(time - finisher_outline_hold_time) \
			/ maxf(finisher_outline_dim_time - finisher_outline_hold_time, 0.001)))
	return 0.35 * (1.0 - _smooth_unit((time - finisher_outline_dim_time) \
		/ maxf(_duration - finisher_outline_dim_time, 0.001)))


func _finisher_outline_core_opacity_at(time: float) -> float:
	if time < finisher_core_fade_in_time:
		return _smooth_unit(time / finisher_core_fade_in_time)
	if time <= finisher_core_hold_time:
		return 1.0
	return 1.0 - _smooth_unit((time - finisher_core_hold_time) \
		/ maxf(finisher_core_fade_out_time, 0.001))


func _finisher_band_opacity_at(time: float) -> float:
	if time < finisher_band_fade_in_time:
		return _smooth_unit(time / finisher_band_fade_in_time)
	if time <= finisher_band_hold_time:
		return 1.0
	return 1.0 - _smooth_unit((time - finisher_band_hold_time) \
		/ maxf(finisher_band_fade_out_time, 0.001))


func _new_layer(layer_name: String, shader_code: String, texture: Texture2D,
		tint: Color, energy: float, priority: int) -> MeshInstance3D:
	var shader := Shader.new()
	shader.code = shader_code
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = priority
	material.set_shader_parameter("trail_texture", texture)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("opacity", 0.0)
	if energy > 0.0:
		material.set_shader_parameter("emission_energy", energy)
	_materials.append(material)

	var instance := MeshInstance3D.new()
	instance.name = layer_name
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.material_override = material
	add_child(instance)
	return instance


func _new_solid_layer(layer_name: String, tint: Color, energy: float,
		priority: int) -> MeshInstance3D:
	var shader := Shader.new()
	shader.code = LIGHTNING_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = priority
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("emission_energy", energy)
	material.set_shader_parameter("opacity", 0.0)
	_materials.append(material)
	var instance := MeshInstance3D.new()
	instance.name = layer_name
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.material_override = material
	add_child(instance)
	return instance


func _new_contact_layer(layer_name: String, tint: Color, energy: float,
		priority: int) -> MeshInstance3D:
	var shader := Shader.new()
	shader.code = CONTACT_FLASH_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = priority
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("emission_energy", energy)
	material.set_shader_parameter("opacity", 0.0)
	_materials.append(material)
	_contact_materials.append(material)
	var instance := MeshInstance3D.new()
	instance.name = layer_name
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.material_override = material
	add_child(instance)
	return instance


func _mark_contact_material(layer: MeshInstance3D) -> void:
	if layer != null and layer.material_override is ShaderMaterial:
		_contact_materials.append(layer.material_override as ShaderMaterial)


func _track_material(layer: MeshInstance3D,
		target: Array[ShaderMaterial]) -> void:
	if layer != null and layer.material_override is ShaderMaterial:
		target.append(layer.material_override as ShaderMaterial)


func _set_layer_shader_float(layer: MeshInstance3D, parameter: StringName,
		value: float) -> void:
	if layer != null and layer.material_override is ShaderMaterial:
		(layer.material_override as ShaderMaterial).set_shader_parameter(
			parameter, value)


func _build_ribbon(points: PackedVector3Array, width: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if points.size() < 2:
		return mesh
	var camera := get_viewport().get_camera_3d()
	var normal := -camera.global_basis.z.normalized() if camera != null \
		else Vector3.FORWARD
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var count := points.size()
	var previous_side := Vector3.ZERO
	for index: int in count:
		var before := points[maxi(index - 1, 0)]
		var after := points[mini(index + 1, count - 1)]
		var tangent := after - before
		tangent -= normal * tangent.dot(normal)
		if tangent.length_squared() < 0.000001:
			tangent = camera.global_basis.x if camera != null else Vector3.RIGHT
		tangent = tangent.normalized()
		var side := normal.cross(tangent).normalized()
		# A foot reverses immediately after contact.  Keep the width basis on the
		# same side through that reversal so adjacent vertex pairs cannot swap and
		# turn the strip into a bow-tie.
		if previous_side.length_squared() > 0.0 and side.dot(previous_side) < 0.0:
			side = -side
		previous_side = side
		var ratio := float(index) / float(count - 1)
		var tapered_half_width := width * 0.5 * lerpf(0.38, 1.0,
			pow(ratio, 0.72))
		vertices.append(points[index] + side * tapered_half_width)
		vertices.append(points[index] - side * tapered_half_width)
		uvs.append(Vector2(ratio, 0.0))
		uvs.append(Vector2(ratio, 1.0))
	if count >= 2:
		for index: int in count - 1:
			var base := index * 2
			indices.append_array(PackedInt32Array([
				base, base + 1, base + 2,
				base + 1, base + 3, base + 2,
			]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _jagged_path(points: PackedVector3Array, amplitude: float,
		polarity: float) -> PackedVector3Array:
	var jagged := PackedVector3Array()
	if points.size() < 2:
		return points
	var camera := get_viewport().get_camera_3d()
	var normal := -camera.global_basis.z.normalized() if camera != null \
		else Vector3.FORWARD
	# Four or five large changes of direction read as lightning. Using every
	# 60 Hz foot sample produces a dense wireframe scribble instead.
	var corner_count := mini(points.size(), 6)
	for corner: int in corner_count:
		var ratio := float(corner) / float(corner_count - 1)
		var index := roundi(ratio * float(points.size() - 1))
		var before := points[maxi(index - 1, 0)]
		var after := points[mini(index + 1, points.size() - 1)]
		var tangent := after - before
		tangent -= normal * tangent.dot(normal)
		if tangent.length_squared() < 0.000001:
			tangent = camera.global_basis.x if camera != null else Vector3.RIGHT
		var side := normal.cross(tangent.normalized()).normalized()
		var envelope := sin(ratio * PI)
		var alternating := -1.0 if corner % 2 == 0 else 1.0
		var cadence := 0.64 + 0.36 * sin(float(corner) * 2.31 + polarity)
		var offset := side * amplitude * envelope * alternating * cadence * polarity
		jagged.append(points[index] + offset)
	return jagged


func _update_finisher_lightning() -> void:
	if _lightning_outer == null or _lightning_inner == null:
		return
	var camera := get_viewport().get_camera_3d()
	var normal := -camera.global_basis.z.normalized() if camera != null \
		else Vector3.FORWARD
	var attack_axis := _strike_axis - normal * _strike_axis.dot(normal)
	if attack_axis.length_squared() < 0.000001:
		attack_axis = camera.global_basis.x if camera != null else Vector3.RIGHT
	attack_axis = attack_axis.normalized()
	var up_axis := normal.cross(attack_axis).normalized()
	if up_axis.dot(Vector3.UP) < 0.0:
		up_axis = -up_axis
	# Reference high: two disconnected angular strokes sit behind the attacker.
	# They deliberately stop before the enemy-side C; joining both shapes makes a
	# closed shield around the target instead of a sparse impact after-image.
	var main_offsets := PackedVector2Array([
		Vector2(-2.10, -0.53),
		Vector2(-1.69, -0.31),
		Vector2(-1.82, -0.07),
		Vector2(-1.32, 0.02),
		Vector2(-1.17, 0.23),
		Vector2(-0.72, 0.17),
		Vector2(-0.38, 0.21),
		Vector2(-0.10, 0.25),
		Vector2(0.06, 0.01),
	])
	var outline := PackedVector3Array()
	for offset: Vector2 in main_offsets:
		outline.append(_impact_position \
			+ attack_axis * offset.x * _head_size \
			+ up_axis * offset.y * _head_size)
	_lightning_outer.mesh = _build_ribbon(outline,
		_width * 0.090 * TRAIL_MASS_SCALE)
	_lightning_inner.mesh = _build_ribbon(outline,
		_width * 0.045 * TRAIL_MASS_SCALE)
	if _lightning_glow != null:
		_lightning_glow.mesh = _build_ribbon(outline,
			_width * 0.24 * TRAIL_MASS_SCALE)

	if _lightning_branch_outer != null and _lightning_branch_inner != null:
		var branch_offsets := PackedVector2Array([
			Vector2(-2.76, -0.94),
			Vector2(-2.29, -0.60),
			Vector2(-2.54, -0.30),
			Vector2(-1.99, -0.40),
		])
		var branch := PackedVector3Array()
		for offset: Vector2 in branch_offsets:
			branch.append(_impact_position \
				+ attack_axis * offset.x * _head_size \
				+ up_axis * offset.y * _head_size)
		_lightning_branch_outer.mesh = _build_ribbon(branch,
			_width * 0.078 * TRAIL_MASS_SCALE)
		_lightning_branch_inner.mesh = _build_ribbon(branch,
			_width * 0.038 * TRAIL_MASS_SCALE)
		if _lightning_branch_glow != null:
			_lightning_branch_glow.mesh = _build_ribbon(branch,
				_width * 0.20 * TRAIL_MASS_SCALE)


func _update_head() -> void:
	if _head == null:
		return
	var camera := get_viewport().get_camera_3d()
	var normal := -camera.global_basis.z.normalized() if camera != null \
		else Vector3.FORWARD
	var long_axis := (_strike_axis if _finisher else _impact_direction) \
		- normal * (_strike_axis if _finisher else _impact_direction).dot(normal)
	if long_axis.length_squared() < 0.000001:
		long_axis = camera.global_basis.x if camera != null else Vector3.RIGHT
	long_axis = long_axis.normalized()
	var height_axis := normal.cross(long_axis).normalized()
	var head_basis := Basis(long_axis, height_axis, normal)
	# The contact flash faces the enemy, but the dense plume follows the actual
	# last foot-motion vector. This keeps the knee diagonal, the middle horizontal,
	# and the high sweep attached to the animation instead of reusing one beam.
	var plume_axis := long_axis if _technique in [&"middle", &"high"] else ( \
		_latest_direction - normal * _latest_direction.dot(normal))
	if plume_axis.length_squared() < 0.000001:
		plume_axis = long_axis
	plume_axis = plume_axis.normalized()
	if plume_axis.dot(long_axis) < 0.0:
		plume_axis = -plume_axis
	var plume_height := normal.cross(plume_axis).normalized()
	var plume_basis := Basis(plume_axis, plume_height, normal)
	var middle := _technique == &"middle"
	_update_plume_layer(_plume_smoke, plume_basis,
		Vector2(_head_size * (2.65 if _finisher else (2.30 if middle else 2.15)),
			_head_size * (1.0 if _finisher else (1.0 if middle else 0.82))
			* PLUME_HEIGHT_SCALE))
	_update_plume_layer(_plume_aura, plume_basis,
		Vector2(_head_size * (2.50 if _finisher else (2.30 if middle else 2.08)),
			_head_size * (0.90 if _finisher else (1.0 if middle else 0.74))
			* PLUME_HEIGHT_SCALE))
	_update_plume_layer(_plume_bright, plume_basis,
		Vector2(_head_size * (2.35 if _finisher else (2.20 if middle else 1.90)),
			_head_size * (0.75 if _finisher else (1.05 if middle else 0.56))
			* PLUME_HEIGHT_SCALE))
	_update_plume_layer(_plume_core, plume_basis,
		Vector2(_head_size * (1.90 if _finisher else (1.90 if middle else 1.72)),
			_head_size * (0.22 if _finisher else (0.34 if middle else 0.28))
			* PLUME_HEIGHT_SCALE))
	var contact_width_scale := 0.72 if middle or _finisher else 0.88
	# The straight kick keeps its accepted horizontal reach, but needs more
	# vertical mass to read beside the punch stack while the leg is moving.
	var contact_height_scale := 0.84 if middle else contact_width_scale
	_update_head_layer(_head_glow, head_basis,
		Vector2(_head_size * (1.92 if _finisher else 1.78),
			_head_size * (1.16 if _finisher else 1.34) * CONTACT_HEIGHT_SCALE)
			* Vector2(contact_width_scale, contact_height_scale))
	_update_head_layer(_head, head_basis,
		Vector2(_head_size * (1.38 if _finisher else 1.32),
			_head_size * (0.80 if _finisher else 1.0) * CONTACT_HEIGHT_SCALE)
			* Vector2(contact_width_scale, contact_height_scale))
	_update_flash_layer(_flash_halo, head_basis,
		Vector2(_head_size * (2.52 if _finisher else 2.20),
			_head_size * (1.18 if _finisher else 1.52) * CONTACT_HEIGHT_SCALE)
			* Vector2(contact_width_scale, contact_height_scale))
	_update_flash_layer(_flash_core, head_basis,
		Vector2(_head_size * (1.584 if _finisher else 1.35),
			_head_size * (0.82 if _finisher else 0.96) * CONTACT_HEIGHT_SCALE)
			* Vector2(contact_width_scale, contact_height_scale))
	if _foot_light != null:
		_foot_light.position = _latest_position


func _update_plume_layer(layer: MeshInstance3D, head_basis: Basis,
		size: Vector2) -> void:
	if layer == null:
		return
	var quad := QuadMesh.new()
	quad.size = size
	layer.mesh = quad
	layer.basis = head_basis
	layer.position = _latest_position \
		- head_basis.x * (IMPACT_PLUME_CORE_U - 0.5) * size.x


func _update_head_layer(layer: MeshInstance3D, head_basis: Basis,
		size: Vector2) -> void:
	if layer == null:
		return
	var quad := QuadMesh.new()
	quad.size = size
	layer.mesh = quad
	layer.basis = head_basis
	# The generated contact texture is asymmetric; its white-hot core is at
	# U=0.66.  Anchor that core—not the transparent quad centre—to the foot.
	layer.position = _latest_position \
		- head_basis.x * (CONTACT_CORE_U - 0.5) * size.x


func _update_flash_layer(layer: MeshInstance3D, head_basis: Basis,
		size: Vector2) -> void:
	if layer == null:
		return
	var quad := QuadMesh.new()
	quad.size = size
	layer.mesh = quad
	layer.basis = head_basis
	layer.position = _latest_position
