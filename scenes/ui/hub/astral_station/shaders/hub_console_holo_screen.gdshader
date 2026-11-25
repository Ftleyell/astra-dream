shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// Pantalla holográfica procedural Astral Pop-Ink para Consolas de Antesala.
// Dibuja marco biselado dorado, telemetría limpia / retícula en ONLINE
// y barra de progreso ámbar segmentada en CALIBRATING, con fondo translúcido limpio.

uniform vec4 screen_color : source_color = vec4(0.95, 0.16, 0.34, 1.0);
uniform vec4 gold_color : source_color = vec4(0.91, 0.78, 0.44, 1.0);
uniform float calibration_factor : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_boost : hint_range(0.0, 2.0) = 0.0;
uniform float demat_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 demat_origin = vec3(0.0);
uniform float demat_max_radius = 30.0;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (demat_progress > 0.001) {
		float d_origin = length(v_world_pos.xz - demat_origin.xz);
		float wave_r = mix(-2.0, demat_max_radius, demat_progress);
		if (d_origin < wave_r) {
			discard;
		}
	}
	vec2 uv = UV;
	vec2 d_edge = min(uv, vec2(1.0) - uv);

	// Marco fino exterior + esquineros dorados Astral Pop-Ink
	float bx = 1.0 - smoothstep(0.012, 0.026, d_edge.x);
	float by = 1.0 - smoothstep(0.022, 0.044, d_edge.y);
	float frame = max(bx, by);

	float in_corner = step(d_edge.x, 0.15) * step(d_edge.y, 0.26);
	float gold_x = (1.0 - smoothstep(0.014, 0.036, d_edge.y)) * step(d_edge.x, 0.15);
	float gold_y = (1.0 - smoothstep(0.010, 0.026, d_edge.x)) * step(d_edge.y, 0.26);
	float corners = max(gold_x, gold_y) * in_corner;

	// Scanlines horizontales finas
	float scan = 0.80 + 0.20 * sin(uv.y * 86.0 - TIME * 4.5);

	// Telemetría ONLINE (barras horizontales izquierda + retícula sutil derecha)
	float bar_range_x = step(0.14, uv.x) * step(uv.x, 0.48);
	float bar0 = (1.0 - smoothstep(0.016, 0.032, abs(uv.y - 0.33))) * bar_range_x;
	float bar1 = (1.0 - smoothstep(0.016, 0.032, abs(uv.y - 0.50))) * step(0.14, uv.x) * step(uv.x, 0.40);
	float bar2 = (1.0 - smoothstep(0.016, 0.032, abs(uv.y - 0.67))) * step(0.14, uv.x) * step(uv.x, 0.34);
	float bars = max(bar0, max(bar1, bar2));

	vec2 rc = (uv - vec2(0.69, 0.50)) * vec2(1.87, 1.0);
	float r_dist = length(rc);
	float ring_reticle = 1.0 - smoothstep(0.014, 0.032, abs(r_dist - 0.21));
	float core_dot = 1.0 - smoothstep(0.025, 0.055, r_dist);
	float reticle = max(ring_reticle, core_dot * 0.85);
	float online_gfx = max(bars, reticle);

	// Barra de calibración segmentada en estado CALIBRATING
	float cal_x = step(0.18, uv.x) * step(uv.x, 0.82);
	float cal_y = 1.0 - smoothstep(0.040, 0.065, abs(uv.y - 0.50));
	float seg_gap = step(0.24, fract(uv.x * 10.0));
	float sweep_wave = step(fract(uv.x - TIME * 0.45), 0.35);
	float cal_bar = cal_x * cal_y * seg_gap * (0.45 + 0.55 * sweep_wave);

	float gfx = mix(online_gfx, cal_bar, calibration_factor);

	vec3 amber_col = vec3(0.95, 0.65, 0.18);
	vec3 active_col = mix(screen_color.rgb, amber_col, calibration_factor * 0.90);
	vec3 glass_bg = active_col * 0.24 * scan;

	vec3 rgb = glass_bg;
	rgb = mix(rgb, active_col * (1.35 + pulse_boost * 0.65), clamp(frame * 0.72 + gfx * 0.95, 0.0, 1.0));
	rgb = mix(rgb, gold_color.rgb * 1.30, corners * mix(1.0, 0.45, calibration_factor));

	float base_alpha = mix(0.095, 0.045, calibration_factor) * scan;
	float gfx_alpha = gfx * mix(0.68, 0.54, calibration_factor);
	float frame_alpha = frame * mix(0.58, 0.32, calibration_factor) + corners * mix(0.85, 0.42, calibration_factor);
	float alpha = clamp(max(base_alpha, max(gfx_alpha, frame_alpha)), 0.0, 0.92);

	ALBEDO = rgb;
	ALPHA = alpha;
}
