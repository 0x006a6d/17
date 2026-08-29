class_name ImpactSlash3D
extends Node3D

const KickTrailRibbon := preload("res://fx/kick_trail_ribbon_3d.gd")
const TRACE: Texture2D = preload("res://assets/fx_textures/kenney/trace_06.png")
const FLARE: Texture2D = preload("res://assets/fx_textures/kenney/flare_01.png")
const HOT_STAR: Texture2D = preload("res://assets/fx_textures/kenney/star_01.png")
const IMPACT_PLUME: Texture2D = preload("res://assets/fx_textures/kenney/muzzle_01_rotated.png")
const REFERENCE_IMPACT_PHASE_1: Texture2D = preload(
	"res://assets/fx_textures/generated/jab_lead_plasma_v11.png")
const JAB_LEAD_CORE_GLOW: Texture2D = preload(
	"res://assets/fx_textures/generated/reference_impact_phase_1_alpha.png")
const REFERENCE_IMPACT_PHASE_2_LIGHT: Texture2D = preload(
	"res://assets/fx_textures/generated/reference_impact_phase_2_light.png")
const REFERENCE_IMPACT_PHASE_2_DARK: Texture2D = preload(
	"res://assets/fx_textures/generated/reference_impact_phase_2_dark.png")
const JAB_CONTACT_BRIGHT: Texture2D = preload(
	"res://assets/fx_textures/generated/jab_contact_bright_v5.png")
const JAB_CONTACT_GAS: Texture2D = preload(
	"res://assets/fx_textures/generated/jab_contact_gas_v6.png")
const JAB_CONTACT_SMOKE: Texture2D = preload(
	"res://assets/fx_textures/generated/jab_contact_smoke_v6.png")
const JAB_CONTACT_SHADOW: Texture2D = preload(
	"res://assets/fx_textures/generated/reference_impact_phase_2_dark.png")
const RIGHT_STRAIGHT_TRAIL_BRIGHT: Texture2D = preload(
	"res://assets/fx_textures/generated/right_straight_trail_plasma_v14_alpha.png")
const RIGHT_STRAIGHT_TRAIL_CORE: Texture2D = preload(
	"res://assets/fx_textures/generated/right_straight_trail_core_v10.png")
const RIGHT_STRAIGHT_TRAIL_VOLUME: Texture2D = preload(
	"res://assets/fx_textures/generated/right_straight_trail_volume_v12.png")
const RIGHT_STRAIGHT_TRAIL_SMOKE: Texture2D = preload(
	"res://assets/fx_textures/generated/right_straight_trail_smoke_v7.png")
const RIGHT_STRAIGHT_CONTACT: Texture2D = preload(
	"res://assets/fx_textures/generated/right_straight_contact_v4.png")
const LEFT_HOOK_CONTACT_BRIGHT: Texture2D = preload(
	"res://assets/fx_textures/generated/left_hook_contact_plasma_v18_alpha.png")
const LEFT_HOOK_CONTACT_VOLUME: Texture2D = preload(
	"res://assets/fx_textures/generated/left_hook_contact_volume_v17.png")
const LEFT_HOOK_CONTACT_SMOKE: Texture2D = preload(
	"res://assets/fx_textures/generated/left_hook_contact_smoke_v14.png")
const LEFT_HOOK_CONTACT_CORE: Texture2D = preload(
	"res://assets/fx_textures/generated/right_straight_contact_v4.png")
const LEFT_HOOK_FOLLOW_BRIGHT: Texture2D = preload(
	"res://assets/fx_textures/generated/left_hook_contact_plasma_v18_alpha.png")
const LEFT_HOOK_FOLLOW_SMOKE: Texture2D = preload(
	"res://assets/fx_textures/generated/left_hook_follow_smoke_v12.png")
const LEFT_HOOK_FOLLOW_CORE: Texture2D = preload(
	"res://assets/fx_textures/generated/right_straight_contact_v4.png")
const HOOK_PENETRATION_CORE: Texture2D = preload(
	"res://assets/fx_textures/generated/hook_penetration_core_white_v17.png")
const BRUSH_STREAKS: Array[Texture2D] = [
	preload("res://assets/fx_textures/kenney/flame_05.png"),
	preload("res://assets/fx_textures/kenney/flame_06.png"),
]
## 自作生成スプライト（SDXL/ComfyUI、黒背景→輝度アルファ化）。質感の主役。
const FLAMES: Array[Texture2D] = [preload("res://assets/fx_textures/generated/flame_a.png"), preload("res://assets/fx_textures/generated/flame_b.png"), preload("res://assets/fx_textures/generated/flame_c.png")]
const GEN_STARS: Array[Texture2D] = [preload("res://assets/fx_textures/generated/star_a.png"), preload("res://assets/fx_textures/generated/star_b.png")]
const GEN_GLOWS: Array[Texture2D] = [preload("res://assets/fx_textures/generated/glow_a.png"), preload("res://assets/fx_textures/generated/glow_b.png")]
const GEN_LANCES: Array[Texture2D] = [preload("res://assets/fx_textures/generated/lance_a.png"), preload("res://assets/fx_textures/generated/lance_b.png")]
const GEN_CRESCENT: Texture2D = preload("res://assets/fx_textures/generated/crescent.png")
const RGB_GLITCH_SHADER := "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear; uniform float offset_px = 6.0; uniform vec2 viewport_size = vec2(1152.0, 648.0); void fragment() { vec2 s=vec2(offset_px/viewport_size.x,0.0); COLOR=vec4(texture(screen_texture,SCREEN_UV+s).r,texture(screen_texture,SCREEN_UV).g,texture(screen_texture,SCREEN_UV-s).b,1.0); }"
const STRAIGHT_TRAIL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D trail_texture : source_color;
uniform float warmth : hint_range(0.0, 1.0) = 0.25;
uniform vec4 frame_tint : source_color = vec4(0.89, 0.84, 0.96, 0.97);
uniform float emission_energy : hint_range(0.0, 2.0) = 1.20;

void fragment() {
	vec4 tex = texture(trail_texture, UV);
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 ivory = vec3(luminance) * vec3(1.0, 0.985, 0.93);
	vec3 colored = mix(ivory, tex.rgb, warmth) * frame_tint.rgb;
	float highlight = smoothstep(0.50, 0.90, luminance);
	// Keep the generated plasma's internal density visible instead of clipping
	// the whole fan into a flat white cel shape.
	ALBEDO = colored * 0.58;
	EMISSION = colored * emission_energy * mix(0.55, 1.25, highlight);
	ALPHA = tex.a * frame_tint.a;
}
"""
const SLASH_BAND_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;
uniform float phase = 1.0;

float lens_shape(vec2 uv, float center, float half_width, float start_x,
		float end_x, float bend) {
	float t = clamp((uv.x - start_x) / max(end_x - start_x, 0.001), 0.0, 1.0);
	float envelope = pow(max(sin(t * 3.14159265), 0.0), 0.48);
	envelope *= mix(0.78, 1.05, smoothstep(0.0, 0.58, t));
	envelope *= 0.90 + 0.10 * sin(t * 11.0 + center * 9.0);
	float center_y = center + bend * sin(t * 3.14159265)
		+ bend * 0.32 * sin(t * 6.2831853 + 1.1);
	float distance_y = abs(uv.y - center_y);
	float normalized_distance = distance_y / max(half_width * envelope, 0.001);
	float field = pow(clamp(1.0 - normalized_distance, 0.0, 1.0), 0.72);
	float feather = min(0.035, (end_x - start_x) * 0.22);
	float range_mask = smoothstep(start_x, start_x + feather, uv.x)
		* (1.0 - smoothstep(end_x - feather, end_x, uv.x));
	return field * range_mask;
}

void fragment() {
	vec2 uv = UV;
	float main_body;
	float inner_core;
	float broad_glow;
	if (phase < 1.5) {
		main_body = lens_shape(uv, 0.50, 0.235, 0.01, 0.995, 0.012);
		float upper_accent = lens_shape(uv, 0.62, 0.040, 0.18, 0.91, 0.026);
		float lower_accent = lens_shape(uv, 0.39, 0.050, 0.02, 0.82, -0.032);
		main_body = max(main_body, max(upper_accent, lower_accent));
		inner_core = lens_shape(uv, 0.50, 0.125, 0.04, 0.98, 0.006);
		broad_glow = lens_shape(uv, 0.50, 0.365, 0.0, 1.0, 0.012);
	} else {
		float lower = lens_shape(uv, 0.31, 0.082, 0.01, 0.99, -0.025);
		float middle = lens_shape(uv, 0.51, 0.108, 0.07, 0.995, 0.006);
		float upper = lens_shape(uv, 0.71, 0.074, 0.16, 0.98, 0.028);
		float needle = lens_shape(uv, 0.19, 0.028, 0.22, 0.93, -0.018);
		main_body = max(max(lower, middle), max(upper, needle));
		float lower_core = lens_shape(uv, 0.31, 0.058, 0.04, 0.96, -0.025);
		float middle_core = lens_shape(uv, 0.51, 0.074, 0.10, 0.98, 0.006);
		float upper_core = lens_shape(uv, 0.71, 0.050, 0.19, 0.95, 0.028);
		inner_core = max(lower_core, max(middle_core, upper_core));
		float glow_lower = lens_shape(uv, 0.31, 0.135, 0.0, 1.0, -0.025);
		float glow_middle = lens_shape(uv, 0.51, 0.175, 0.04, 1.0, 0.006);
		float glow_upper = lens_shape(uv, 0.71, 0.125, 0.12, 1.0, 0.028);
		broad_glow = max(glow_lower, max(glow_middle, glow_upper));
	}
	vec3 orange = vec3(1.0, 0.20, 0.008);
	vec3 gold = vec3(1.0, 0.62, 0.025);
	vec3 cream = vec3(1.0, 0.97, 0.68);
	vec3 color = mix(orange, gold, clamp(main_body, 0.0, 1.0));
	color = mix(color, cream, clamp(main_body * 0.10 + inner_core, 0.0, 1.0));
	float alpha = max(broad_glow * 0.34, max(main_body, inner_core));
	ALBEDO = color;
	EMISSION = color * (1.8 + inner_core * 9.2 + main_body * 2.0);
	ALPHA = alpha;
}
"""
const SLASH_SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled;
uniform float phase = 1.0;

float shadow_lens(vec2 uv, float center, float half_width, float start_x,
		float end_x, float bend) {
	float t = clamp((uv.x - start_x) / max(end_x - start_x, 0.001), 0.0, 1.0);
	float envelope = pow(max(sin(t * 3.14159265), 0.0), 0.45);
	float center_y = center + bend * sin(t * 3.14159265);
	float normalized_distance = abs(uv.y - center_y)
		/ max(half_width * envelope, 0.001);
	float field = pow(clamp(1.0 - normalized_distance, 0.0, 1.0), 1.25);
	float mask = smoothstep(start_x, start_x + 0.04, uv.x)
		* (1.0 - smoothstep(end_x - 0.04, end_x, uv.x));
	return field * mask;
}

