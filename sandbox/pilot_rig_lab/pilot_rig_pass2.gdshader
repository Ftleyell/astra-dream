shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// 1. Outline exterior unificado de la silueta completa (cuerpo + cabeza)
uniform bool enable_outer_outline = true;
uniform float outer_outline_width_px : hint_range(0.0, 8.0) = 1.45;
uniform float outer_outline_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 outer_outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 outer_outline_lit_color : source_color = vec4(0.11, 0.035, 0.07, 1.0);
uniform float outer_outline_tint_mix : hint_range(0.0, 1.0) = 0.0;
uniform float zoom_scale : hint_range(0.35, 4.0) = 1.0;
uniform vec2 light_dir_2d = vec2(-0.58, -0.81);

// 2. Smear seco direccional sin costuras entre extremidades
uniform float smear_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 smear_dir = vec2(1.0, 0.0);
uniform vec4 smear_tint : source_color = vec4(0.86, 0.18, 0.32, 1.0);
uniform float q_time = 0.0;

// 3. Impact Frames de 2 frames (1 = B/N directo, 2 = invertido con rayos radiales)
uniform int impact_frame_phase : hint_range(0, 2) = 0;
uniform vec2 impact_center_uv = vec2(0.5, 0.5);

// 4. Holo-Sweep Cyber-Cut unificado
uniform float holo_sweep_pos : hint_range(-1.0, 2.0) = -1.0;
uniform float holo_sweep_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 holo_sweep_dir = vec2(0.22, 0.92);
uniform vec4 holo_beam_color : source_color = vec4(0.15, 0.96, 1.0, 1.0);

vec4 sample_unpremul(vec2 uv) {
	vec4 s = textureLod(screen_texture, clamp(uv, vec2(0.0), vec2(1.0)), 0.0);
	if (s.a <= 0.025) {
		return vec4(0.0);
	}
	s.rgb = min(s.rgb / s.a, vec3(3.0));
	return s;
}

