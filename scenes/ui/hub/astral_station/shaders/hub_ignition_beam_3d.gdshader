shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// Columna energética 3D vertical para el Ritual de Ignición Orbital Norte con borde Fresnel difuminado.

uniform vec4 beam_color : source_color = vec4(0.95, 0.22, 0.42, 1.0);
uniform vec4 core_gold_color : source_color = vec4(0.96, 0.82, 0.36, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 0.0;

void fragment() {
	if (intensity <= 0.005) {
		discard;
	}
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float edge_feather = pow(ndv, 2.9);
	float v_fade = smoothstep(0.0, 0.14, UV.y) * (1.0 - smoothstep(0.42, 0.98, UV.y));
	float helix_a = 0.5 + 0.5 * sin(UV.x * 37.699 + UV.y * 12.0 - TIME * 11.0);
	float helix_b = 0.5 + 0.5 * sin(UV.x * 18.849 - UV.y * 8.0 - TIME * 7.5);
	float streaks = 0.38 + 0.62 * (helix_a * 0.65 + helix_b * 0.35);
	float alpha = v_fade * edge_feather * streaks * clamp(intensity, 0.0, 1.0) * 0.56;
	vec3 col = mix(beam_color.rgb, core_gold_color.rgb, smoothstep(0.32, 0.88, helix_a)) * (1.15 + intensity * 0.90);
	ALBEDO = col;
	ALPHA = alpha;
}
