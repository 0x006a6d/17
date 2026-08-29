shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 0.25) = 0.075;
uniform float edge_softness : hint_range(0.001, 0.03) = 0.008;


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 centered = abs(UV - vec2(0.5));
	vec2 corner = centered - vec2(0.5 - corner_radius);
	float distance_to_edge = length(max(corner, vec2(0.0)))
		+ min(max(corner.x, corner.y), 0.0) - corner_radius;
	float mask = 1.0 - smoothstep(-edge_softness, edge_softness,
		distance_to_edge);
	COLOR = vec4(source.rgb, source.a * mask);
}
