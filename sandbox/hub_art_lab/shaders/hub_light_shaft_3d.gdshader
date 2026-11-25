shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, fog_disabled;

// Haces de luz volumétricos suaves (god-rays) con bordes difuminados Fresnel.

uniform vec4 shaft_color : source_color = vec4(0.95, 0.34, 0.52, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.14;
uniform float edge_power : hint_range(0.8, 5.0) = 2.2;

void fragment() {
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float edge_feather = pow(ndv, edge_power);
	float v_fade = smoothstep(0.0, 0.22, UV.y) * (1.0 - smoothstep(0.62, 1.0, UV.y));
	float shimmer = 0.85 + 0.15 * sin(UV.x * 18.849 + TIME * 0.45);
	ALBEDO = shaft_color.rgb * intensity;
	ALPHA = edge_feather * v_fade * shimmer * intensity;
}