void fragment() {
	vec4 c = sample_unpremul(SCREEN_UV);
	float orig_c_a = c.a;

	// --- 1. Outline exterior unificado sólido (antes del smear para no ennegrecer trazos de motion) ---
	if (enable_outer_outline && outer_outline_width_px > 0.01 && outer_outline_strength > 0.01 && c.a < 0.99) {
		float zc = clamp(zoom_scale, 0.35, 4.0);
		float zoom_eff = mix(0.52, 1.38, smoothstep(0.50, 2.05, zc));
		float base_px = outer_outline_width_px * zoom_eff;
		vec2 light_n = length(light_dir_2d) > 0.001 ? normalize(light_dir_2d) : vec2(-0.58, -0.81);
		float outer_max = 0.0;
		float outer_sum = 0.0;
		float hit_dirs = 0.0;
		float best_n_dist = 8.0;
		vec2 best_out_n = -light_n;
		float best_edge_dist = 8.0;
		vec3 nearest_edge_rgb = c.a > 0.25 ? min(c.rgb, vec3(1.0)) : outer_outline_color.rgb;
		for (int i = 0; i < 16; i++) {
			float ang = float(i) * 0.3926990817; // TAU / 16.0
			vec2 dir = vec2(cos(ang), sin(ang));
			float dir_best = 0.0;
			for (int ring = 0; ring < 4; ring++) {
				float rf = ring == 0 ? 0.25 : (ring == 1 ? 0.50 : (ring == 2 ? 0.75 : 1.0));
				float r_px = rf * base_px;
				vec2 tap_uv = clamp(SCREEN_UV + dir * (r_px * SCREEN_PIXEL_SIZE), vec2(0.0), vec2(1.0));
				vec4 s_tap = textureLod(screen_texture, tap_uv, 0.0);
				if (s_tap.a > 0.18) {
					float alpha_cov = smoothstep(0.18, 0.62, s_tap.a);
					float d_edge = r_px - (s_tap.a - 0.5) * 0.60;
					float reach_sample = (1.0 - smoothstep(max(base_px - 0.48, 0.0), base_px + 0.48, d_edge)) * alpha_cov;
					dir_best = max(dir_best, reach_sample);
					if (outer_outline_tint_mix > 0.001) {
						if (d_edge < best_n_dist) {
							best_n_dist = d_edge;
							best_out_n = -dir;
						}
						if (s_tap.a > 0.25 && d_edge < best_edge_dist) {
							best_edge_dist = d_edge;
							nearest_edge_rgb = min(s_tap.rgb / s_tap.a, vec3(1.0));
						}
					}
				}
			}
			outer_max = max(outer_max, dir_best);
			if (dir_best > 0.01) {
				outer_sum += dir_best;
				hit_dirs += 1.0;
			}
		}
		float outer_avg = hit_dirs > 0.5 ? (outer_sum / hit_dirs) : 0.0;
		float raw_reach = mix(outer_max, outer_avg, hit_dirs >= 2.0 ? 0.16 : 0.0);
		float outer_reach = smoothstep(0.06, 0.62, raw_reach);
		float a_r = textureLod(screen_texture, clamp(SCREEN_UV + vec2(SCREEN_PIXEL_SIZE.x, 0.0), vec2(0.0), vec2(1.0)), 0.0).a;
		float a_l = textureLod(screen_texture, clamp(SCREEN_UV + vec2(-SCREEN_PIXEL_SIZE.x, 0.0), vec2(0.0), vec2(1.0)), 0.0).a;
		float a_d = textureLod(screen_texture, clamp(SCREEN_UV + vec2(0.0, SCREEN_PIXEL_SIZE.y), vec2(0.0), vec2(1.0)), 0.0).a;
		float a_u = textureLod(screen_texture, clamp(SCREEN_UV + vec2(0.0, -SCREEN_PIXEL_SIZE.y), vec2(0.0), vec2(1.0)), 0.0).a;
		float a_ur = textureLod(screen_texture, clamp(SCREEN_UV + vec2(SCREEN_PIXEL_SIZE.x, -SCREEN_PIXEL_SIZE.y), vec2(0.0), vec2(1.0)), 0.0).a;
		float a_ul = textureLod(screen_texture, clamp(SCREEN_UV + vec2(-SCREEN_PIXEL_SIZE.x, -SCREEN_PIXEL_SIZE.y), vec2(0.0), vec2(1.0)), 0.0).a;
		float a_dr = textureLod(screen_texture, clamp(SCREEN_UV + vec2(SCREEN_PIXEL_SIZE.x, SCREEN_PIXEL_SIZE.y), vec2(0.0), vec2(1.0)), 0.0).a;
		float a_dl = textureLod(screen_texture, clamp(SCREEN_UV + vec2(-SCREEN_PIXEL_SIZE.x, SCREEN_PIXEL_SIZE.y), vec2(0.0), vec2(1.0)), 0.0).a;
		vec3 final_outline_col = outer_outline_color.rgb;
		if (outer_outline_tint_mix > 0.001) {
			vec2 edge_grad = vec2(a_l - a_r, a_u - a_d);
			if (c.a > 0.05 && dot(edge_grad, edge_grad) > 0.002) {
				best_out_n = normalize(edge_grad);
			}
			float lit_align = smoothstep(-0.10, 0.76, dot(best_out_n, light_n));
			vec3 tinted_lit_col = mix(
				outer_outline_lit_color.rgb,
				nearest_edge_rgb * 0.22 + outer_outline_lit_color.rgb * 0.78,
				0.35
			);
			final_outline_col = mix(outer_outline_color.rgb, tinted_lit_col, lit_align * outer_outline_tint_mix);
		}
		float min_in_a = min(min(min(a_r, a_l), min(a_d, a_u)), min(min(a_ur, a_ul), min(a_dr, a_dl)));
		float inner_seal_bite = mix(0.08, 0.78, smoothstep(0.85, 1.90, zc));
		float inner_seal = (1.0 - smoothstep(0.35, 0.90, min_in_a)) * c.a;
		float fg_w = smoothstep(0.20, 0.85, c.a) * (1.0 - inner_seal * inner_seal_bite);
		vec3 composed_rgb = mix(final_outline_col, c.rgb, fg_w);
		float outline_blend = outer_outline_strength * max(outer_reach, smoothstep(0.28, 0.65, c.a));
		c.rgb = c.a < 0.01 ? final_outline_col : mix(c.rgb, composed_rgb, outline_blend);
		c.a = max(c.a, outer_reach * outer_outline_strength);
	}

	// --- 2. Smear seco direccional sin costuras ---
	if (smear_strength > 0.005) {
		vec2 dir_n = length(smear_dir) > 0.001 ? normalize(smear_dir) : vec2(1.0, 0.0);
		vec2 step_uv = dir_n * SCREEN_PIXEL_SIZE * (smear_strength * 14.0);
		vec4 s1 = sample_unpremul(SCREEN_UV - step_uv * 0.45);
		vec4 s2 = sample_unpremul(SCREEN_UV - step_uv * 1.0);
		vec4 s3 = sample_unpremul(SCREEN_UV - step_uv * 1.65);

		float stripe = 0.65 + 0.35 * step(0.35, fract(SCREEN_UV.y * 85.0 + q_time * 12.0));
		float trail_a = max(s1.a * 0.65, max(s2.a * 0.42, s3.a * 0.24)) * smear_strength * stripe;
		vec3 trail_col = mix(smear_tint.rgb * 1.25, s1.rgb, 0.45);

		if (c.a < 0.35 && trail_a > 0.02) {
			float next_a = max(c.a, trail_a * 0.85);
			float w = clamp((trail_a * 1.35) / max(next_a, 0.0001), 0.0, 1.0);
			c.rgb = c.a < 0.01 ? trail_col : mix(c.rgb, trail_col, w);
			c.a = next_a;
		} else if (orig_c_a >= 0.35) {
			float dry_streak = smoothstep(0.3, 0.9, smear_strength) * (1.0 - stripe) * 0.35;
			c.rgb = mix(c.rgb, smear_tint.rgb * 1.4, dry_streak);
		}
	}

	// --- 3. Holo-Sweep Cyber-Cut unificado ---
	if (holo_sweep_strength > 0.01 && holo_sweep_pos > -0.5 && c.a > 0.01) {
		vec2 d_uv = (SCREEN_UV - impact_center_uv) / max(SCREEN_PIXEL_SIZE.y * 280.0, 0.001);
		vec2 s_dir = length(holo_sweep_dir) > 0.001 ? normalize(holo_sweep_dir) : vec2(0.22, 0.92);
		float proj = dot(d_uv, s_dir);
		float diag_pos = clamp(proj * 0.5 + 0.5, 0.0, 1.0);
		float band = 1.0 - smoothstep(0.0, 0.08, abs(diag_pos - holo_sweep_pos));
		float scan = 0.65 + 0.35 * step(0.35, fract(proj * 26.0 + q_time * 8.0));
		float beam = band * holo_sweep_strength * scan;
		c.rgb = mix(c.rgb, holo_beam_color.rgb * 1.8, clamp(beam * 0.85, 0.0, 1.0));
	}

	// --- 4. Impact Frames (2 frames: B/N directo -> invertido con rayos radiales) ---
	if (impact_frame_phase > 0 && c.a > 0.05) {
		float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
		float bw = step(0.14, luma);
		if (impact_frame_phase == 1) {
			c.rgb = vec3(bw * 1.45);
		} else {
			vec2 d_center = SCREEN_UV - impact_center_uv;
			float ang = atan(d_center.y, d_center.x);
			float ray = step(0.45, fract(ang * 5.729578 + 0.35));
			float inv_bw = 1.0 - bw;
			c.rgb = vec3(mix(inv_bw, 1.0 - inv_bw, ray * 0.65) * 1.45);
		}
	}

	if (c.a < 0.02) {
		c = vec4(0.0);
	}
	COLOR = c;
}
