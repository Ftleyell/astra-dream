shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

// Shader translúcido de cristal arquitectónico Astral para recortes en cubierta.
// Permite ver el Cosmos Engine debajo de las islas con retícula hexagonal grabada,
// reflejo especular diagonal y disolución tecnológica sincronizada.

uniform vec4 glass_tint : source_color = vec4(0.06, 0.14, 0.28, 1.0);
uniform vec4 edge_glow_color : source_color = vec4(0.22, 0.88, 1.0, 1.0);
uniform vec4 gold_frame_color : source_color = vec4(0.92, 0.77, 0.42, 1.0);
uniform float base_alpha : hint_range(0.05, 0.7) = 0.22;
uniform float hex_scale : hint_range(1.0, 12.0) = 4.2;

uniform float demat_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 demat_origin = vec3(0.0);
uniform float demat_max_radius = 34.0;

varying vec3 v_world_pos;

float _hex_cell(vec2 p) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	return max(abs(gv.x), dot(abs(gv), normalize(r)));
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (demat_progress > 0.001) {
		float d_origin = length(v_world_pos.xz - demat_origin.xz);
		float hex_d = _hex_cell(v_world_pos.xz * 2.4);
		float wave_r = mix(-2.5, demat_max_radius, demat_progress);
		if ((d_origin + hex_d * 1.1) < wave_r) {
			discard;
		}
	}

	float hx = _hex_cell(v_world_pos.xz * hex_scale);
	float hex_grid = smoothstep(0.45, 0.495, hx) * 0.22;

	float diag_glint = pow(max(0.0, sin((v_world_pos.x + v_world_pos.z) * 0.55 - TIME * 0.45)), 10.0) * 0.14;
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, 3.0) * 0.18;

	vec3 col = mix(glass_tint.rgb, edge_glow_color.rgb, clamp(hex_grid * 0.8 + diag_glint + fresnel, 0.0, 1.0));
	float alpha = clamp(base_alpha * 0.4 + hex_grid * 0.14 + diag_glint * 0.14 + fresnel * 0.16, 0.02, 0.16);

	ALBEDO = col;
	EMISSION = col * (0.25 + hex_grid * 0.45 + diag_glint * 0.6);
	ALPHA = alpha;
}
