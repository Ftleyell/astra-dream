shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

// 1. Outline exterior unificado + Micro-Rim de silueta (cuerpo + cabeza)
uniform bool enable_outer_outline = false;
uniform float outer_outline_width_px : hint_range(0.0, 8.0) = 0.78;
uniform float outline_min_px : hint_range(0.1, 4.0) = 0.48;
uniform float outline_max_px : hint_range(0.2, 8.0) = 1.15;
uniform float outer_outline_strength : hint_range(0.0, 1.0) = 0.0;
uniform float outline_inward_replace : hint_range(0.0, 1.0) = 0.12;
uniform float outline_crispness : hint_range(0.05, 1.0) = 0.42;
uniform vec4 outer_outline_color : source_color = vec4(0.045, 0.040, 0.095, 1.0);
uniform vec4 outer_outline_lit_color : source_color = vec4(0.11, 0.035, 0.07, 1.0);
uniform float outer_outline_tint_mix : hint_range(0.0, 1.0) = 0.0;
uniform float outline_calligraphy_amount : hint_range(0.0, 1.0) = 0.65;
uniform float zoom_scale : hint_range(0.35, 4.0) = 1.0;
uniform vec2 light_dir_2d = vec2(-0.58, -0.81);

uniform float silhouette_rim_strength : hint_range(0.0, 1.5) = 0.0;
uniform float silhouette_rim_width_px : hint_range(0.5, 4.0) = 1.45;
uniform float counter_rim_strength : hint_range(0.0, 1.5) = 0.0;
uniform vec4 rim_key_color : source_color = vec4(0.94, 0.97, 1.0, 1.0);
uniform vec4 rim_counter_color : source_color = vec4(0.86, 0.18, 0.32, 1.0);

// Soldador morfológico, Light-Wrap HDR y Rotated Poisson IGN
uniform float seam_weld_radius_px : hint_range(0.5, 2.5) = 1.25;
uniform float seam_bridge_threshold : hint_range(0.3, 0.9) = 0.62;
uniform float hdr_threshold : hint_range(1.0, 1.5) = 1.18;
uniform float hdr_light_wrap_strength : hint_range(0.0, 1.0) = 0.0;
uniform float ign_jitter_strength : hint_range(0.0, 1.0) = 0.0;
uniform float cas_sharpen_strength : hint_range(0.0, 1.0) = 0.0;

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

vec3 unpremul_raw(vec4 s) {
	if (s.a <= 0.0001) {
		return vec3(0.0);
	}
	return min(s.rgb / s.a, vec3(3.0));
}

vec4 sample_unpremul(vec2 uv) {
	vec4 s = textureLod(screen_texture, clamp(uv, vec2(0.0), vec2(1.0)), 0.0);
	if (s.a <= 0.025) {
		return vec4(0.0);
	}
	s.rgb = min(s.rgb / s.a, vec3(3.0));
	return s;
}

float ign(vec2 frag_coord) {
	vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
	return fract(magic.z * fract(dot(frag_coord, magic.xy)));
}

vec3 p2_linear_to_srgb(vec3 lin) {
	vec3 c = clamp(lin, vec3(0.0), vec3(1.0));
	vec3 lo = c * 12.92;
	vec3 hi = 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055;
	return mix(lo, hi, step(vec3(0.0031308), c));
}

