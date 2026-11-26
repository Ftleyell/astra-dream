shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Shader translúcido refinado para Puentes de Luz (Hard-Light Bridges) entre islas flotantes.
// - Rieles laterales en Oro Astral + pasarela central zafiro-cian con chevrones y rejilla hexagonal.
// - Pulso de proximidad bajo Valentina + desmaterialización radial sincronizada.

uniform vec4 bridge_color : source_color = vec4(0.14, 0.86, 1.0, 1.0);
uniform vec4 trim_gold_color : source_color = vec4(0.92, 0.77, 0.42, 1.0);
uniform float base_alpha : hint_range(0.05, 0.9) = 0.24;
uniform float scroll_speed : hint_range(0.0, 4.0) = 1.05;
uniform vec3 player_world_pos = vec3(0.0);

uniform float tutorial_highlight_pulse : hint_range(0.0, 2.0) = 0.0;
uniform vec4 tutorial_highlight_color : source_color = vec4(0.28, 0.94, 1.0, 1.0);

uniform bool demat_invert = false;
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
		float signed_wave = (d_origin + hex_d * 1.1) - wave_r;
		if ((!demat_invert && signed_wave < 0.0) || (demat_invert && signed_wave > 0.0)) {
			discard;
		}
	}

	float edge_x = abs(UV.x - 0.5) * 2.0;
	float outer_rail = smoothstep(0.86, 0.96, edge_x);
	float inner_rail = (1.0 - smoothstep(0.015, 0.045, abs(edge_x - 0.78))) * 0.65;
	float end_fade = smoothstep(0.0, 0.025, UV.y) * smoothstep(1.0, 0.975, UV.y);

	// Rejilla hexagonal sutil y chevrones direccionales finos en el carril central
	float center_mask = 1.0 - smoothstep(0.60, 0.78, edge_x);
	float chevron_phase = fract(UV.y * 4.5 - abs(UV.x - 0.5) * 1.2 - TIME * scroll_speed);
	float chevron = smoothstep(0.76, 0.85, chevron_phase) * (1.0 - smoothstep(0.88, 0.95, chevron_phase)) * center_mask;
	float hx = _hex_cell(v_world_pos.xz * 3.4);
	float hex_grid = smoothstep(0.43, 0.49, hx) * 0.38 * center_mask;

	float prox = 1.0 - smoothstep(0.5, 2.8, length(v_world_pos.xz - player_world_pos.xz));

	vec3 col = mix(bridge_color.rgb, trim_gold_color.rgb, clamp(outer_rail * 0.85 + inner_rail * 0.5 + prox * 0.20, 0.0, 1.0));
	float alpha = clamp((base_alpha + chevron * 0.24 + hex_grid * 0.22 + outer_rail * 0.55 + inner_rail * 0.30 + prox * 0.22) * end_fade, 0.0, 0.88);
	vec3 emit_col = col * (0.85 + outer_rail * 0.75 + chevron * 0.45 + prox * 0.55);
	if (tutorial_highlight_pulse > 0.001) {
		col = mix(col, tutorial_highlight_color.rgb, clamp(tutorial_highlight_pulse * 0.55, 0.0, 0.85));
		emit_col += tutorial_highlight_color.rgb * tutorial_highlight_pulse * (0.85 + outer_rail * 0.75) * end_fade;
		alpha = clamp(alpha + tutorial_highlight_pulse * 0.28 * end_fade, 0.0, 0.96);
	}

	ALBEDO = col;
	EMISSION = emit_col;
	ALPHA = alpha;
}