void fragment() {
	vec2 uv = UV;
	float shadow;
	float strength;
	if (phase < 1.5) {
		shadow = shadow_lens(uv, 0.46, 0.22, 0.0, 0.98, -0.025);
		strength = 0.10;
	} else {
		float lower = shadow_lens(uv, 0.27, 0.105, 0.0, 0.94, -0.035);
		float middle = shadow_lens(uv, 0.47, 0.135, 0.02, 0.97, -0.010);
		float upper = shadow_lens(uv, 0.67, 0.095, 0.12, 0.94, 0.020);
		shadow = max(lower, max(middle, upper));
		strength = 0.30;
	}
	float tail_weight = mix(1.0, 0.18, smoothstep(0.12, 0.92, uv.x));
	ALBEDO = vec3(0.055, 0.020, 0.006);
	ALPHA = shadow * strength * tail_weight;
}
"""

@export var melee_path: NodePath = ^"../PlayerMelee"
@export var hitbox_path: NodePath = ^"../Model/MeleeHitbox"
@export_group("Stage 1 Spear and Reverse Fan")
@export var spear_length: float = 1.90
@export var spear_tip_extension: float = 0.60
@export var spear_width: float = 0.30
@export var spear_white_core_width: float = 1.60
@export var spear_gold_width: float = 3.00
@export var spear_orange_width: float = 3.30
@export var spear_duration: float = 0.16
@export var spear_emission_energy: float = 10.0
@export var fan_tongue_count: int = 8
@export var fan_spread_degrees: float = 30.0
@export var fan_duration: float = 4.0 / 30.0
@export var fan_length: Vector2 = Vector2(0.72, 1.05)
@export var fan_width: Vector2 = Vector2(0.45, 0.60)
@export var fan_contact_glow_size: float = 0.85
@export_group("Stage 2 Three Phase")
@export var star_diameter: float = 1.05
@export var star_frames: int = 1
@export var orange_glow_diameter: float = 0.88
@export var orange_glow_frames: int = 2
@export var jagged_flame_diameter: float = 0.92
@export var jagged_flame_frames: int = 2
@export var star_contact_glow_size: float = 0.90
@export_group("Reference Impact")
## 参照映像の核になる、接触点の短い白熱星と攻撃方向へ伸びる金色の打撃筋。
@export_range(0.1, 1.0, 0.05) var later_hit_vertical_scale: float = 1.00
@export var impact_core_diameter: float = 0.62
@export var impact_duration: float = 3.0 / 30.0
@export var impact_smear_length: float = 2.35
@export var impact_smear_width: float = 2.80
@export var impact_plume_size: Vector2 = Vector2(1.08, 0.54)
@export_range(0.0, 1.0) var impact_plume_anchor: float = 0.23
@export var impact_fan_count: int = 8
@export var impact_fan_spread_degrees: float = 7.0
@export var impact_fan_length: Vector2 = Vector2(0.45, 1.05)
@export var impact_fan_width: Vector2 = Vector2(0.22, 0.42)
@export var impact_fan_lane_span: float = 0.34
@export_range(0.05, 0.45, 0.01) var impact_fade_in_ratio: float = 0.42
@export_range(0.0, 0.45, 0.01) var impact_peak_hold_ratio: float = 0.12
## 蹴りとの視覚的な強さを揃える。形状や暗部は保ち、パンチの発光だけを抑える。
@export_range(0.5, 1.0, 0.01) var punch_emission_scale: float = 0.88
## フックは面積が広いため、共通スケール後にもう一段だけ光量を抑える。
@export_range(0.5, 1.0, 0.01) var hook_emission_scale: float = 0.82
@export var jab_frame_interval: float = 2.5 / 30.0
@export var jab_frame_duration: float = 3.0 / 30.0
@export var jab_lead_tint: Color = Color(1.0, 0.98, 0.86, 0.92)
@export_range(0.0, 2.0, 0.01) var jab_lead_emission: float = 0.68
@export var jab_lead_tip_size: Vector2 = Vector2(0.72, 0.20)
@export var jab_lead_tip_vertical_offset: float = 0.045
@export var jab_lead_tip_penetration: float = -0.02
@export var jab_contact_tint: Color = Color(1.0, 0.97, 0.62, 0.95)
@export_range(0.0, 2.0, 0.01) var jab_contact_emission: float = 1.15
@export var jab_contact_length: float = 1.72
@export var jab_contact_size: Vector2 = Vector2(1.72, 1.05)
@export_range(0.5, 0.95, 0.01) var jab_contact_core_u: float = 0.83
@export var jab_contact_burst_size: Vector2 = Vector2(0.68, 0.68)
@export var straight_frame_interval: float = 2.0 / 30.0
@export var straight_frame_duration: float = 4.0 / 30.0
@export var straight_trail_size: Vector2 = Vector2(1.68, 0.73)
@export_range(0.55, 0.85, 0.01) var straight_trail_contact_u: float = 0.76
@export_range(0.0, 1.0, 0.01) var straight_frame_3_warmth: float = 0.00
@export_range(0.0, 1.0, 0.01) var straight_frame_4_warmth: float = 0.88
@export var straight_frame_3_tint: Color = Color(1.0, 0.98, 0.88, 0.98)
@export var straight_frame_4_tint: Color = Color(1.0, 0.82, 0.36, 1.0)
@export_range(0.0, 2.0, 0.01) var straight_frame_3_emission: float = 1.95
@export_range(0.0, 2.0, 0.01) var straight_frame_4_emission: float = 1.45
@export var straight_contact_duration: float = 3.25 / 30.0
@export var straight_contact_size: Vector2 = Vector2(0.74, 0.74)
@export_range(0.45, 0.75, 0.01) var straight_contact_core_u: float = 0.66
@export var hook_follow_interval: float = 3.0 / 30.0
@export var hook_contact_duration: float = 3.5 / 30.0
@export var hook_follow_duration: float = 4.0 / 30.0
@export var hook_contact_size: Vector2 = Vector2(2.20, 1.42)
@export var hook_follow_size: Vector2 = Vector2(2.70, 0.68)
@export_range(0.5, 0.9, 0.01) var hook_contact_core_u: float = 0.83
@export_range(0.5, 0.9, 0.01) var hook_follow_core_u: float = 0.82
@export var hook_contact_surface_core_ratio: Vector2 = Vector2(1.15, 0.30)
@export var hook_follow_surface_core_ratio: Vector2 = Vector2(1.20, 0.20)
## 左フックの接触を敵の胴の中心から下げる量。大きいと腰より下に出て、
## どこに当たったか読めなくなる。
@export_range(0.0, 0.4, 0.01) var hook_contact_lower_ratio: float = 0.0
@export_range(0.0, 0.4, 0.01) var hook_follow_lower_ratio: float = 0.0
@export_range(0.0, 0.3, 0.01) var hook_depth_ratio: float = 0.08
@export_group("Kick Foot Trail")
## 空振りでは描画せず、段開始からこの数だけ脚ボーン位置を記録する。
@export_range(6, 24, 1) var kick_trail_max_samples: int = 12
## 命中時に可視化する末尾サンプル数。蹴り上げ開始の縦線を残さない。
@export_range(4, 12, 1) var kick_trail_visible_samples: int = 9
@export_range(5, 12, 1) var kick_side_arc_samples: int = 8
@export_range(0.3, 1.0, 0.01) var kick_side_arc_length: float = 0.64
@export_range(0.08, 0.5, 0.01) var kick_side_arc_drop: float = 0.26
@export_range(0.001, 0.08, 0.001) var kick_trail_min_sample_distance: float = 0.012
@export_range(0.08, 0.5, 0.01) var kick_trail_duration: float = 0.18
@export_range(0.04, 0.3, 0.01) var kick_trail_follow_duration: float = 0.15
@export_range(0.08, 0.5, 0.01) var kick_trail_width: float = 0.30
@export_range(0.10, 0.8, 0.01) var kick_contact_size: float = 0.62
## 足軌道・太さ・接触光・敵側C字を一緒に拡縮する。
@export_range(1.0, 1.5, 0.01) var kick_vfx_scale: float = 1.18
@export_range(0.0, 1.0, 0.05) var kick_toe_anchor_ratio: float = 0.90
@export_group("Stage 3 Swish and Lightning")
@export var swish_radius: float = 0.82
@export var swish_width: float = 0.22
@export var swish_segments: int = 7
@export var swish_duration: float = 0.28
@export var lightning_line_count: int = 2
@export var lightning_segment_count: int = 4
@export var lightning_radius: float = 0.85
@export var lightning_width: Vector2 = Vector2(0.014, 0.032)
@export var lightning_duration: float = 4.0 / 30.0
@export var finisher_arc_diameter: float = 1.42
@export var finisher_arc_duration: float = 4.0 / 30.0
@export_group("Shared Embers")
@export var ember_amount: int = 12
@export var finisher_ember_amount: int = 20
@export var ember_lifetime: float = 0.14
@export var ember_randomness: float = 0.40
@export var ember_spread_degrees: float = 50.0
@export var ember_velocity: Vector2 = Vector2(7.0, 11.0)
@export var finisher_ember_velocity: Vector2 = Vector2(7.0, 10.0)
@export var ember_damping: Vector2 = Vector2(20.0, 28.0)
@export var ember_gravity: Vector3 = Vector3(0.0, -3.0, 0.0)
@export var ember_scale: Vector2 = Vector2(0.8, 1.2)
@export var ember_quad_size: Vector2 = Vector2(0.018, 0.16)
@export var ember_emission_energy: float = 8.0
@export var lingering_ember_amount: int = 4
@export var lingering_ember_lifetime: float = 0.16
@export var lingering_ember_velocity: Vector2 = Vector2(0.45, 1.25)
@export var lingering_ember_quad_size: Vector2 = Vector2(0.075, 0.075)
@export_group("Palette and Timing")
@export var white_color: Color = Color("fff8e0")
@export var cream_color: Color = Color("ffe9ae")
@export var gold_color: Color = Color("ffd23e")
@export var orange_color: Color = Color("ff9524")
@export var phase_fps: float = 30.0
@export var flame_frame_interval: float = 1.0 / 30.0
@export_group("Finisher Screen FX")
@export var finisher_techniques: Array[StringName] = [&"hook", &"high"]
## 参照映像は接触点だけが白熱し、画面全体は変色しない。必要な場合だけ有効化する。
@export var finisher_screen_fx_enabled: bool = false
@export var screen_flash_alpha: float = 0.08
@export var screen_flash_duration: float = 0.085
@export var glitch_offset_pixels: float = 6.0
@export var glitch_duration: float = 0.075

signal slash_spawned(technique: StringName, impact_position: Vector3, shape: int)
signal phase_spawned(technique: StringName, phase: StringName)
signal slash_frame_advanced(technique: StringName, frame: int)

var _melee: Node
var _hitbox: Hitbox
var _technique: StringName = &"jab"
var _rng := RandomNumberGenerator.new()
var _previews: Array[Node3D] = []
var _kick_skeleton: Skeleton3D = null
var _kick_anchor_bone: int = -1
var _kick_toe_bone: int = -1
var _kick_limb_bone: int = -1
var _kick_anchor_bone_name: StringName = &""
var _kick_samples := PackedVector3Array()
var _kick_tracking: bool = false
var _kick_visible: bool = false
var _kick_follow_time_left: float = 0.0
var _kick_trail: Node3D = null

func _ready() -> void:
	_rng.randomize()
	_melee = get_node_or_null(melee_path)
	_hitbox = get_node_or_null(hitbox_path) as Hitbox
	_resolve_kick_skeleton()
	if _melee != null and _melee.has_signal("stage_started"):
		_melee.connect("stage_started", _on_stage_started)
	if _melee != null and _melee.has_signal("combo_finished"):
		_melee.connect("combo_finished", _on_combo_ended)
	if _melee != null and _melee.has_signal("combo_interrupted"):
		_melee.connect("combo_interrupted", _on_combo_ended)
	if _hitbox != null:
		_hitbox.impact_landed.connect(_on_impact_landed)

func _on_stage_started(technique: StringName, _stage: int) -> void:
	_technique = technique
	_clear_previews()
	_reset_kick_tracking()
	if _is_kick_technique(technique):
		_begin_kick_tracking(technique)
	# 攻撃開始時には何も出さない。全VFXは Hurtbox の命中イベントからだけ出す。

func _on_impact_landed(target: Node3D, position: Vector3) -> void:
	if not _is_kick_technique(_technique) or not _kick_visible:
		_clear_previews()
	var direction := _attack_direction(target)
	var effect_position := position
	match _technique:
		&"jab":
			_spawn_jab_hit_sequence(position, direction)
		&"straight":
			_spawn_straight_hit(position, direction)
		&"hook":
			_spawn_hook_hit(target, position, direction)
		&"knee", &"middle", &"high":
			effect_position = _spawn_kick_hit(position, direction)
		_:
			_spawn_reference_impact(position, direction,
				finisher_techniques.has(_technique))
			phase_spawned.emit(_technique, &"contact")
	_spawn_embers(effect_position,
		-direction if _combo_kind(_technique) == 1 else direction,
		finisher_techniques.has(_technique))
	_spawn_lingering_embers(effect_position, direction,
		finisher_techniques.has(_technique))
	if finisher_screen_fx_enabled and finisher_techniques.has(_technique):
		_spawn_finisher_screen_fx()
	slash_spawned.emit(_technique, position, _shape_for(_technique))


func _physics_process(delta: float) -> void:
	if not _kick_tracking:
		return
	var anchor := _kick_anchor_position(global_position + Vector3.UP * 0.8)
	if _kick_visible and is_instance_valid(_kick_trail):
		# A landed kick is an impact, not a glow stuck to the returning foot.
		# Configure the art from the live bone at contact, then keep that world-space
		# silhouette fixed exactly like the accepted punch effects.
		_kick_follow_time_left = 0.0
		_kick_tracking = false
	else:
		_append_kick_sample(anchor)

func _combo_kind(technique: StringName) -> int:
	if technique == &"jab" or technique == &"knee": return 1
	if technique == &"straight" or technique == &"middle": return 2
	return 3


func _is_kick_technique(technique: StringName) -> bool:
	return technique == &"knee" or technique == &"middle" \
		or technique == &"high"


func _resolve_kick_skeleton() -> void:
	if is_instance_valid(_kick_skeleton):
		return
	var model := get_node_or_null(^"../Model")
	_kick_skeleton = _find_skeleton(model)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node == null:
		return null
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _begin_kick_tracking(technique: StringName) -> void:
	_resolve_kick_skeleton()
	_kick_anchor_bone = -1
	_kick_toe_bone = -1
	_kick_limb_bone = -1
	# The first strike is a knee, so keep its contact art on the striking knee.
	# Middle/high remain attached to the moving foot and toe chain.
	_kick_anchor_bone_name = &"RightLowerLeg" if technique == &"knee" \
		else &"RightFoot"
	if _kick_skeleton != null:
		_kick_anchor_bone = _kick_skeleton.find_bone(_kick_anchor_bone_name)
		if technique != &"knee":
			_kick_toe_bone = _kick_skeleton.find_bone(&"RightToes")
			_kick_limb_bone = _kick_skeleton.find_bone(&"RightLowerLeg")
	_kick_tracking = _kick_anchor_bone >= 0
	if _kick_tracking:
		_append_kick_sample(_kick_anchor_position(global_position + Vector3.UP))


func _reset_kick_tracking() -> void:
	_kick_samples.clear()
	_kick_anchor_bone = -1
	_kick_toe_bone = -1
	_kick_limb_bone = -1
	_kick_anchor_bone_name = &""
	_kick_tracking = false
	_kick_visible = false
	_kick_follow_time_left = 0.0
	_kick_trail = null


func _on_combo_ended() -> void:
	_kick_tracking = false
	# Keep the tiny hidden history until the next stage resets it. High kick's
	# combo-out and hitbox-close times differ by only ~1.5 ms, so an Area3D
	# impact can arrive one physics tick after combo_finished. Clearing here
	# would replace the real foot arc with the fallback straight segment.


func _kick_anchor_position(fallback: Vector3) -> Vector3:
	if _kick_skeleton == null or _kick_anchor_bone < 0:
		return fallback
	var anchor := (_kick_skeleton.global_transform \
		* _kick_skeleton.get_bone_global_pose(_kick_anchor_bone)).origin
	if _kick_toe_bone >= 0:
		var toe := (_kick_skeleton.global_transform \
			* _kick_skeleton.get_bone_global_pose(_kick_toe_bone)).origin
		anchor = anchor.lerp(toe, kick_toe_anchor_ratio)
	return anchor


func _kick_limb_axis(fallback: Vector3) -> Vector3:
	if _kick_skeleton == null or _kick_limb_bone < 0:
		return fallback.normalized() if fallback.length_squared() > 0.000001 \
			else Vector3.RIGHT
	var limb_origin := (_kick_skeleton.global_transform \
		* _kick_skeleton.get_bone_global_pose(_kick_limb_bone)).origin
	var foot := _kick_anchor_position(limb_origin + fallback)
	var axis := foot - limb_origin
	if axis.length_squared() < 0.000001:
		return fallback.normalized() if fallback.length_squared() > 0.000001 \
			else Vector3.RIGHT
	return axis.normalized()


func _append_kick_sample(position: Vector3) -> void:
	if _kick_samples.is_empty():
		_kick_samples.append(position)
		return
	var last_index := _kick_samples.size() - 1
	if _kick_samples[last_index].distance_to(position) < kick_trail_min_sample_distance:
		# Before contact, keep the last accepted sample fixed so several sub-
		# threshold moves accumulate into a real segment. Once visible, replace
		# only the live endpoint to keep the white-hot core attached to the foot.
		if _kick_visible:
			_kick_samples[last_index] = position
		return
	_kick_samples.append(position)
	while _kick_samples.size() > kick_trail_max_samples:
		_kick_samples.remove_at(0)


func _spawn_kick_hit(fallback_position: Vector3,
		direction: Vector3) -> Vector3:
	if _kick_anchor_bone_name == &"":
		_begin_kick_tracking(_technique)
	var anchor := _kick_anchor_position(fallback_position)
	_append_kick_sample(anchor)
	if not _kick_samples.is_empty():
		# Contact uses the exact current bone position even when the last move was
		# shorter than the history sampling threshold.
		_kick_samples[_kick_samples.size() - 1] = anchor
	if _kick_visible and is_instance_valid(_kick_trail):
		return anchor
	# 直接テストやSkeleton欠損でも板を固定命中点へ置かず、攻撃方向の短い
	# 軌道へ退避する。実プレイでは段開始から記録済みの実ボーン列を使う。
	if _kick_samples.size() < 2 \
			or _kick_path_length(_kick_samples) < kick_trail_min_sample_distance * 2.0:
		var history_offset := -direction.normalized() * 0.42
		history_offset += Vector3.DOWN * (0.24 if _technique == &"knee" else 0.12)
		_kick_samples.insert(0, anchor + history_offset)
	_trim_kick_samples_for_contact(direction)
	_shape_kick_samples_for_side_view(direction)

	var technique_scale := 0.88 if _technique == &"knee" \
		else (1.16 if _technique == &"high" else 1.0)
	var scale := technique_scale * kick_vfx_scale
	# Every landed kick uses the same brief on-screen window. The finisher keeps
	# its larger silhouette, but no longer leaves a long amber after-image.
	var trail := KickTrailRibbon.new() as Node3D
	trail.name = "KickFootTrail"
	add_child(trail)
	trail.call("configure", _kick_samples, kick_trail_width * scale,
		kick_contact_size * scale, kick_trail_duration,
		_technique == &"high", direction, _technique != &"high", _technique,
		_kick_limb_axis(direction))
	_previews.append(trail)
	_kick_trail = trail
	_kick_visible = true
	# The bone history determines contact position and direction only. Once the
	# hit is confirmed, the effect stays at that impact while the leg recovers.
	_kick_tracking = false
	_kick_follow_time_left = 0.0
	phase_spawned.emit(_technique, &"kick_foot_trail")
	return anchor


func _kick_path_length(points: PackedVector3Array) -> float:
	var length := 0.0
	for index: int in points.size() - 1:
		length += points[index].distance_to(points[index + 1])
	return length


func _trim_kick_samples_for_contact(direction: Vector3) -> void:
	if _kick_samples.size() <= 2:
		return
	var attack_axis := direction
	attack_axis.y = 0.0
	if attack_axis.length_squared() < 0.000001:
		attack_axis = Vector3.RIGHT
	attack_axis = attack_axis.normalized()
	var last := _kick_samples.size() - 1
	var start := maxi(0, _kick_samples.size() - kick_trail_visible_samples)
	# Discard the older lift section once it becomes substantially more vertical
	# than the forward contact travel. Keep at least four points for a readable
	# curved ribbon and let knee retain its naturally shorter upward hook.
	if _technique != &"knee":
		for index: int in range(last - 1, start - 1, -1):
			var segment := _kick_samples[index + 1] - _kick_samples[index]
			var forward_amount := absf(segment.dot(attack_axis))
			if last - index >= 3 and absf(segment.y) > forward_amount * 1.15:
				start = index + 1
				break
		start = mini(start, maxi(last - 3, 0))
	var trimmed := PackedVector3Array()
	for index: int in range(start, _kick_samples.size()):
		trimmed.append(_kick_samples[index])
	_kick_samples = trimmed


func _shape_kick_samples_for_side_view(direction: Vector3) -> void:
	if _kick_samples.is_empty():
		return
	var attack_axis := direction
	attack_axis.y = 0.0
	if attack_axis.length_squared() < 0.000001:
		attack_axis = Vector3.RIGHT
	attack_axis = attack_axis.normalized()
	var anchor := _kick_samples[_kick_samples.size() - 1]
	var technique_scale := 0.78 if _technique == &"knee" \
		else (1.08 if _technique == &"high" else 1.0)
	var horizontal_span := 0.0
	for point: Vector3 in _kick_samples:
		horizontal_span = maxf(horizontal_span,
			absf((anchor - point).dot(attack_axis)))
	var arc_length := clampf(maxf(horizontal_span, kick_side_arc_length),
		0.42, 0.82) * technique_scale * kick_vfx_scale
	var arc_drop := kick_side_arc_drop * technique_scale * kick_vfx_scale
	var side_arc := PackedVector3Array()
	for index: int in kick_side_arc_samples:
		var ratio := float(index) / float(kick_side_arc_samples - 1)
		var angle := (1.0 - ratio) * PI * 0.5
		var point := anchor - attack_axis * arc_length * sin(angle)
		point.y -= arc_drop * sin(angle)
		# The QC/requested shape is the side silhouette. Keep the stylized contact
		# arc in the attack plane while its head remains the real foot position.
		point.z = anchor.z
		side_arc.append(point)
	_kick_samples = side_arc


func kick_tracking_bone_name() -> StringName:
	return _kick_anchor_bone_name


func kick_sample_count() -> int:
	return _kick_samples.size()


func kick_trail_endpoint() -> Vector3:
	if is_instance_valid(_kick_trail):
		var endpoint: Vector3 = _kick_trail.call("latest_position")
		return endpoint
	return Vector3.ZERO

func _spawn_spear_preview(technique: StringName) -> void:
	var direction := _nearest_target_direction()
	var total_length := spear_length + spear_tip_extension
	# 参照1枚目から背景と人物を除いた、単一の柔らかい横長スミア。
	var lance := _sprite(REFERENCE_IMPACT_PHASE_1,
		Vector2(total_length, total_length * 0.38),
		Color.WHITE, 1.05, 29)
	lance.name = "Stage1Spear"
	lance.top_level = true
	# 先端を約0.85m先の対象表面へ置き、残りを攻撃者の背後へ伸ばす。
	lance.global_position = _preview_origin() \
		+ direction * (0.85 - total_length * 0.5)
	_orient_quad_horizontal(lance, direction)
	_previews.append(lance)
	var tween := lance.create_tween().set_parallel(true)
	tween.tween_property(lance, "scale", Vector3(1.05, 1.04, 1.0), spear_duration)
	tween.tween_property(lance, "transparency", 1.0, spear_duration)
	tween.chain().tween_callback(func() -> void: _forget_preview(lance))
	phase_spawned.emit(technique, &"spear")

func _spawn_swish_preview(technique: StringName) -> void:
	var camera := get_viewport().get_camera_3d()
	var origin := global_position + Vector3.UP * 0.82 + _nearest_target_direction() * 0.30
	var right := camera.global_basis.x.normalized() if camera != null else Vector3.RIGHT
	var up := camera.global_basis.y.normalized() if camera != null else Vector3.UP
	# 生成した三日月スプライト1枚を、脚の軌道に合わせて画面平面上で回して振り抜く。
	var crescent := _sprite(GEN_CRESCENT, Vector2.ONE * swish_radius * 2.1,
		Color(1.42, 0.76, 0.14, 0.90), 6.0, 18)
	crescent.name = "Stage3Swish"
	crescent.top_level = true
	crescent.global_position = origin
	_previews.append(crescent)
	var sweep := crescent.create_tween()
	sweep.tween_method(func(angle: float) -> void:
		if is_instance_valid(crescent):
			_orient_quad(crescent, -right * sin(angle) + up * cos(angle)),
		-1.05, 1.05, swish_duration)
	_fade(crescent, swish_duration, 1.1)
	phase_spawned.emit(technique, &"swish")

func _spawn_reverse_fan(position: Vector3, direction: Vector3) -> void:
	# キック等、4枚のパンチ参照に含まれない技の既定命中演出。
	_spawn_reference_impact(position, direction, false)
	phase_spawned.emit(_technique, &"contact")


func _spawn_jab_hit_sequence(position: Vector3, direction: Vector3) -> void:
	# 参照1→2。各画像を瞬間表示せず、フェードを重ねて連続した一撃にする。
	var attack_direction := direction.normalized()
	var total_length := spear_length + spear_tip_extension
	# 参照1の太さは硬い白帯ではなく、通常合成の暗い熱雲と、その上の
	# 加算白熱芯に分ける。内部密度を残して一枚絵のビーム感を抑える。
	var halo := _mixed_sprite(REFERENCE_IMPACT_PHASE_1,
		Vector2(total_length, total_length * 1.10),
		Color(0.34, 0.16, 0.055, 0.34), 0.0, 28)
	halo.name = "JabLeadHalo"
	halo.top_level = true
	halo.global_position = position - attack_direction * total_length * 0.45
	# 素材の左端が尖った先端。攻撃方向と逆向きのBasisへ貼ることで、
	# 丸い熱雲を攻撃者側、尖った白熱部を命中点側へ向ける。
	_orient_quad_horizontal(halo, -attack_direction)
	_fade(halo, jab_frame_duration, 1.03)
	var lead := _sprite(REFERENCE_IMPACT_PHASE_1,
		Vector2(total_length, total_length * 0.47), jab_lead_tint,
		jab_lead_emission, 29)
	lead.name = "JabLeadSmear"
	lead.top_level = true
	lead.global_position = position - attack_direction * total_length * 0.45
	_orient_quad_horizontal(lead, -attack_direction)
	_fade(lead, jab_frame_duration, 1.03)
	# 低濃度の白い芯だけを別レイヤーで足し、琥珀色の熱膜を白一色に
	# 飛ばさず、中心から外へ光量が落ちる階層を作る。
	var core_glow := _sprite(JAB_LEAD_CORE_GLOW,
		Vector2(total_length, total_length * 0.23),
		Color(1.0, 1.0, 0.98, 0.46), 0.65, 30)
	core_glow.name = "JabLeadCoreGlow"
	core_glow.top_level = true
	core_glow.global_position = lead.global_position
	_orient_quad_horizontal(core_glow, -attack_direction)
	_fade(core_glow, jab_frame_duration * 0.92, 1.02)
	# 参照1の上側先端は本体素材の白熱芯が担う。下側をその熱膜の中へ
	# 密着させ、狭い暗いスリットを挟んで同じ根元から割れる二股にする。
	# 先端位置も上側へ揃え、別の弾が太腿を貫く見え方を避ける。
	var tip_center := position - attack_direction \
		* (jab_lead_tip_size.x * 0.5 - jab_lead_tip_penetration)
	var lower_tip := _sprite(JAB_LEAD_CORE_GLOW,
		Vector2(jab_lead_tip_size.x * 1.05, jab_lead_tip_size.y * 1.55),
		Color(1.14, 1.10, 0.96, 0.94), 1.82, 32)
	lower_tip.name = "JabLeadLowerTip"
	lower_tip.top_level = true
	lower_tip.global_position = tip_center \
		- Vector3.UP * jab_lead_tip_vertical_offset
	_orient_quad_horizontal(lower_tip, -attack_direction)
	_fade(lower_tip, jab_frame_duration * 0.88, 1.04)
	phase_spawned.emit(_technique, &"jab_frame_1")
	_spawn_jab_contact_later(position, attack_direction, _technique)


func _spawn_jab_contact_later(position: Vector3, direction: Vector3,
		technique: StringName) -> void:
	await get_tree().create_timer(jab_frame_interval).timeout
	if not is_inside_tree() or _technique != technique:
		return
	# 参照2: 暗い尾と内部カットを持つ接触稲妻へ進む。汎用の円形
	# FLARE/HOT_STAR は足さず、素材内の非対称な稲妻だけを残す。
	_spawn_jab_contact_impact(position, direction)
	phase_spawned.emit(technique, &"jab_frame_2")


func _spawn_jab_contact_impact(position: Vector3, direction: Vector3) -> void:
	var attack_direction := direction.normalized()
	var duration := impact_duration
	var layer_position := position \
		- attack_direction * (jab_contact_core_u - 0.5) \
		* jab_contact_size.x
	# 参照2の金色の下を走る黒褐色の速度影。発光素材へ焼き込まず、
	# 通常アルファの独立層にすることで黒を本当に画面へ残す。
	var shadow := _mixed_sprite(JAB_CONTACT_SHADOW,
		Vector2(jab_contact_size.x, jab_contact_size.y * 0.72),
		Color(0.18, 0.09, 0.035, 0.64), 0.0, 35)
	shadow.name = "JabContactShadow"
	shadow.top_level = true
	shadow.global_position = layer_position
	_orient_quad_horizontal(shadow, attack_direction)
	_fade(shadow, duration, 1.03)
	# 同じ原画から分離した半透明煙と加算光を同じ位置へ固定する。
	# 形状を増やさず、暗部だけが通常合成、発光部だけが加算になる。
	var smoke := _mixed_sprite(JAB_CONTACT_SMOKE, jab_contact_size,
		Color(0.34, 0.19, 0.08, 0.76), 0.0, 36)
	smoke.name = "JabContactSmoke"
	smoke.top_level = true
	smoke.global_position = layer_position
	_orient_quad_horizontal(smoke, attack_direction)
	_fade(smoke, duration, 1.03)
	var smear := _sprite(JAB_CONTACT_BRIGHT, jab_contact_size,
		jab_contact_tint, jab_contact_emission, 38)
	smear.name = "ImpactSmear"
	smear.top_level = true
	smear.global_position = layer_position
	_orient_quad_horizontal(smear, attack_direction)
	_fade(smear, duration, 1.03)
	# 細い電光の間を埋める、面状で半透明な熱膜。frame 1の物理的な
	# プラズマ材質を薄く再利用し、線画だけへ痩せるのを防ぐ。
	var body := _sprite(REFERENCE_IMPACT_PHASE_1, jab_contact_size,
		Color(1.0, 0.76, 0.26, 0.20), 0.14, 37)
	body.name = "JabContactBody"
	body.top_level = true
	body.global_position = layer_position
	_orient_quad_horizontal(body, attack_direction)
	_fade(body, duration * 0.96, 1.03)
	# 通常合成の本体は煙の暗部を担う。同じ素材の明部だけを低濃度で
	# 加算し、細い光条が実機で沈まず、板状にも戻らないようにする。
	var glow := _sprite(JAB_CONTACT_GAS,
		Vector2(jab_contact_size.x, jab_contact_size.y * 1.12),
		Color(1.0, 0.78, 0.30, 0.30), 0.26, 37)
	glow.name = "JabContactGlow"
	glow.top_level = true
	glow.global_position = layer_position
	_orient_quad_horizontal(glow, attack_direction)
	_fade(glow, duration * 0.92, 1.04)
	# 参照2の接触側にだけ残る小さな白黄の破裂。広い星形にはせず、
	# 線状スミアの終点へ局所的な白熱を置く。
	var burst := _sprite(RIGHT_STRAIGHT_CONTACT, jab_contact_burst_size,
		Color(1.28, 1.16, 0.82, 1.0), 2.10, 39)
	burst.name = "JabContactBurst"
	burst.top_level = true
	burst.global_position = position \
		- attack_direction * (straight_contact_core_u - 0.5) \
		* jab_contact_burst_size.x
	_orient_quad_horizontal(burst, attack_direction)
	_fade(burst, duration * 0.88, 1.05)


func _spawn_straight_hit(position: Vector3, direction: Vector3) -> void:
	# 参照3は一本のスミアではなく、既に上下へ割れた不規則な白金の筆跡。
	# 素材の白熱収束点（76%地点）を命中座標へ置き、残り24%を敵側へ通す。
	var attack_direction := direction.normalized()
	var layer_position := position \
		- attack_direction * (straight_trail_contact_u - 0.5) \
		* straight_trail_size.x
	# 原画は共通のまま、黒褐色の煙だけを通常合成へ分離する。明部を
	# 加算シェーダーへ渡すことで、縮小時にも乾いた筆跡へ戻らない。
	var smoke := _mixed_sprite(RIGHT_STRAIGHT_TRAIL_SMOKE,
		straight_trail_size, Color(0.065, 0.028, 0.008, 0.26), 0.0, 33)
	smoke.name = "StraightSmokeSprite"
	smoke.top_level = true
	smoke.global_position = layer_position
	_orient_quad_horizontal(smoke, attack_direction)
	_fade(smoke, straight_frame_duration, 1.02, 0.34)
	# 細線だけで羽毛に見えないよう、同じプラズマをぼかした低濃度の
	# 体積層を下へ置く。輪郭やサイズは増やさず、内部の密度だけを補う。
	var volume := _straight_trail_sprite(
		RIGHT_STRAIGHT_TRAIL_VOLUME, 0.52, 34, 0.34)
	volume.name = "StraightVolumeSprite"
	volume.top_level = true
	volume.global_position = layer_position
	_orient_quad_horizontal(volume, attack_direction)
	_fade(volume, straight_frame_duration, 1.022, 0.34)
	_transition_straight_trail_to_frame_4(volume, 0.52, 0.34)
	var trail := _straight_trail_sprite(
		RIGHT_STRAIGHT_TRAIL_BRIGHT, 1.20, 35, 0.96)
	trail.name = "StraightTrailSprite"
	trail.top_level = true
	trail.global_position = layer_position
	_orient_quad_horizontal(trail, attack_direction)
	_fade(trail, straight_frame_duration, 1.02, 0.34)
	_transition_straight_trail_to_frame_4(trail, 1.20, 0.96)
	# 高密度部分だけを再抽出した細い芯。外側の膜とは別に白熱させ、
	# frame 4では同じタイミングで黄へ移る。
	var core := _straight_trail_sprite(
		RIGHT_STRAIGHT_TRAIL_CORE, 0.24, 36, 0.08)
	core.name = "StraightCoreSprite"
	core.top_level = true
	core.global_position = layer_position
	_orient_quad_horizontal(core, attack_direction)
	_fade(core, straight_frame_duration * 0.96, 1.018, 0.34)
	_transition_straight_trail_to_frame_4(core, 0.24, 0.08)
	phase_spawned.emit(_technique, &"straight_frame_3")
	_spawn_straight_frame_4_later(position, attack_direction, _technique)


func _spawn_straight_frame_4_later(position: Vector3, direction: Vector3,
		technique: StringName) -> void:
	await get_tree().create_timer(straight_frame_interval).timeout
	if not is_inside_tree() or _technique != technique:
		return
	# 参照4は参照3の筆跡を白から黄へ変化させながら残し、
	# 接触点へ非対称な白金の割れだけを重ねる。
	# 円形FLARE/HOT_STARや新しい扇は足さない。
	var contact := _sprite(RIGHT_STRAIGHT_CONTACT, straight_contact_size,
		Color(1.30, 1.16, 0.80, 1.0), 2.10, 39)
	contact.name = "StraightContactBurst"
	contact.top_level = true
	contact.global_position = position \
		- direction * (straight_contact_core_u - 0.5) \
		* straight_contact_size.x
	_orient_quad_horizontal(contact, direction)
	_fade(contact, straight_contact_duration, 1.04)
	phase_spawned.emit(technique, &"straight_frame_4")


func _spawn_hook_hit(target: Node3D, position: Vector3,
		direction: Vector3) -> void:
	# 左フック接触。素材の白熱コアを敵幅の55%地点へ固定し、長い尾を
	# 攻撃者側、短い出口を反対側へ通す。Quad中央を敵中央へ置くのではない。
	var attack_direction := direction.normalized()
	var metrics := _target_effect_metrics(target, position)
	var target_center: Vector3 = metrics.center
	var target_width: float = metrics.width
	var target_height: float = metrics.height
	var contact_core := target_center
	contact_core.y -= target_height * hook_contact_lower_ratio
	contact_core += attack_direction * target_width * 0.05
	var contact_smoke := _mixed_sprite(LEFT_HOOK_CONTACT_SMOKE,
		hook_contact_size, Color(0.07, 0.028, 0.008, 0.0), 0.0, 38)
	contact_smoke.name = "HookContactSmoke"
	contact_smoke.top_level = true
	contact_smoke.global_position = contact_core \
		- attack_direction * (hook_contact_core_u - 0.5) \
		* hook_contact_size.x \
		+ _camera_forward() * target_width * hook_depth_ratio
	_orient_quad_horizontal(contact_smoke, attack_direction)
	_set_sprite_depth_test(contact_smoke, true)
	_fade(contact_smoke, hook_contact_duration, 1.06)
	var contact_volume := _sprite(LEFT_HOOK_CONTACT_VOLUME,
		hook_contact_size, Color(1.0, 0.82, 0.55, 0.62), 1.20, 38)
	contact_volume.name = "HookContactVolume"
	contact_volume.top_level = true
	contact_volume.global_position = contact_core \
		- attack_direction * (hook_contact_core_u - 0.5) \
		* hook_contact_size.x \
		+ _camera_forward() * target_width * hook_depth_ratio
	_orient_quad_horizontal(contact_volume, attack_direction)
	_set_sprite_depth_test(contact_volume, true)
	_fade(contact_volume, hook_contact_duration, 1.06)
	var contact := _sprite(LEFT_HOOK_CONTACT_BRIGHT, hook_contact_size,
		Color(1.10, 1.02, 0.82, 0.75), 1.25, 39)
	contact.name = "HookContactSprite"
	contact.top_level = true
	contact.global_position = contact_core \
		- attack_direction * (hook_contact_core_u - 0.5) \
		* hook_contact_size.x \
		+ _camera_forward() * target_width * hook_depth_ratio
	_orient_quad_horizontal(contact, attack_direction)
	_set_sprite_depth_test(contact, true)
	_fade(contact, hook_contact_duration, 1.06)
	# 胴体に隠れる深度あり本体と同じプラズマを、交差区間だけ小さく
	# 低濃度で前面へ戻す。閾値済み素材なので灰色の面は出さず、細い
	# 乱流と白熱した密度だけが敵表面を横切る。
	var surface_plasma_size := Vector2(
		target_width * 2.20, target_height * 0.55)
	var surface_plasma := _sprite(LEFT_HOOK_CONTACT_BRIGHT,
		surface_plasma_size, Color(1.20, 1.10, 0.90, 0.36), 1.65, 40)
	surface_plasma.name = "HookContactSurfacePlasma"
	surface_plasma.top_level = true
	surface_plasma.global_position = contact_core \
		- attack_direction * (hook_contact_core_u - 0.5) \
		* surface_plasma_size.x
	_orient_quad_horizontal(surface_plasma, attack_direction)
	_fade(surface_plasma, hook_contact_duration * 0.84, 1.035)
	var surface_volume := _sprite(LEFT_HOOK_CONTACT_VOLUME,
		surface_plasma_size, Color(1.0, 0.85, 0.55, 0.36), 1.05, 39)
	surface_volume.name = "HookContactSurfaceVolume"
	surface_volume.top_level = true
	surface_volume.global_position = surface_plasma.global_position
	_orient_quad_horizontal(surface_volume, attack_direction)
	_fade(surface_volume, hook_contact_duration * 0.82, 1.035)
	# 深度あり本体だけでは胴体区間が完全に消えるため、白熱コアの切り出しを
	# 小さく低濃度で表面へ残す。全帯を前面へ貼らず、内部発光だけを見せる。
	var surface_core := _sprite(LEFT_HOOK_CONTACT_CORE,
		Vector2(target_width * hook_contact_surface_core_ratio.x,
			target_height * hook_contact_surface_core_ratio.y),
		Color(1.0, 1.0, 0.96, 0.35), 2.10, 40)
	surface_core.name = "HookContactSurfaceCore"
	surface_core.top_level = true
	surface_core.global_position = contact_core \
		- attack_direction * (straight_contact_core_u - 0.5) \
		* ((surface_core.mesh as QuadMesh).size.x)
	_orient_quad_horizontal(surface_core, attack_direction)
	_fade(surface_core, hook_contact_duration * 0.86, 1.04)
	# 敵の前面全面を白く塗らず、素材内の不規則な芯を狭く切り出す。
	# これが貫通帯の内部だけに見える白熱階層になる。
	var hot_core := _sprite(LEFT_HOOK_CONTACT_CORE,
		Vector2(target_width * 1.08, target_height * 0.30),
		Color(1.0, 1.0, 0.96, 0.72), 2.80, 41)
	hot_core.name = "HookContactHotCore"
	hot_core.top_level = true
	hot_core.global_position = contact_core \
		- attack_direction * (straight_contact_core_u - 0.5) \
		* ((hot_core.mesh as QuadMesh).size.x)
	_orient_quad_horizontal(hot_core, attack_direction)
	_fade(hot_core, hook_contact_duration * 0.68, 1.03)
	# 深度ありの体積層を敵の前後へ通しつつ、交差区間だけに細い白熱芯を
	# 表面合成する。広いヴェールではなく、内部を貫いた線として読ませる。
	var penetration_core := _sprite(HOOK_PENETRATION_CORE,
		Vector2(target_width * 1.35, target_height * 0.14),
		Color(1.55, 1.34, 0.88, 0.28), 2.40, 42)
	penetration_core.name = "HookContactPenetrationCore"
	penetration_core.top_level = true
	penetration_core.global_position = contact_core \
		- attack_direction * (straight_trail_contact_u - 0.5) \
		* ((penetration_core.mesh as QuadMesh).size.x) \
		+ attack_direction * target_width * 0.02
	_orient_quad_horizontal(penetration_core, attack_direction)
	_fade(penetration_core, hook_contact_duration * 0.74, 1.025)
	phase_spawned.emit(_technique, &"hook_contact_burst")
	_spawn_hook_follow_later(target_center, target_width, target_height,
		attack_direction, _technique)


func _spawn_directional_contact_burst(position: Vector3, name_prefix: String,
		flattened: bool, duration: float, diameter: float = -1.0) -> void:
	var vertical_scale := later_hit_vertical_scale if flattened else 1.0
	var core_diameter := impact_core_diameter if diameter <= 0.0 else diameter
	var glow_size := core_diameter * 1.45
	var glow := _sprite(FLARE,
		Vector2(glow_size, glow_size * vertical_scale),
		Color(1.58, 1.31, 0.76, 0.92), 12.0, 38)
	glow.name = name_prefix + "ImpactBloom"
	glow.top_level = true
	glow.global_position = position
	_fade(glow, duration, 1.15)
	var core_size := core_diameter
	var core := _sprite(HOT_STAR,
		Vector2(core_size, core_size * vertical_scale),
		Color(1.75, 1.66, 1.42, 1.0), 14.0, 39)
	core.name = name_prefix + "ImpactCore"
	core.top_level = true
	core.global_position = position
	core.rotation.z = _rng.randf_range(-0.20, 0.20)
	_fade(core, duration * 0.82, 1.10)


func _spawn_hook_follow_later(target_center: Vector3, target_width: float,
		target_height: float, direction: Vector3, technique: StringName) -> void:
	await get_tree().create_timer(hook_follow_interval).timeout
	if not is_inside_tree() or _technique != technique:
		return
	var low_position := target_center - Vector3.UP \
		* target_height * hook_follow_lower_ratio
	var follow_core := low_position + direction * target_width * 0.05
	var follow_smoke := _mixed_sprite(LEFT_HOOK_FOLLOW_SMOKE,
		hook_follow_size, Color(0.06, 0.024, 0.007, 0.0), 0.0, 37)
	follow_smoke.name = "HookFollowSmoke"
	follow_smoke.top_level = true
	follow_smoke.global_position = follow_core \
		- direction * (hook_follow_core_u - 0.5) * hook_follow_size.x \
		+ _camera_forward() * target_width * hook_depth_ratio
	_orient_quad_horizontal(follow_smoke, direction)
	_set_sprite_depth_test(follow_smoke, true)
	_fade(follow_smoke, hook_follow_duration, 1.04)
	var follow_volume := _sprite(LEFT_HOOK_CONTACT_VOLUME,
		hook_follow_size, Color(1.0, 0.76, 0.42, 0.52), 0.94, 37)
	follow_volume.name = "HookFollowVolume"
	follow_volume.top_level = true
	follow_volume.global_position = follow_core \
		- direction * (hook_follow_core_u - 0.5) * hook_follow_size.x \
		+ _camera_forward() * target_width * hook_depth_ratio
	_orient_quad_horizontal(follow_volume, direction)
	_set_sprite_depth_test(follow_volume, true)
	_fade(follow_volume, hook_follow_duration, 1.04)
	var follow := _sprite(LEFT_HOOK_FOLLOW_BRIGHT, hook_follow_size,
		Color(1.05, 0.92, 0.68, 0.60), 0.92, 38)
	follow.name = "HookFollowSprite"
	follow.top_level = true
	follow.global_position = follow_core \
		- direction * (hook_follow_core_u - 0.5) * hook_follow_size.x \
		+ _camera_forward() * target_width * hook_depth_ratio
	_orient_quad_horizontal(follow, direction)
	_set_sprite_depth_test(follow, true)
	_fade(follow, hook_follow_duration, 1.04)
	var surface_plasma_size := Vector2(
		target_width * 2.40, target_height * 0.30)
	var surface_plasma := _sprite(LEFT_HOOK_FOLLOW_BRIGHT,
		surface_plasma_size, Color(1.12, 0.98, 0.72, 0.26), 1.08, 39)
	surface_plasma.name = "HookFollowSurfacePlasma"
	surface_plasma.top_level = true
	surface_plasma.global_position = follow_core \
		- direction * (hook_follow_core_u - 0.5) * surface_plasma_size.x
	_orient_quad_horizontal(surface_plasma, direction)
	_fade(surface_plasma, hook_follow_duration * 0.82, 1.025)
	var surface_volume := _sprite(LEFT_HOOK_CONTACT_VOLUME,
		surface_plasma_size, Color(1.0, 0.68, 0.28, 0.28), 0.74, 38)
	surface_volume.name = "HookFollowSurfaceVolume"
	surface_volume.top_level = true
	surface_volume.global_position = surface_plasma.global_position
	_orient_quad_horizontal(surface_volume, direction)
	_fade(surface_volume, hook_follow_duration * 0.80, 1.025)
	var surface_core := _sprite(LEFT_HOOK_FOLLOW_CORE,
		Vector2(target_width * hook_follow_surface_core_ratio.x,
			target_height * hook_follow_surface_core_ratio.y),
		Color(1.0, 0.96, 0.78, 0.16), 1.60, 39)
	surface_core.name = "HookFollowSurfaceCore"
	surface_core.top_level = true
	surface_core.global_position = follow_core \
		- direction * (straight_contact_core_u - 0.5) \
		* ((surface_core.mesh as QuadMesh).size.x)
	_orient_quad_horizontal(surface_core, direction)
	_fade(surface_core, hook_follow_duration * 0.78, 1.02)
	var hot_core := _sprite(LEFT_HOOK_FOLLOW_CORE,
		Vector2(target_width * 1.02, target_height * 0.14),
		Color(1.0, 0.98, 0.90, 0.50), 2.30, 40)
	hot_core.name = "HookFollowHotCore"
	hot_core.top_level = true
	hot_core.global_position = follow_core \
		- direction * (straight_contact_core_u - 0.5) \
		* ((hot_core.mesh as QuadMesh).size.x)
	_orient_quad_horizontal(hot_core, direction)
	_fade(hot_core, hook_follow_duration * 0.66, 1.02)
	var penetration_core := _sprite(HOOK_PENETRATION_CORE,
		Vector2(target_width * 1.85, target_height * 0.10),
		Color(1.30, 1.10, 0.66, 0.30), 2.00, 41)
	penetration_core.name = "HookFollowPenetrationCore"
	penetration_core.top_level = true
	penetration_core.global_position = follow_core \
		- direction * (straight_trail_contact_u - 0.5) \
		* ((penetration_core.mesh as QuadMesh).size.x) \
		+ direction * target_width * 0.03
	_orient_quad_horizontal(penetration_core, direction)
	_fade(penetration_core, hook_follow_duration * 0.70, 1.02)
	phase_spawned.emit(technique, &"hook_follow_through")


func _spawn_reference_impact(position: Vector3, direction: Vector3,
		finisher: bool) -> void:
	var duration: float = impact_duration * (1.25 if finisher else 1.0)
	# ジャブ・ストレート・フックで横のリーチを揃える。
	var scale: float = 1.0
	var attack_direction := direction.normalized()
	var back := -attack_direction

	# 1. 攻撃者から接触点へ収束する太いスミア。参照動画の横長の金色帯。
	_spawn_attack_smear(position, attack_direction, duration, scale)

	# 2. Bloomを作る柔らかい面。白飛びは接触点の狭い範囲だけに置く。
	var glow := _sprite(FLARE, Vector2.ONE * impact_core_diameter * scale * 1.45,
		Color(1.58, 1.31, 0.76, 0.92), 12.0, 35)
	glow.name = "ImpactBloom"
	glow.top_level = true
	glow.global_position = position
	_fade(glow, duration, 1.18)

	# 3. 中央の白い星。アッパーのような大星にはせず、芯だけを白に保つ。
	var core := _sprite(HOT_STAR, Vector2.ONE * impact_core_diameter * scale,
		Color(1.75, 1.66, 1.42, 1.0), 14.0, 39)
	core.name = "ImpactHotCore"
	core.top_level = true
	core.global_position = position
	core.rotation.z = _rng.randf_range(-0.20, 0.20)
	_fade(core, duration * 0.82, 1.12)

	# 電光と方向ブラーは命中スプライト側へ統合済み。
	# 参照3・4の扇状残光は今回の対象外なので、ここで終了する。


func _spawn_attack_smear(position: Vector3, attack_direction: Vector3,
		duration: float, scale: float, name_prefix: String = "Impact") -> void:
	var length := impact_smear_length * scale
	var size := Vector2(length, length * 0.40)
	# 暗い尾と内部カットは通常合成し、背景を実際に暗くする。
	var dark := _sprite(REFERENCE_IMPACT_PHASE_2_DARK,
		size, Color.WHITE, 0.0, 36)
	dark.name = name_prefix + "SmearDark"
	dark.top_level = true
	var dark_material := (dark.mesh as QuadMesh).material as StandardMaterial3D
	dark_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	dark_material.emission_enabled = false
	dark_material.emission_texture = null

	# 金・白のスミアと接触稲妻は透過PNGを加算合成する。
	var smear := _sprite(REFERENCE_IMPACT_PHASE_2_LIGHT,
		size, Color.WHITE, 1.15, 37)
	smear.name = name_prefix + "Smear"
	smear.top_level = true
	# 素材内の接触点は横位置80%。両層を同じ命中座標へ合わせる。
	var layer_position := position - attack_direction * length * 0.30
	dark.global_position = layer_position
	smear.global_position = layer_position
	_orient_quad_horizontal(dark, attack_direction)
	_orient_quad_horizontal(smear, attack_direction)
	_fade(dark, duration, 1.03)
	_fade(smear, duration, 1.03)


func _spawn_impact_plume(position: Vector3, back: Vector3, duration: float,
		scale: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var normal := -camera.global_basis.z.normalized()
	var axis := back - normal * back.dot(normal)
	if axis.length_squared() < 0.001:
		axis = camera.global_basis.x
	axis = axis.normalized()
	var side := normal.cross(axis).normalized()
	var length := impact_plume_size.x * scale
	var half_height := impact_plume_size.y * scale * 0.5
	var anchor := clampf(impact_plume_anchor, 0.0, 1.0)
	var start := -axis * length * anchor
	var end := axis * length * (1.0 - anchor)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		start + side * half_height, start - side * half_height,
		end + side * half_height, end - side * half_height,
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := _material(IMPACT_PLUME,
		Color(1.34, 0.82, 0.20, 0.72), 4.5, false)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.render_priority = 34
	mesh.surface_set_material(0, material)
	var plume := MeshInstance3D.new()
	plume.name = "ImpactPlume"
	plume.mesh = mesh
	plume.top_level = true
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plume)
	plume.global_position = position
	_fade(plume, duration, 1.08)


func _spawn_contact_crack(position: Vector3, back: Vector3,
		duration: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var normal := -camera.global_basis.z.normalized()
	var axis := back - normal * back.dot(normal)
	if axis.length_squared() < 0.001:
		axis = camera.global_basis.x
	axis = axis.normalized()
	var side := normal.cross(axis).normalized()
	# 扇の手前に埋もれないよう、接触点から対象側へ少しだけずらす。
	var crack_origin := position - axis * 0.08
	var points := PackedVector3Array([
		crack_origin + side * 0.20 - axis * 0.02,
		crack_origin + side * 0.10 + axis * 0.12,
		crack_origin + side * 0.02 - axis * 0.05,
		crack_origin - side * 0.15 + axis * 0.10,
		crack_origin - side * 0.32 - axis * 0.02,
	])
	for index: int in points.size() - 1:
		_spawn_solid_glow_segment(points[index], points[index + 1], 0.024,
			duration * 0.90, "ImpactContactCrack", 38)


func _spawn_impact_fan(position: Vector3, back: Vector3, duration: float,
		scale: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var normal := -camera.global_basis.z.normalized() if camera != null else Vector3.FORWARD
	var fan_axis := back - normal * back.dot(normal)
	if fan_axis.length_squared() < 0.001:
		fan_axis = camera.global_basis.x if camera != null else Vector3.RIGHT
	else:
		fan_axis = fan_axis.normalized()
	var count: int = maxi(impact_fan_count, 1)
	# 右ストレート4。横のリーチを保ちつつ、参照の低い扇へ束ねる。
	var spread := deg_to_rad(impact_fan_spread_degrees) \
		* later_hit_vertical_scale
	var lane_axis := normal.cross(fan_axis).normalized()
	for index: int in count:
		var ratio: float = 0.5 if count == 1 else float(index) / float(count - 1)
		var lane := ratio - 0.5
		var angle := lerpf(-spread, spread, ratio)
		angle += _rng.randf_range(-spread * 0.30, spread * 0.30)
		var ray_direction := fan_axis.rotated(normal, angle).normalized()
		# 炎型テクスチャは画像中央の約半分が実像なので、Quadの長さを2倍にする。
		# 根元を接触点へ束ね、参照3・4枚目の太い筆跡を作る。
		var length := _rng.randf_range(impact_fan_length.x,
			impact_fan_length.y) * scale
		if index == count / 2:
			length = impact_fan_length.y * scale
		var width := _rng.randf_range(impact_fan_width.x,
			impact_fan_width.y) * scale * later_hit_vertical_scale
		var texture := BRUSH_STREAKS[index % BRUSH_STREAKS.size()]
		var ray := _sprite(texture, Vector2(width, length * 2.0),
			Color(1.44, 0.76, 0.10, 0.96), 6.0, 32)
		ray.name = "StraightFanRay"
		ray.top_level = true
		var lane_offset := lane_axis * lane * impact_fan_lane_span * scale \
			* later_hit_vertical_scale
		ray.global_position = position + lane_offset + ray_direction * length * 0.5
		_orient_quad(ray, ray_direction)
		_fade(ray, duration, 1.04)
		var core_length := length * _rng.randf_range(0.72, 0.90)
		var core := _sprite(texture,
			Vector2(width * 0.82, core_length * 2.0),
			Color(1.58, 1.52, 1.30, 1.0), 10.0, 33)
		core.name = "StraightFanCore"
		core.top_level = true
		core.global_position = position + lane_offset + ray_direction * core_length * 0.5
		_orient_quad(core, ray_direction)
		_fade(core, duration * 0.74, 1.02)


func _spawn_finisher_arc(position: Vector3, direction: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var normal := -camera.global_basis.z.normalized()
	var forward := direction - normal * direction.dot(normal)
	if forward.length_squared() < 0.001:
		forward = camera.global_basis.x
	forward = forward.normalized()
	var up := normal.cross(forward).normalized()
	var size := finisher_arc_diameter * 0.50
	# 動画の締めにある、対象の輪郭へ沿う角張った「>」を二重にする。
	for layer: int in 2:
		var inset := float(layer) * 0.12
		var center := position - forward * size * (0.52 + inset)
		var points := PackedVector3Array([
			center - forward * 0.10 + up * size * (1.0 - inset),
			center + forward * size * (0.48 - inset) + up * size * 0.42,
			center + forward * size * (0.62 - inset),
			center + forward * size * (0.48 - inset) - up * size * 0.42,
			center - forward * 0.10 - up * size * (1.0 - inset),
		])
		for index: int in points.size() - 1:
			_spawn_glow_segment(points[index], points[index + 1],
				0.070 if layer == 0 else 0.040,
				finisher_arc_duration * (1.0 - layer * 0.12),
				"Stage3ImpactArc" if layer == 0 else "Stage3ImpactArcCore",
				28 + layer)
func _spawn_stage_two_sequence(position: Vector3, direction: Vector3, technique: StringName) -> void:
	_spawn_star(position)
	phase_spawned.emit(technique, &"star")
	_stage_two_later(position, direction, technique)

func _stage_two_later(position: Vector3, direction: Vector3, technique: StringName) -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	if not is_inside_tree(): return
	for child in get_children():
		if child.name.to_lower().begins_with("stage2star"):
			child.visible = false
			child.queue_free()
	var orange_position := position - direction * 0.18
	_spawn_orange_glow(orange_position)
	phase_spawned.emit(technique, &"orange_glow")
	for _frame in orange_glow_frames:
		await get_tree().process_frame
	if not is_inside_tree(): return
	_spawn_flame(orange_position, technique)
	_spawn_reverse_fan(position, -direction)
	phase_spawned.emit(technique, &"jagged_flame")

func _spawn_star(position: Vector3) -> void:
	_spawn_contact_glow(position, star_contact_glow_size, 10.0, float(star_frames) / phase_fps)
	var star := _sprite(GEN_STARS[_rng.randi_range(0, GEN_STARS.size() - 1)],
		Vector2.ONE * star_diameter * 1.15, Color(1.5, 1.45, 1.3, 1.0), 6.0, 34)
	star.name = "Stage2Star"
	star.top_level = true
	star.global_position = position
	_fade(star, maxf(float(star_frames) / phase_fps, 0.05), 1.18)

func _spawn_contact_glow(position: Vector3, size: float, energy: float, duration: float) -> void:
	var glow := _sprite(FLARE, Vector2.ONE * size, Color(1.35, 1.28, 1.10, 1.0), energy, 20)
	glow.name = "FilledContactGlow"
	glow.top_level = true
	glow.global_position = position
	_fade(glow, duration, 1.15)

func _spawn_orange_glow(position: Vector3) -> void:
	var glow := _sprite(GEN_GLOWS[_rng.randi_range(0, GEN_GLOWS.size() - 1)],
		Vector2.ONE * orange_glow_diameter * 1.1, Color(1.3, 1.2, 1.0, 1.0), 6.0, 29)
	glow.name = "Stage2OrangeGlow"
	glow.top_level = true
	glow.global_position = position
	_fade(glow, float(orange_glow_frames) / phase_fps, 1.35)

func _spawn_radial_rays(position: Vector3, color: Color, count: int, length: float, width: float, energy: float, duration: float, ray_name: String) -> void:
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x.normalized() if camera != null else Vector3.RIGHT
	var up := camera.global_basis.y.normalized() if camera != null else Vector3.UP
	for index in count:
		var angle := TAU * float(index) / float(count)
		var direction := right * cos(angle) + up * sin(angle)
		var ray := _triangle(length, clampf(width, 0.10, 0.16), color, energy, 28)
		ray.name = ray_name
		ray.top_level = true
		ray.global_position = position + direction * length * 0.28
		_orient_mesh(ray, direction)
		_fade(ray, duration, 1.25)

func _spawn_flame(position: Vector3, technique: StringName) -> void:
	var flame := _sprite(FLAMES[0], Vector2.ONE * jagged_flame_diameter, orange_color, 10.0, 26)
	flame.name = "Stage2JaggedFlame"
	flame.top_level = true
	flame.global_position = position
	_animate_flame(flame, technique)

func _animate_flame(flame: MeshInstance3D, technique: StringName) -> void:
	for frame in FLAMES.size():
		if not is_instance_valid(flame): return
		_set_texture(flame, FLAMES[frame])
		flame.rotation.z += 0.36
		slash_frame_advanced.emit(technique, frame)
		await get_tree().create_timer(flame_frame_interval).timeout
	if is_instance_valid(flame): flame.queue_free()

func _spawn_lightning(position: Vector3, direction: Vector3, lines: int, segments: int, radius: float, phase: StringName) -> void:
	for _line_index in maxi(lines, 1):
		var previous := position + Vector3.UP * _rng.randf_range(-radius * 0.5, radius * 0.5)
		for segment_index in maxi(segments, 2):
			var progress := float(segment_index + 1) / float(maxi(segments, 2))
			var side := direction.rotated(Vector3.UP, PI * 0.5)
			var next := position + direction * lerpf(-radius * 0.40, radius * 0.65, progress)
			next += side * _rng.randf_range(-radius, radius) * 0.20
			next.y += _rng.randf_range(-radius, radius) * 0.25
			_spawn_segment(previous, next, _rng.randf_range(lightning_width.x, lightning_width.y))
			previous = next
	phase_spawned.emit(_technique, phase)

func _spawn_segment(from: Vector3, to: Vector3, width: float) -> void:
	_spawn_glow_segment(from, to, width, lightning_duration,
		"Stage3Lightning", 25)


func _spawn_solid_glow_segment(from: Vector3, to: Vector3, width: float,
		duration: float, segment_name: String, priority: int) -> void:
	var vector := to - from
	var segment := _sprite(null, Vector2(width, vector.length()),
		gold_color, 5.0, priority)
	segment.name = segment_name
	segment.top_level = true
	segment.global_position = (from + to) * 0.5
	_orient_quad(segment, vector)
	_fade(segment, duration, 0.92)
	var core := _sprite(null, Vector2(width * 0.38, vector.length()),
		Color(1.62, 1.58, 1.42, 1.0), 11.0, priority + 1)
	core.name = segment_name + "Core"
	core.top_level = true
	core.global_position = (from + to) * 0.5
	_orient_quad(core, vector)
	_fade(core, duration * 0.82, 0.92)


func _spawn_glow_segment(from: Vector3, to: Vector3, width: float,
		duration: float, segment_name: String, priority: int) -> void:
	var vector := to - from
	# 無地Quadは角張った棒に見えるため、両端が減衰する trace テクスチャを使う。
	var segment := _sprite(TRACE,
		Vector2(maxf(width, 0.012), vector.length()), orange_color, 2.4,
		priority)
	segment.name = segment_name
	segment.top_level = true
	segment.global_position = (from + to) * 0.5
	_orient_quad(segment, vector)
	_fade(segment, duration, 0.82)
	# 白熱の芯。細い白を重ねて「発光する電光」に見せる（オレンジ棒のテープ化防止）。
	var core := _sprite(TRACE,
		Vector2(maxf(width * 0.36, 0.006), vector.length()),
		Color(1.7, 1.6, 1.4, 1.0), 8.0, priority + 1)
	core.name = segment_name + "Core"
	core.top_level = true
	core.global_position = (from + to) * 0.5
	_orient_quad(core, vector)
	_fade(core, duration * 0.82, 0.82)

func _spawn_embers(position: Vector3, direction: Vector3, finisher: bool) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "ResidualEmbers"
	particles.top_level = true
	add_child(particles)
	particles.global_position = position
	particles.amount = finisher_ember_amount if finisher else ember_amount
	particles.lifetime = ember_lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = ember_randomness
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-8, -5, -8), Vector3(16, 10, 16))
	var process := ParticleProcessMaterial.new()
	var camera := get_viewport().get_camera_3d()
	var screen_right := camera.global_basis.x.normalized() if camera != null else Vector3.RIGHT
	var screen_sign := signf(direction.dot(screen_right))
	if is_zero_approx(screen_sign): screen_sign = 1.0
	process.direction = (screen_right * screen_sign + Vector3.UP * 0.12).normalized()
	process.spread = ember_spread_degrees
	var velocity := finisher_ember_velocity if finisher else ember_velocity
	process.initial_velocity_min = velocity.x
	process.initial_velocity_max = velocity.y
	process.damping_min = ember_damping.x
	process.damping_max = ember_damping.y
	process.gravity = ember_gravity
	process.scale_min = ember_scale.x
	process.scale_max = ember_scale.y
	process.particle_flag_align_y = true
	process.color_ramp = _particle_ramp()
	particles.process_material = process
	particles.draw_pass_1 = _streak_mesh()
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func _spawn_lingering_embers(position: Vector3, direction: Vector3, finisher: bool) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "LingeringEmbers"
	particles.top_level = true
	add_child(particles)
	particles.global_position = position
	particles.amount = lingering_ember_amount + (4 if finisher else 0)
	particles.lifetime = lingering_ember_lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.25
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var process := ParticleProcessMaterial.new()
	process.direction = (direction + Vector3.UP * 0.45).normalized()
	process.spread = 55.0
	process.initial_velocity_min = lingering_ember_velocity.x
	process.initial_velocity_max = lingering_ember_velocity.y
	process.damping_min = 1.0
	process.damping_max = 2.0
	process.gravity = Vector3(0.0, -1.2, 0.0)
	process.scale_min = 0.65
	process.scale_max = 1.35
	process.particle_flag_align_y = false
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.72, 1.0])
	gradient.colors = PackedColorArray([Color(1.0, 0.82, 0.24, 1.0), Color(1.0, 0.38, 0.035, 0.90), Color(1.0, 0.20, 0.01, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = lingering_ember_quad_size
	# エネルギーを上げすぎると数px に潰れたテクスチャが白い矩形ドットになる。
	quad.material = _material(FLARE, orange_color, 2.5, true)
	particles.draw_pass_1 = quad
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func _particle_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.88, 1.0])
	# HDR を上げすぎるとテクスチャの形が飛んで矩形に見える。控えめに。
	gradient.colors = PackedColorArray([Color(2.3, 2.2, 1.9, 1.0), Color(2.5, 1.5, 0.15, 1.0), Color(1.8, 0.5, 0.03, 0.78), Color(1.0, 0.2, 0.01, 0.0)])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture

func _streak_mesh() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = ember_quad_size
	var material := _material(TRACE, Color.WHITE, ember_emission_energy, true)
	# Particle HDR comes from the vertex color ramp so it can genuinely age white→gold→orange.
	material.emission_enabled = false
	material.emission_texture = null
	quad.material = material
	return quad


func _lozenge(length: float, width: float, color: Color, energy: float,
		priority: int) -> MeshInstance3D:
	# 両端を尖らせ、中央を面として残す横薙ぎ用の発光ブレード。
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0.0, -length * 0.5, 0.0),
		Vector3(-width * 0.5, -length * 0.12, 0.0),
		Vector3(-width * 0.40, length * 0.20, 0.0),
		Vector3(0.0, length * 0.5, 0.0),
		Vector3(width * 0.40, length * 0.20, 0.0),
		Vector3(width * 0.5, -length * 0.12, 0.0),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD,
		Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD,
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([
		0, 1, 5, 1, 2, 5, 2, 4, 5, 2, 3, 4,
	])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := _material(null, color, energy, false)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.render_priority = priority
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _jagged_ribbon(length: float, width: float, color: Color, energy: float,
		priority: int, phase: int, soft_edges: bool) -> MeshInstance3D:
	# 接触点側(-Y)と先端側(+Y)を細くし、中間の幅を段違いにした筆跡。
	# 単純な三角形では出ない、参照の割れた稲妻状シルエットを作る。
	var width_steps := PackedFloat32Array([
		0.04, 0.28, 0.68, 1.0, 0.82, 0.94, 0.66, 0.42, 0.18, 0.03,
	])
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for index: int in width_steps.size():
		var progress := float(index) / float(width_steps.size() - 1)
		var local_y := lerpf(-length * 0.5, length * 0.5, progress)
		var curve_phase := float(phase) * 0.73
		var zigzag := sin(float(index) * 1.35 + curve_phase) * width * 0.28
		var half_width := width * width_steps[index] * 0.5
		vertices.append(Vector3(zigzag - half_width, local_y, 0.0))
		vertices.append(Vector3(zigzag + half_width, local_y, 0.0))
		normals.append(Vector3.FORWARD)
		normals.append(Vector3.FORWARD)
		uvs.append(Vector2(0.0, progress))
		uvs.append(Vector2(1.0, progress))
	var indices := PackedInt32Array()
	for index: int in width_steps.size() - 1:
		var first := index * 2
		indices.append_array(PackedInt32Array([
			first, first + 1, first + 2,
			first + 1, first + 3, first + 2,
		]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := _material(TRACE if soft_edges else null, color, energy, false)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.render_priority = priority
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func _triangle(length: float, root_width: float, color: Color, energy: float, priority: int) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-root_width * 0.5, -length * 0.5, 0.0),
		Vector3(root_width * 0.5, -length * 0.5, 0.0),
		Vector3(0.0, length * 0.5, 0.0),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := _material(null, color, energy, false)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.render_priority = priority
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func _solid_sphere(diameter: float, color: Color, energy: float, priority: int) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = diameter * 0.5
	sphere.height = diameter
	sphere.radial_segments = 16
	sphere.rings = 8
	var material := _material(null, color, energy, false)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.render_priority = priority
	sphere.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = sphere
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func _sprite(texture: Texture2D, size: Vector2, color: Color, energy: float, priority: int) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = _material(texture, color, energy, false)
	var sprite := MeshInstance3D.new()
	sprite.mesh = quad
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	(sprite.mesh.material as StandardMaterial3D).render_priority = priority
	return sprite


func _mixed_sprite(texture: Texture2D, size: Vector2, color: Color,
		energy: float, priority: int) -> MeshInstance3D:
	# 加算合成では黒褐色が消える。通常合成で半透明の煙状暗部を残し、
	# emission texture の明部だけを発光させる。
	var sprite := _sprite(texture, size, color, energy, priority)
	var material := (sprite.mesh as QuadMesh).material as StandardMaterial3D
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	return sprite


func _straight_trail_sprite(texture: Texture2D, emission_scale: float,
		priority: int, opacity_scale: float = 1.0) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = straight_trail_size
	var shader := Shader.new()
	shader.code = STRAIGHT_TRAIL_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = priority
	material.set_shader_parameter("trail_texture", texture)
	material.set_shader_parameter("warmth", straight_frame_3_warmth)
	var initial_tint := _scaled_punch_color(straight_frame_3_tint)
	initial_tint.a *= opacity_scale
	material.set_shader_parameter("frame_tint", initial_tint)
	material.set_shader_parameter("emission_energy",
		straight_frame_3_emission * emission_scale)
	quad.material = material
	var sprite := MeshInstance3D.new()
	sprite.mesh = quad
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	return sprite


func _transition_straight_trail_to_frame_4(sprite: MeshInstance3D,
		emission_scale: float, opacity_scale: float = 1.0) -> void:
	var material := (sprite.mesh as QuadMesh).material as ShaderMaterial
	var color_tween := sprite.create_tween().set_parallel(true)
	color_tween.tween_property(material, "shader_parameter/warmth",
		straight_frame_4_warmth, straight_frame_interval) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var final_tint := _scaled_punch_color(straight_frame_4_tint)
	final_tint.a *= opacity_scale
	color_tween.tween_property(material, "shader_parameter/frame_tint",
		final_tint, straight_frame_interval) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	color_tween.tween_property(material, "shader_parameter/emission_energy",
		straight_frame_4_emission * emission_scale,
		straight_frame_interval) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _procedural_slash(size: Vector2, phase: float, priority: int) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var shader := Shader.new()
	shader.code = SLASH_BAND_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("phase", phase)
	material.render_priority = priority
	quad.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = quad
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func _material(texture: Texture2D, color: Color, energy: float, particles: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if particles else BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = particles
	material.albedo_texture = texture
	var visible_color := _scaled_punch_color(color) \
		if not particles and energy > 0.0 else color
	material.albedo_color = visible_color
	material.emission_enabled = true
	material.emission = Color(visible_color.r * energy,
		visible_color.g * energy, visible_color.b * energy, color.a)
	material.emission_texture = texture
	return material


func _punch_emission_scale() -> float:
	if _technique not in [&"jab", &"straight", &"hook"]:
		return 1.0
	return punch_emission_scale * (hook_emission_scale \
		if _technique == &"hook" else 1.0)


func _scaled_punch_color(color: Color) -> Color:
	var scale := _punch_emission_scale()
	return Color(color.r * scale, color.g * scale, color.b * scale, color.a)

func _fade(sprite: MeshInstance3D, duration: float, end_scale: float,
		fade_in_ratio_override: float = -1.0) -> void:
	# 生成直後から完成形を見せると「1枚を貼った」ように見える。
	# 完全透明から短く立ち上げ、ピークを保ち、透明へ戻して消す。
	duration = maxf(duration, 0.01)
	var fade_in_ratio := impact_fade_in_ratio if fade_in_ratio_override < 0.0 \
		else clampf(fade_in_ratio_override, 0.01, 0.90)
	var fade_in_duration := duration * fade_in_ratio
	var hold_duration := duration * impact_peak_hold_ratio
	var fade_out_duration := maxf(duration - fade_in_duration - hold_duration,
		0.005)
	sprite.transparency = 1.0
	sprite.scale = Vector3.ONE * 0.94
	var alpha_tween := sprite.create_tween()
	alpha_tween.tween_property(sprite, "transparency", 0.0,
		fade_in_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	alpha_tween.tween_interval(hold_duration)
	alpha_tween.tween_property(sprite, "transparency", 1.0,
		fade_out_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	alpha_tween.tween_callback(sprite.queue_free)
	var scale_tween := sprite.create_tween()
	scale_tween.tween_property(sprite, "scale", Vector3.ONE * end_scale,
		duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_texture(sprite: MeshInstance3D, texture: Texture2D) -> void:
	var material := (sprite.mesh as QuadMesh).material as StandardMaterial3D
	material.albedo_texture = texture
	material.emission_texture = texture

func _orient_quad(sprite: MeshInstance3D, world_direction: Vector3) -> void:
	var material := (sprite.mesh as QuadMesh).material as StandardMaterial3D
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_orient_mesh(sprite, world_direction)


func _set_sprite_depth_test(sprite: MeshInstance3D, enabled: bool) -> void:
	var quad := sprite.mesh as QuadMesh
	if quad == null or not quad.material is BaseMaterial3D:
		return
	(quad.material as BaseMaterial3D).no_depth_test = not enabled


func _orient_quad_horizontal(sprite: MeshInstance3D,
		world_direction: Vector3) -> void:
	# Billboard のままだと負方向の攻撃でもテクスチャが反転せず、素材右端の
	# 接触稲妻が攻撃者の背後へ出る。Basis で攻撃方向を確実に反映する。
	var material := (sprite.mesh as QuadMesh).material
	if material is BaseMaterial3D:
		(material as BaseMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var normal := -camera.global_basis.z.normalized()
	var long_axis := world_direction - normal * world_direction.dot(normal)
	if long_axis.length_squared() < 0.001:
		long_axis = camera.global_basis.x
	long_axis = long_axis.normalized()
	var height_axis := normal.cross(long_axis).normalized()
	sprite.global_basis = Basis(long_axis, height_axis, normal)

func _orient_mesh(sprite: MeshInstance3D, world_direction: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var normal := -camera.global_basis.z.normalized()
	var long_axis := world_direction - normal * world_direction.dot(normal)
	if long_axis.length_squared() < 0.001: long_axis = camera.global_basis.y
	long_axis = long_axis.normalized()
	var width_axis := long_axis.cross(normal).normalized()
	sprite.global_basis = Basis(width_axis, long_axis, normal)


## Billboardスプライトの横軸を、世界空間の攻撃方向を投影した画面方向へ合わせる。
func _screen_rotation(world_direction: Vector3) -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null or world_direction.length_squared() < 0.001:
		return 0.0
	var screen_direction := Vector2(world_direction.dot(camera.global_basis.x),
		-world_direction.dot(camera.global_basis.y))
	if screen_direction.length_squared() < 0.001:
		return 0.0
	return screen_direction.angle()

func _preview_origin() -> Vector3:
	return global_position + Vector3.UP * 1.05

func _nearest_target_direction() -> Vector3:
	var nearest_distance := INF
	var nearest_direction := Vector3.ZERO
	for node in get_tree().get_nodes_in_group(&"hurtbox"):
		if node is Node3D:
			var delta: Vector3 = (node as Node3D).global_position - global_position
			delta.y = 0.0
			if delta.length_squared() > 0.001 and delta.length_squared() < nearest_distance:
				nearest_distance = delta.length_squared()
				nearest_direction = delta.normalized()
	if nearest_direction != Vector3.ZERO: return nearest_direction
	# Hurtbox scenes are not required to use a group, so also inspect nearby Hurtbox nodes.
	for node in get_tree().root.find_children("*", "Hurtbox", true, false):
		if node is Node3D:
			var delta: Vector3 = (node as Node3D).global_position - global_position
			delta.y = 0.0
			if delta.length_squared() > 0.001 and delta.length_squared() < nearest_distance:
				nearest_distance = delta.length_squared()
				nearest_direction = delta.normalized()
	return nearest_direction if nearest_direction != Vector3.ZERO else _facing_direction()

func _facing_direction() -> Vector3:
	var model := get_node_or_null(^"../Model") as Node3D
	if model != null:
		var yaw := model.global_rotation.y
		return Vector3(sin(yaw), 0.0, cos(yaw)).normalized()
	return Vector3.FORWARD

func _attack_direction(target: Node3D) -> Vector3:
	var direction := target.global_position - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.001 else _facing_direction()


func _target_effect_metrics(target: Node3D,
		fallback_position: Vector3) -> Dictionary:
	var center := fallback_position
	var width := 0.90
	var height := 1.70
	if target == null:
		return {"center": center, "width": width, "height": height}
	var hurtbox := target.get_node_or_null(^"Hurtbox")
	if hurtbox == null:
		center = target.global_position
		center.y = fallback_position.y
		return {"center": center, "width": width, "height": height}
	for child: Node in hurtbox.get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.shape == null:
			continue
		center = collision.global_position
		var shape := collision.shape
		if shape is CapsuleShape3D:
			width = (shape as CapsuleShape3D).radius * 2.0
			height = (shape as CapsuleShape3D).height
		elif shape is BoxShape3D:
			var box_size := (shape as BoxShape3D).size
			width = maxf(box_size.x, box_size.z)
			height = box_size.y
		elif shape is CylinderShape3D:
			width = (shape as CylinderShape3D).radius * 2.0
			height = (shape as CylinderShape3D).height
		elif shape is SphereShape3D:
			width = (shape as SphereShape3D).radius * 2.0
			height = width
		break
	return {"center": center, "width": maxf(width, 0.1),
		"height": maxf(height, 0.1)}


func _camera_forward() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	return -camera.global_basis.z.normalized() if camera != null \
		else Vector3.FORWARD

func _clear_previews() -> void:
	for preview in _previews:
		if is_instance_valid(preview):
			# 親から即座に外し、次の技でも Stage1Spear の名前を安定させる。
			if preview.get_parent() != null:
				preview.get_parent().remove_child(preview)
			preview.queue_free()
	_previews.clear()

func _forget_preview(preview: Node3D) -> void:
	_previews.erase(preview)
	if is_instance_valid(preview): preview.queue_free()

func _spawn_finisher_screen_fx() -> void:
	# Give the orange contact polylines one readable 30 fps frame before the full-screen accents.
	await get_tree().create_timer(2.0 / phase_fps).timeout
	if not is_inside_tree(): return
	_spawn_screen_flash()
	_spawn_rgb_glitch()

func _spawn_screen_flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1.0, 0.92, 0.62, screen_flash_alpha)
	flash.size = get_viewport().get_visible_rect().size
	layer.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, screen_flash_duration)
	tween.tween_callback(layer.queue_free)

func _spawn_rgb_glitch() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 91
	add_child(layer)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE
	rect.size = get_viewport().get_visible_rect().size
	rect.visible = false
	var shader := Shader.new()
	shader.code = RGB_GLITCH_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("offset_px", clampf(glitch_offset_pixels, 4.0, 8.0))
	material.set_shader_parameter("viewport_size", rect.size)
	rect.material = material
	layer.add_child(rect)
	var tween := rect.create_tween()
	tween.tween_interval(screen_flash_duration)
	tween.tween_callback(func() -> void: rect.visible = true)
	tween.tween_interval(maxf(glitch_duration, 0.01))
	tween.tween_callback(layer.queue_free)

func _shape_for(technique: StringName) -> int:
	return 1 if technique == &"jab" or technique == &"straight" else 0