vec3 p2_srgb_to_linear(vec3 srgb) {
	vec3 c = clamp(srgb, vec3(0.0), vec3(1.0));
	vec3 lo = c / 12.92;
	vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec4 c0_raw = textureLod(screen_texture, SCREEN_UV, 0.0);
	vec4 c = vec4(unpremul_raw(c0_raw), c0_raw.a);
	float orig_c_a = c.a;

	// --- 1. Anillo 1 compartido + Micro-Rim de silueta + HDR Light-Wrap + Contorno Caligráfico ---
	bool run_outline = enable_outer_outline && outer_outline_strength > 0.005 && outer_outline_width_px > 0.01;
	bool run_silhouette_pass = run_outline || (silhouette_rim_strength > 0.01) || (counter_rim_strength > 0.01) || (hdr_light_wrap_strength > 0.01);
	if (run_silhouette_pass) {
		float zc = clamp(zoom_scale, 0.35, 4.0);
		float zoom_eff = pow(zc, 0.60);
		float base_px = outer_outline_width_px * zoom_eff;
		float w_min = max(base_px * (1.0 - 0.42 * outline_calligraphy_amount), outline_min_px * min(zoom_eff, 1.0));
		float w_max = min(max(base_px * (1.0 + 0.25 * outline_calligraphy_amount), outline_min_px), outline_max_px * max(zoom_eff, 1.0));
		float r1_weld = seam_weld_radius_px;

		// 4 ejes diametralmente opuestos: E/W, N/S, SE/NW, SW/NE
		vec2 o_e  = vec2(r1_weld, 0.0) * px;
		vec2 o_s  = vec2(0.0, r1_weld) * px;
		vec2 o_se = vec2(r1_weld * 0.70710678, r1_weld * 0.70710678) * px;
		vec2 o_sw = vec2(-r1_weld * 0.70710678, r1_weld * 0.70710678) * px;

		vec4 s_e  = textureLod(screen_texture, clamp(SCREEN_UV + o_e,  vec2(0.0), vec2(1.0)), 0.0);
		vec4 s_w  = textureLod(screen_texture, clamp(SCREEN_UV - o_e,  vec2(0.0), vec2(1.0)), 0.0);
		vec4 s_s  = textureLod(screen_texture, clamp(SCREEN_UV + o_s,  vec2(0.0), vec2(1.0)), 0.0);
		vec4 s_n  = textureLod(screen_texture, clamp(SCREEN_UV - o_s,  vec2(0.0), vec2(1.0)), 0.0);
		vec4 s_se = textureLod(screen_texture, clamp(SCREEN_UV + o_se, vec2(0.0), vec2(1.0)), 0.0);
		vec4 s_nw = textureLod(screen_texture, clamp(SCREEN_UV - o_se, vec2(0.0), vec2(1.0)), 0.0);
		vec4 s_sw = textureLod(screen_texture, clamp(SCREEN_UV + o_sw, vec2(0.0), vec2(1.0)), 0.0);
		vec4 s_ne = textureLod(screen_texture, clamp(SCREEN_UV - o_sw, vec2(0.0), vec2(1.0)), 0.0);

		// Soldador morfológico restringido exclusivamente a micro-grietas interiores reales (nunca borde exterior)
		float avg_a1 = (s_e.a + s_w.a + s_s.a + s_n.a + s_se.a + s_nw.a + s_sw.a + s_ne.a) * 0.125;
		float solid_nb_count = step(0.50, s_e.a) + step(0.50, s_w.a) + step(0.50, s_s.a) + step(0.50, s_n.a)
			+ step(0.50, s_se.a) + step(0.50, s_nw.a) + step(0.50, s_sw.a) + step(0.50, s_ne.a);
		bool is_interior_crack = (avg_a1 > 0.55) && (solid_nb_count >= 4.5);

		float pair_ew   = min(s_e.a,  s_w.a);
		float pair_ns   = min(s_s.a,  s_n.a);
		float pair_senw = min(s_se.a, s_nw.a);
		float pair_swne = min(s_sw.a, s_ne.a);
		float max_pair_bridge = max(max(pair_ew, pair_ns), max(pair_senw, pair_swne));

		if (is_interior_crack && c.a < 0.99 && max_pair_bridge > c.a && max_pair_bridge > seam_bridge_threshold * 0.6) {
			float w_ew   = smoothstep(0.30, 0.75, pair_ew);
			float w_ns   = smoothstep(0.30, 0.75, pair_ns);
			float w_senw = smoothstep(0.30, 0.75, pair_senw);
			float w_swne = smoothstep(0.30, 0.75, pair_swne);
			vec3 bridge_rgb = (s_e.rgb + s_w.rgb) * w_ew + (s_s.rgb + s_n.rgb) * w_ns
				+ (s_se.rgb + s_nw.rgb) * w_senw + (s_sw.rgb + s_ne.rgb) * w_swne;
			float bridge_a = (s_e.a + s_w.a) * w_ew + (s_s.a + s_n.a) * w_ns
				+ (s_se.a + s_nw.a) * w_senw + (s_sw.a + s_ne.a) * w_swne;
			float target_weld_a = smoothstep(seam_bridge_threshold * 0.5, seam_bridge_threshold, max_pair_bridge);
			float welded_a = max(c.a, target_weld_a);
			vec3 bridged_col = bridge_rgb / max(bridge_a, 0.0001);
			float weld_blend = clamp((welded_a - c.a) / max(welded_a, 0.0001), 0.0, 1.0);
			c.rgb = mix(c.rgb, min(bridged_col, vec3(3.0)), weld_blend);
			c.a = welded_a;
			orig_c_a = max(orig_c_a, welded_a);
		}

		// Estadísticas Anillo 1, Sobel (grad / n_edge), curvatura y callig_width_px ANTES del muestreo radial
		float max_a1 = max(c.a, max(max(max(s_e.a, s_w.a), max(s_s.a, s_n.a)), max(max(s_se.a, s_nw.a), max(s_sw.a, s_ne.a))));
		float min_a1 = min(c.a, min(min(min(s_e.a, s_w.a), min(s_s.a, s_n.a)), min(min(s_se.a, s_nw.a), min(s_sw.a, s_ne.a))));

		float gx = (s_ne.a + 2.0 * s_e.a + s_se.a) - (s_nw.a + 2.0 * s_w.a + s_sw.a);
		float gy = (s_sw.a + 2.0 * s_s.a + s_se.a) - (s_nw.a + 2.0 * s_n.a + s_ne.a);
		vec2 grad_a = vec2(gx, gy);
		vec2 n_edge = length(grad_a) > 0.0001 ? -normalize(grad_a) : vec2(1.0, 0.0);
		vec2 t_dir = vec2(-n_edge.y, n_edge.x);
		float laplacian = (s_e.a + s_w.a + s_s.a + s_n.a) * 0.25 - c.a;
		float concavity = clamp(laplacian * 1.5, -0.5, 0.8);
		vec2 light_n = length(light_dir_2d) > 0.001 ? normalize(light_dir_2d) : vec2(-0.58, -0.81);
		float edge_dot_l = dot(n_edge, light_n);

		float callig_t = smoothstep(-0.55, 0.65, -edge_dot_l);
		float callig_width_px = clamp(mix(w_min, w_max, callig_t) + concavity * 0.35, w_min, w_max);

		// Acumuladores continuos (distancia sub-píxel, color vecino LDR y Light-Wrap HDR)
		float min_dist_px = c.a > 0.5 ? -(c.a - 0.5) : 100.0;
		vec3 nearest_ldr_rgb = vec3(0.0);
		float nearest_w_sum = 0.0;
		vec3 hdr_wrap_accum = vec3(0.0);

		vec4 ring1_taps[8] = vec4[8](s_e, s_w, s_s, s_n, s_se, s_nw, s_sw, s_ne);
		for (int i = 0; i < 8; i++) {
			vec4 tap = ring1_taps[i];
			if (tap.a > 0.15) {
				vec3 up_tap = unpremul_raw(tap);
				float wt = tap.a * tap.a;
				nearest_ldr_rgb += min(up_tap, vec3(1.0)) * wt;
				nearest_w_sum += wt;
				hdr_wrap_accum += max(up_tap - vec3(hdr_threshold), vec3(0.0)) * tap.a;
			}
		}

		// Micro-Rim de Silueta Exterior (filo de luz en el borde real de la silueta completa)
		if (c.a > 0.50 && (silhouette_rim_strength > 0.01 || counter_rim_strength > 0.01)) {
			float rim_r = silhouette_rim_width_px * zoom_eff;
			float a_toward_light = textureLod(screen_texture, clamp(SCREEN_UV + light_n * rim_r * px, vec2(0.0), vec2(1.0)), 0.0).a;
			float a_toward_opp = textureLod(screen_texture, clamp(SCREEN_UV - light_n * rim_r * px, vec2(0.0), vec2(1.0)), 0.0).a;
			float has_grad = smoothstep(0.02, 0.15, length(grad_a));
			float key_gate = mix(1.0, smoothstep(-0.20, 0.35, edge_dot_l), has_grad);
			float ctr_gate = mix(1.0, smoothstep(-0.20, 0.35, -edge_dot_l), has_grad);
			float key_sil_rim = smoothstep(0.60, 0.92, c.a) * (1.0 - smoothstep(0.15, 0.65, a_toward_light)) * key_gate;
			float ctr_sil_rim = smoothstep(0.60, 0.92, c.a) * (1.0 - smoothstep(0.15, 0.65, a_toward_opp)) * ctr_gate * (1.0 - key_sil_rim * 0.70);
			float sil_luma_gate = smoothstep(0.015, 0.055, dot(c.rgb, vec3(0.2126, 0.7152, 0.0722)));
			c.rgb += rim_key_color.rgb * key_sil_rim * silhouette_rim_strength * 0.52 * sil_luma_gate;
			c.rgb += rim_counter_color.rgb * ctr_sil_rim * counter_rim_strength * 0.42 * sil_luma_gate;
		}

		// Estimador radial continuo de cruce sub-píxel (anillos r1 = 0.50 * max_reach, r2 = 1.00 * max_reach)
		if (run_outline && min_a1 < 0.98) {
			float coarse_a = textureLod(screen_texture, SCREEN_UV, 1.5).a;
			if (coarse_a > 0.005 || max_a1 > 0.005) {
				float noise = ign(FRAGCOORD.xy) * 6.2831853 * ign_jitter_strength;
				float cn = cos(noise);
				float sn = sin(noise);
				mat2 rot = mat2(vec2(cn, sn), vec2(-sn, cn));
				const vec2 RING_12[12] = vec2[](
					vec2( 1.0000,  0.0000), vec2( 0.8660,  0.5000), vec2( 0.5000,  0.8660),
					vec2( 0.0000,  1.0000), vec2(-0.5000,  0.8660), vec2(-0.8660,  0.5000),
					vec2(-1.0000,  0.0000), vec2(-0.8660, -0.5000), vec2(-0.5000, -0.8660),
					vec2( 0.0000, -1.0000), vec2( 0.5000, -0.8660), vec2( 0.8660, -0.5000)
				);
				float max_reach = max(callig_width_px + 0.65, 1.25);
				float ray_r1 = max_reach * 0.50;
				float ray_r2 = max_reach * 1.00;
				for (int i = 0; i < 12; i++) {
					vec2 p = rot * RING_12[i];
					vec2 dir_px = n_edge * p.x + t_dir * p.y;
					vec2 tap_uv1 = clamp(SCREEN_UV + dir_px * ray_r1 * px, vec2(0.0), vec2(1.0));
					vec2 tap_uv2 = clamp(SCREEN_UV + dir_px * ray_r2 * px, vec2(0.0), vec2(1.0));
					vec4 s_tap1 = textureLod(screen_texture, tap_uv1, 0.0);
					vec4 s_tap2 = textureLod(screen_texture, tap_uv2, 0.0);

					if (c.a <= 0.5) {
						float d_ray = 100.0;
						if (s_tap1.a >= 0.5) {
							float eff_r1 = (s_tap1.a > 0.96 && c.a > 0.02) ? min(ray_r1, 0.95) : ray_r1;
							float frac = clamp((0.5 - c.a) / max(s_tap1.a - c.a, 0.001), 0.0, 1.0);
							d_ray = eff_r1 * frac;
						} else if (s_tap2.a >= 0.5) {
							float frac = clamp((0.5 - s_tap1.a) / max(s_tap2.a - s_tap1.a, 0.001), 0.0, 1.0);
							d_ray = mix(ray_r1, ray_r2, frac);
						} else if (s_tap1.a > 0.15) {
							d_ray = ray_r1 + (0.5 - s_tap1.a) * 0.75;
						} else if (s_tap2.a > 0.15) {
							d_ray = ray_r2 + (0.5 - s_tap2.a) * 0.75;
						}
						if (min_dist_px > 50.0) {
							min_dist_px = d_ray;
						} else if (d_ray < 50.0) {
							float h_sm = max(0.14 - abs(min_dist_px - d_ray), 0.0) / 0.14;
							min_dist_px = min(min_dist_px, d_ray) - h_sm * h_sm * 0.14 * 0.25;
						}
					}

					if (s_tap1.a > 0.15) {
						vec3 up1 = unpremul_raw(s_tap1);
						float wt1 = s_tap1.a * s_tap1.a;
						nearest_ldr_rgb += min(up1, vec3(1.0)) * wt1;
						nearest_w_sum += wt1;
						hdr_wrap_accum += max(up1 - vec3(hdr_threshold), vec3(0.0)) * s_tap1.a;
					}
					if (s_tap2.a > 0.15) {
						vec3 up2 = unpremul_raw(s_tap2);
						float wt2 = s_tap2.a * s_tap2.a;
						nearest_ldr_rgb += min(up2, vec3(1.0)) * wt2;
						nearest_w_sum += wt2;
						hdr_wrap_accum += max(up2 - vec3(hdr_threshold), vec3(0.0)) * s_tap2.a;
					}
				}
			}
		}

		// Colored Line Art unificado (antes del Light-Wrap HDR para no oscurecer el halo)
		if (run_outline) {
			float target_width_px = callig_width_px;

			float aa_band = clamp(max(outline_crispness, 0.42), 0.42, 0.75);
			float outline_cov = smoothstep(target_width_px + aa_band, target_width_px - aa_band, min_dist_px) * outer_outline_strength;
			vec3 avg_ldr = nearest_w_sum > 0.0001 ? (nearest_ldr_rgb / nearest_w_sum) : outer_outline_color.rgb;
			vec3 avg_srgb = p2_linear_to_srgb(clamp(avg_ldr, vec3(0.0), vec3(1.0)));
			vec3 colored_ink = p2_srgb_to_linear(pow(avg_srgb, vec3(1.45)) * 0.36);
			float lit_align = smoothstep(0.05, 0.78, edge_dot_l);
			vec3 callig_col = mix(colored_ink, mix(colored_ink, outer_outline_lit_color.rgb, 0.65), lit_align * 0.55);
			vec3 final_outline_col = mix(outer_outline_color.rgb, callig_col, outer_outline_tint_mix);

			float inward_edge_mask = (1.0 - smoothstep(0.15, 0.92, min_a1)) * outline_inward_replace * outer_outline_strength;
			if (c.a < 0.99 || inward_edge_mask > 0.01) {
				float out_a = max(c.a, outline_cov);
				float fg_over_w = c.a / max(out_a, 0.0001);
				float fg_w = fg_over_w * (1.0 - inward_edge_mask);
				vec3 composed_rgb = mix(final_outline_col, c.rgb, fg_w);
				float apply_w = max(outline_cov, inward_edge_mask);
				c.rgb = c.a < 0.01 ? final_outline_col : mix(c.rgb, composed_rgb, apply_w);
				c.a = out_a;
			}
		}

		// Light-Wrap HDR + Halo Espacial Emisivo
		if (hdr_light_wrap_strength > 0.005) {
			float wrap_r = 3.0 * zoom_eff;
			vec2 wd = vec2(0.70710678 * wrap_r) * px;
			vec4 h0 = textureLod(screen_texture, clamp(SCREEN_UV + vec2(wd.x, wd.y), vec2(0.0), vec2(1.0)), 0.5);
			vec4 h1 = textureLod(screen_texture, clamp(SCREEN_UV + vec2(-wd.x, wd.y), vec2(0.0), vec2(1.0)), 0.5);
			vec4 h2 = textureLod(screen_texture, clamp(SCREEN_UV + vec2(wd.x, -wd.y), vec2(0.0), vec2(1.0)), 0.5);
			vec4 h3 = textureLod(screen_texture, clamp(SCREEN_UV + vec2(-wd.x, -wd.y), vec2(0.0), vec2(1.0)), 0.5);
			vec3 halo_accum = (
				max(unpremul_raw(h0) - vec3(hdr_threshold), vec3(0.0)) * h0.a +
				max(unpremul_raw(h1) - vec3(hdr_threshold), vec3(0.0)) * h1.a +
				max(unpremul_raw(h2) - vec3(hdr_threshold), vec3(0.0)) * h2.a +
				max(unpremul_raw(h3) - vec3(hdr_threshold), vec3(0.0)) * h3.a
			) * 0.25;
			vec3 hdr_wrap = (hdr_wrap_accum * 0.0625 + halo_accum * 0.45) * hdr_light_wrap_strength;
			c.rgb += hdr_wrap * c.a;
			float halo_luma = max(halo_accum.r, max(halo_accum.g, halo_accum.b)) * hdr_light_wrap_strength;
			if (c.a < 0.99 && halo_luma > 0.005) {
				float outer_halo_a = clamp(halo_luma * 0.45, 0.0, 0.65) * (1.0 - c.a);
				c.rgb = mix(c.rgb, halo_accum * 1.15, clamp(outer_halo_a / max(c.a + outer_halo_a, 0.0001), 0.0, 1.0));
				c.a = max(c.a, outer_halo_a);
			}
		}
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

	// --- 3.5 CAS (Contrast Adaptive Sharpening) protegido por alfa ---
	if (cas_sharpen_strength > 0.005 && orig_c_a > 0.85) {
		vec4 cn_e = textureLod(screen_texture, clamp(SCREEN_UV + vec2(px.x, 0.0), vec2(0.0), vec2(1.0)), 0.0);
		vec4 cn_w = textureLod(screen_texture, clamp(SCREEN_UV - vec2(px.x, 0.0), vec2(0.0), vec2(1.0)), 0.0);
		vec4 cn_s = textureLod(screen_texture, clamp(SCREEN_UV + vec2(0.0, px.y), vec2(0.0), vec2(1.0)), 0.0);
		vec4 cn_n = textureLod(screen_texture, clamp(SCREEN_UV - vec2(0.0, px.y), vec2(0.0), vec2(1.0)), 0.0);
		float min_na = min(min(cn_e.a, cn_w.a), min(cn_s.a, cn_n.a));
		float interior_guard = smoothstep(0.82, 0.96, min_na);
		if (interior_guard > 0.01) {
			vec3 ce = unpremul_raw(cn_e);
			vec3 cw = unpremul_raw(cn_w);
			vec3 cs = unpremul_raw(cn_s);
			vec3 cn = unpremul_raw(cn_n);
			vec3 mn = min(c.rgb, min(min(ce, cw), min(cs, cn)));
			vec3 mx = max(c.rgb, max(max(ce, cw), max(cs, cn)));
			vec3 amp = sqrt(clamp(min(mn, max(vec3(2.0) - mx, vec3(0.0))) / max(mx, vec3(0.0001)), vec3(0.0), vec3(1.0)));
			float peak = -1.0 / mix(8.0, 5.0, cas_sharpen_strength);
			vec3 w = amp * peak;
			vec3 sharp = (c.rgb + (ce + cw + cs + cn) * w) / max(vec3(1.0) + 4.0 * w, vec3(0.0001));
			c.rgb = mix(c.rgb, max(sharp, vec3(0.0)), cas_sharpen_strength * interior_guard);
		}
	}

	// --- 4. Impact Frames (2 frames: B/N directo -> invertido con rayos radiales) ---
	if (impact_frame_phase > 0 && c.a > 0.05) {
		vec3 srgb_c = pow(clamp(c.rgb, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
		float luma = dot(srgb_c, vec3(0.2126, 0.7152, 0.0722));
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
