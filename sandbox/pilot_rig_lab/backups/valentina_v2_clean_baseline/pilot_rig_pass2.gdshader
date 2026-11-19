shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

// 1. Outline exterior unificado de la silueta completa (cuerpo + cabeza)
uniform bool enable_outer_outline = false;
uniform float outer_outline_width_px : hint_range(0.0, 8.0) = 0.65;
uniform float outer_outline_strength : hint_range(0.0, 1.0) = 0.0;
uniform float outline_inward_replace : hint_range(0.0, 1.0) = 0.95;
uniform float outline_crispness : hint_range(0.1, 1.0) = 0.25;
uniform vec4 outer_outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 outer_outline_lit_color : source_color = vec4(0.11, 0.035, 0.07, 1.0);
uniform float outer_outline_tint_mix : hint_range(0.0, 1.0) = 0.0;
uniform float zoom_scale : hint_range(0.35, 4.0) = 1.0;
uniform vec2 light_dir_2d = vec2(-0.58, -0.81);

// Soldador morfológico, Light-Wrap HDR y Rotated Poisson IGN
uniform float seam_weld_radius_px : hint_range(0.5, 2.5) = 1.35;
uniform float seam_bridge_threshold : hint_range(0.3, 0.9) = 0.62;
uniform float hdr_threshold : hint_range(1.0, 1.5) = 1.08;
uniform float hdr_light_wrap_strength : hint_range(0.0, 1.0) = 0.42;
uniform float ign_jitter_strength : hint_range(0.0, 1.0) = 0.85;

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

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec4 c0_raw = textureLod(screen_texture, SCREEN_UV, 0.0);
	vec4 c = vec4(unpremul_raw(c0_raw), c0_raw.a);
	float orig_c_a = c.a;

	// --- 1. Anillo 1 compartido (8 taps a 1.35 px) + Anillo 2 condicional (8 taps Poisson IGN) ---
	// Purgado temporalmente para rework de bordes/rims
	if (false && enable_outer_outline) {
		float zc = clamp(zoom_scale, 0.35, 4.0);
		float zoom_eff = pow(zc, 0.60);
		float base_px = outer_outline_width_px * zoom_eff;
		float w_min = max(0.60 * base_px, 0.55);
		float w_max = max(1.10 * base_px, 0.85);
		float r1 = seam_weld_radius_px;

		// 4 ejes diametralmente opuestos: E/W, N/S, SE/NW, SW/NE
		vec2 o_e  = vec2(r1, 0.0) * px;
		vec2 o_s  = vec2(0.0, r1) * px;
		vec2 o_se = vec2(r1 * 0.70710678, r1 * 0.70710678) * px;
		vec2 o_sw = vec2(-r1 * 0.70710678, r1 * 0.70710678) * px;

		vec4 s_e  = textureLod(screen_texture, clamp(SCREEN_UV + o_e,  vec2(0.0), vec2(1.0)), 0.0);
		vec4 s_w  = textureLod(screen_texture, clamp(SCREEN_UV - o_e,  vec2(0.0), vec2(1.0)), 0.0);
		vec4 s_s  = textureLod(screen_texture, clamp(SCREEN_UV + o_s,  vec2(0.0), vec2(1.0)), 0.0);
		vec4 s_n  = textureLod(screen_texture, clamp(SCREEN_UV - o_s,  vec2(0.0), vec2(1.0)), 0.0);
		vec4 s_se = textureLod(screen_texture, clamp(SCREEN_UV + o_se, vec2(0.0), vec2(1.0)), 0.0);
		vec4 s_nw = textureLod(screen_texture, clamp(SCREEN_UV - o_se, vec2(0.0), vec2(1.0)), 0.0);
		vec4 s_sw = textureLod(screen_texture, clamp(SCREEN_UV + o_sw, vec2(0.0), vec2(1.0)), 0.0);
		vec4 s_ne = textureLod(screen_texture, clamp(SCREEN_UV - o_sw, vec2(0.0), vec2(1.0)), 0.0);

		// Soldador morfológico de oposición bipolar (sin taps extra)
		float pair_ew   = min(s_e.a,  s_w.a);
		float pair_ns   = min(s_s.a,  s_n.a);
		float pair_senw = min(s_se.a, s_nw.a);
		float pair_swne = min(s_sw.a, s_ne.a);
		float max_pair_bridge = max(max(pair_ew, pair_ns), max(pair_senw, pair_swne));

		bool is_micro_crack = (c.a < 0.98) && (max_pair_bridge > 0.80);
		if (c.a < 0.99 && max_pair_bridge > c.a && max_pair_bridge > seam_bridge_threshold * 0.6) {
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

		// Estadísticas Anillo 1, Sobel (n_edge / t_dir) y Laplaciano de curvatura
		float max_a1 = max(c.a, max(max(max(s_e.a, s_w.a), max(s_s.a, s_n.a)), max(max(s_se.a, s_nw.a), max(s_sw.a, s_ne.a))));
		float min_a1 = min(c.a, min(min(min(s_e.a, s_w.a), min(s_s.a, s_n.a)), min(min(s_se.a, s_nw.a), min(s_sw.a, s_ne.a))));

		float gx = (s_ne.a + 2.0 * s_e.a + s_se.a) - (s_nw.a + 2.0 * s_w.a + s_sw.a);
		float gy = (s_sw.a + 2.0 * s_s.a + s_se.a) - (s_nw.a + 2.0 * s_n.a + s_ne.a);
		vec2 grad_a = vec2(gx, gy);
		vec2 n_edge = length(grad_a) > 0.0001 ? -normalize(grad_a) : vec2(1.0, 0.0);
		vec2 t_dir = vec2(-n_edge.y, n_edge.x);
		float laplacian = (s_e.a + s_w.a + s_s.a + s_n.a) * 0.25 - c.a;
		float concavity = clamp(laplacian * 1.5, -0.5, 0.8);

		// Acumuladores continuos (distancia sub-píxel, color vecino LDR y Light-Wrap HDR)
		float min_dist_px = c.a > 0.5 ? 0.0 : 100.0;
		vec3 nearest_ldr_rgb = vec3(0.0);
		float nearest_w_sum = 0.0;
		vec3 hdr_wrap_accum = vec3(0.0);

		vec4 ring1_taps[8] = vec4[8](s_e, s_w, s_s, s_n, s_se, s_nw, s_sw, s_ne);
		for (int i = 0; i < 8; i++) {
			vec4 tap = ring1_taps[i];
			if (tap.a > 0.15) {
				float d_edge = max(r1 - (tap.a - 0.5) * 0.75, 0.0);
				min_dist_px = min(min_dist_px, d_edge);
				vec3 up_tap = unpremul_raw(tap);
				float wt = tap.a * tap.a;
				nearest_ldr_rgb += min(up_tap, vec3(1.0)) * wt;
				nearest_w_sum += wt;
				hdr_wrap_accum += max(up_tap - vec3(hdr_threshold), vec3(0.0)) * tap.a;
			}
		}

		// Anillo 2 condicional (8 taps Rotated Poisson con IGN estirado 1.15x sobre tangente a LOD 0.5)
		if (min_a1 < 0.98 && !is_micro_crack) {
			float coarse_a = textureLod(screen_texture, SCREEN_UV, 1.5).a;
			if (coarse_a > 0.005 || max_a1 > 0.005) {
				float noise = ign(FRAGCOORD.xy) * 6.2831853 * ign_jitter_strength;
				float cn = cos(noise);
				float sn = sin(noise);
				mat2 rot = mat2(vec2(cn, sn), vec2(-sn, cn));
				const vec2 POISSON_8[8] = vec2[](
					vec2( 0.9239,  0.3827), vec2(-0.9239, -0.3827),
					vec2( 0.3827, -0.9239), vec2(-0.3827,  0.9239),
					vec2( 0.6533,  0.2706), vec2(-0.6533, -0.2706),
					vec2(-0.2706,  0.6533), vec2( 0.2706, -0.6533)
				);
				float ring2_r = max(w_max, base_px);
				for (int i = 0; i < 8; i++) {
					vec2 p = rot * POISSON_8[i];
					vec2 off_px = (n_edge * p.x + t_dir * (p.y * 1.15)) * ring2_r;
					vec2 tap_uv = clamp(SCREEN_UV + off_px * px, vec2(0.0), vec2(1.0));
					vec4 s_tap = textureLod(screen_texture, tap_uv, 0.5);
					if (s_tap.a > 0.15) {
						float d_tap = max(length(off_px) - (s_tap.a - 0.5) * 0.75, 0.0);
						min_dist_px = min(min_dist_px, d_tap);
						vec3 up_tap = unpremul_raw(s_tap);
						float wt = s_tap.a * s_tap.a;
						nearest_ldr_rgb += min(up_tap, vec3(1.0)) * wt;
						nearest_w_sum += wt;
						hdr_wrap_accum += max(up_tap - vec3(hdr_threshold), vec3(0.0)) * s_tap.a;
					}
				}
			}
		}

		// Light-Wrap HDR entre piezas
		vec3 hdr_wrap = (hdr_wrap_accum * 0.0625) * hdr_light_wrap_strength;
		c.rgb += hdr_wrap * c.a;

		// Grosor caligráfico y Colored Line Art (solo activo cuando outer_outline_tint_mix > 0)
		vec2 light_n = length(light_dir_2d) > 0.001 ? normalize(light_dir_2d) : vec2(-0.58, -0.81);
		float edge_dot_l = dot(n_edge, light_n);
		float callig_t = smoothstep(-0.55, 0.65, -edge_dot_l);
		float callig_width_px = clamp(mix(w_min, w_max, callig_t) + concavity * 0.35, w_min, w_max);
		float target_width_px = mix(base_px, callig_width_px, outer_outline_tint_mix);

		float aa_band = clamp(outline_crispness, 0.12, 0.65);
		float outline_cov = smoothstep(target_width_px + aa_band, max(target_width_px - aa_band, 0.0), min_dist_px) * outer_outline_strength;
		vec3 avg_ldr = nearest_w_sum > 0.0001 ? (nearest_ldr_rgb / nearest_w_sum) : outer_outline_color.rgb;
		vec3 colored_ink = pow(clamp(avg_ldr, vec3(0.0), vec3(1.0)), vec3(1.6)) * mix(outer_outline_lit_color.rgb * 0.9, vec3(0.18), 0.55);
		float lit_align = smoothstep(0.05, 0.78, edge_dot_l);
		vec3 callig_col = mix(colored_ink, outer_outline_lit_color.rgb * 0.45 + avg_ldr * 0.08, lit_align * 0.45);
		vec3 final_outline_col = mix(outer_outline_color.rgb, callig_col, outer_outline_tint_mix);

		// Reemplazo del borde del PNG: cubre tanto el halo exterior como el primer ~1px interior sucio
		float inward_edge_mask = (1.0 - smoothstep(0.15, 0.92, min_a1)) * outline_inward_replace * outer_outline_strength;
		if (c.a < 0.99 || inward_edge_mask > 0.01) {
			float fg_w = smoothstep(0.35, 0.90, c.a) * (1.0 - inward_edge_mask);
			vec3 composed_rgb = mix(final_outline_col, c.rgb, fg_w);
			float outline_blend = max(outline_cov, max(inward_edge_mask, smoothstep(0.28, 0.65, c.a) * outer_outline_strength));
			c.rgb = c.a < 0.01 ? final_outline_col : mix(c.rgb, composed_rgb, outline_blend);
			c.a = max(c.a, outline_cov);
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
