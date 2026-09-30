shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.45);
uniform float edge_sharpness : hint_range(0.0, 0.1) = 0.015;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	float alpha_edge = smoothstep(0.5, 0.5 - edge_sharpness, dist);
	if (alpha_edge <= 0.0) {
		discard;
	}
	ALBEDO = shadow_color.rgb;
	ALPHA = shadow_color.a * alpha_edge;
}
