shader_type canvas_item;

uniform float key_start : hint_range(0.0, 0.5) = 0.015;
uniform float key_end : hint_range(0.0, 0.5) = 0.075;


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float green_dominance = source.g - max(source.r, source.b);
	float background = smoothstep(key_start, key_end, green_dominance);
	COLOR = vec4(source.rgb, source.a * (1.0 - background));
}
