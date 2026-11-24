shader_type canvas_item;
render_mode blend_mix;

// Shader de producción ArcSys 2.5D para Close-Ups de Diálogo Vivos (Living Dialogue Portraits).
// Consume Normal Maps 3D reales (Sapiens + Depth-Anything-V2), Depth Map, ID Mask RGB,
// ILM Map (Metal/AO/Hair) y Motion Mask (Respiración/Pelo/Ojo+Monóculo).

#include "res://scenes/pilots/shaders/rig_color_recolor.gdshaderinc"
#include "res://scenes/pilots/shaders/rig_stylized_lighting.gdshaderinc"

uniform sampler2D normal_map : filter_linear;
uniform sampler2D depth_map : hint_default_white, filter_linear;
uniform sampler2D id_mask : hint_default_black, filter_linear;
uniform sampler2D ilm_map : hint_default_white, filter_linear;
uniform sampler2D motion_mask : hint_default_black, filter_linear;

uniform bool has_normal_map = false;
uniform bool has_depth_map = false;
uniform bool has_id_mask = false;
uniform bool has_ilm_map = false;
uniform bool has_motion_mask = false;

uniform bool living_enabled = true;
uniform float anim_time = 0.0;
uniform vec2 mouse_offset = vec2(0.0, 0.0);
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

// Dinámica orgánica Zero-G & Encuadre In-Game
uniform float breath_amp_px = 2.8;
uniform float breath_speed = 1.25;
uniform float hair_sway_amp_px = 3.2;
uniform float parallax_strength = 0.0045;
uniform float bottom_fade_start : hint_range(0.50, 0.99) = 0.86;
uniform float bottom_fade_power : hint_range(0.50, 4.0) = 1.8;

// Iluminación ArcSys 2.5D & Rim-Light Cósmico
uniform vec4 rim_light_color : source_color = vec4(0.58, 0.74, 1.0, 1.0);
uniform float rim_light_strength : hint_range(0.0, 1.5) = 0.56;
uniform float rim_light_angle_deg = -40.0;
uniform float cel_strength : hint_range(0.0, 1.0) = 0.46;
uniform vec4 cel_shadow_tint : source_color = vec4(0.145, 0.145, 0.335, 1.0);
uniform float specular_strength : hint_range(0.0, 1.5) = 0.72;
uniform float ilm_ao_strength : hint_range(0.0, 1.0) = 0.58;
uniform float face_shadow_protect : hint_range(0.0, 1.0) = 0.92;

// Brillo ojo/monóculo & pulso al hablar
uniform float eye_shimmer_strength : hint_range(0.0, 1.5) = 0.32;
uniform float speech_pulse : hint_range(0.0, 1.5) = 0.0;

// Dinámica de turno (1.0 = hablando/foco, 0.0 = escuchando)
uniform float focus_amount : hint_range(0.0, 1.0) = 1.0;
uniform float listening_dim_brightness : hint_range(0.2, 1.0) = 0.58;
uniform float listening_desaturate : hint_range(0.0, 0.85) = 0.25;

// Modo transmisión radio / Comms
uniform float comms_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 comms_tint_color : source_color = vec4(0.42, 0.90, 1.0, 1.0);

// Recoloreo de Skins por ID Mask + ILM Hair
uniform bool skin_recolor_enabled = false;
uniform vec4 skin_accent_color : source_color = vec4(0.86, 0.18, 0.32, 1.0);
uniform vec4 skin_panel_color : source_color = vec4(0.36, 0.38, 0.44, 1.0);
uniform vec4 skin_dark_color : source_color = vec4(0.16, 0.15, 0.20, 1.0);
uniform vec4 skin_hair_color : source_color = vec4(0.86, 0.88, 0.94, 1.0);
uniform bool use_skin_hair_recolor = false;

// Depuración Rayos-X: 0=Final, 1=Albedo, 2=Normal, 3=Depth, 4=ID Mask, 5=ILM Map, 6=Motion Mask
uniform int debug_view_mode = 0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 base_uv = UV;

	vec4 m_raw = has_motion_mask ? texture(motion_mask, base_uv) : vec4(0.0);
	float depth_raw = has_depth_map ? texture(depth_map, base_uv).r : 0.5;

	vec2 final_uv = base_uv;
	if (living_enabled && debug_view_mode != 1) {
		vec2 parallax_uv = (length(mouse_offset) > 0.001) ? mouse_offset * (depth_raw - 0.35) * parallax_strength : vec2(0.0);
		float breath_wave = 0.5 + 0.5 * sin(anim_time * breath_speed);
		vec2 breath_uv = vec2((base_uv.x - 0.5) * -0.0012, 0.0014) * breath_wave * (breath_amp_px * 0.38) * m_raw.r;

		float hair_weight = pow(clamp(m_raw.g, 0.0, 1.0), 1.65);
		float w1 = sin(anim_time * 0.95 + base_uv.y * 1.8);
		float w2 = cos(anim_time * 0.62 + base_uv.x * 1.3);
		vec2 hair_uv = vec2(w1 * 0.80 + w2 * 0.20, w2 * 0.16) * (hair_sway_amp_px * 0.58 * px) * hair_weight;
		final_uv = base_uv + parallax_uv + breath_uv + hair_uv;
	}

	if (final_uv.x < 0.0 || final_uv.x > 1.0 || final_uv.y < 0.0 || final_uv.y > 1.0) {
		discard;
	}

	vec4 tex = texture(TEXTURE, final_uv, -0.55);
	float clean_alpha = smoothstep(0.04, 0.96, tex.a);
	if (clean_alpha < 0.01) {
		discard;
	}

	vec3 n_tex = has_normal_map ? texture(normal_map, final_uv).rgb : vec3(0.5, 0.5, 1.0);
	float d_val = has_depth_map ? texture(depth_map, final_uv).r : 0.5;
	vec4 id_m = has_id_mask ? texture(id_mask, final_uv) : vec4(0.0);
	vec4 ilm_m = has_ilm_map ? texture(ilm_map, final_uv) : vec4(0.22, 0.54, 0.0, 1.0);
	vec4 mot_m = has_motion_mask ? texture(motion_mask, final_uv) : vec4(0.0);

	if (debug_view_mode == 1) {
		COLOR = vec4(tex.rgb, tex.a * fade_alpha);
	} else if (debug_view_mode == 2) {
		COLOR = vec4(srgb_to_linear(clamp(n_tex, vec3(0.0), vec3(1.0))), tex.a * fade_alpha);
	} else if (debug_view_mode == 3) {
		COLOR = vec4(srgb_to_linear(vec3(d_val)), tex.a * fade_alpha);
	} else if (debug_view_mode == 4) {
		vec3 id_vis = clamp(id_m.rgb + vec3(0.55, 0.85, 1.0) * ilm_m.b, vec3(0.0), vec3(1.0));
		COLOR = vec4(srgb_to_linear(id_vis), tex.a * fade_alpha);
	} else if (debug_view_mode == 5) {
		COLOR = vec4(srgb_to_linear(clamp(ilm_m.rgb, vec3(0.0), vec3(1.0))), tex.a * fade_alpha);
	} else if (debug_view_mode == 6) {
		COLOR = vec4(srgb_to_linear(clamp(mot_m.rgb, vec3(0.0), vec3(1.0))), tex.a * fade_alpha);
	} else {
		// Godot ya entrega TEXTURE en Linear bajo hdr_2d=true; convertimos a sRGB para ArcSys/recolor y regresamos a Linear al final.
		vec3 rgb_srgb = linear_to_srgb(max(tex.rgb, vec3(0.0)));
		vec3 orig_srgb = rgb_srgb;
		float orig_luma = dot(rgb_srgb, vec3(0.299, 0.587, 0.114));
		float raw_luma_lin = dot(max(tex.rgb, vec3(0.0)), vec3(0.2126, 0.7152, 0.0722));
		float ink_core = 1.0 - smoothstep(0.05, 0.25, orig_luma);
		float not_ink = 1.0 - ink_core;
		float inner_alpha = smoothstep(0.72, 0.98, tex.a);
		float eye_protect = clamp(mot_m.b, 0.0, 1.0);
		float hair_mat_w = has_ilm_map ? clamp(ilm_m.b, 0.0, 1.0) : 0.0;
		float suit_w = clamp(id_m.b, 0.0, 1.0);
		float panel_w = clamp(id_m.g, 0.0, 1.0);
		float acc_w = clamp(id_m.r, 0.0, 1.0);
		float skin_w = clamp(1.0 - max(max(acc_w, panel_w), max(suit_w, max(hair_mat_w, eye_protect))), 0.0, 1.0);
		bool is_skin = (skin_w > 0.45);
		float is_face = is_skin ? smoothstep(0.39, 0.22, final_uv.y) : 0.0;

		// 1. Recoloreo limpio de Skin por ID Mask RGB + ILM Hair (B)
		if (skin_recolor_enabled && has_id_mask) {
			if (suit_w > 0.05) {
				vec3 r_suit = apply_recolor_algorithm(max(skin_dark_color.rgb, vec3(0.0)), orig_luma, raw_luma_lin, 0.24, 1, 1.06, 0.28, 1.04);
				rgb_srgb = mix(rgb_srgb, linear_to_srgb(r_suit), suit_w * not_ink * 0.92);
			}
			if (panel_w > 0.05) {
				vec3 r_pan = apply_recolor_algorithm(max(skin_panel_color.rgb, vec3(0.0)), orig_luma, raw_luma_lin, 0.44, 1, 1.06, 0.36, 1.04);
				rgb_srgb = mix(rgb_srgb, linear_to_srgb(r_pan), panel_w * not_ink * 0.90);
			}
			if (acc_w > 0.05) {
				vec3 r_acc = apply_recolor_algorithm(max(skin_accent_color.rgb, vec3(0.0)), orig_luma, raw_luma_lin, 0.34, 1, 1.10, 0.42, 1.10);
				rgb_srgb = mix(rgb_srgb, linear_to_srgb(r_acc), acc_w * not_ink * 0.90);
			}
			if (use_skin_hair_recolor && hair_mat_w > 0.08) {
				vec3 r_hair = apply_recolor_algorithm(max(skin_hair_color.rgb, vec3(0.0)), orig_luma, raw_luma_lin, 0.78, 1, 1.04, 0.24, 1.04);
				rgb_srgb = mix(rgb_srgb, linear_to_srgb(r_hair), hair_mat_w * not_ink * 0.88);
			}
		}

		// 2. Vector Normal 3D real (Sapiens + DA-V2) y dirección de luz
		float l_rad = radians(rim_light_angle_deg);
		vec2 light_xy = normalize(vec2(cos(l_rad), sin(l_rad)));
		vec3 n_vec = vec3(0.0, 0.0, 1.0);
		if (has_normal_map) {
			vec3 n_raw = n_tex * 2.0 - 1.0;
			n_vec = normalize(vec3(n_raw.x, n_raw.y, max(n_raw.z, 0.22)));
		} else if (has_depth_map) {
			vec2 d_off = px * 5.0;
			float d_l = texture(depth_map, clamp(final_uv - vec2(d_off.x, 0.0), 0.0, 1.0)).r;
			float d_r = texture(depth_map, clamp(final_uv + vec2(d_off.x, 0.0), 0.0, 1.0)).r;
			float d_u = texture(depth_map, clamp(final_uv - vec2(0.0, d_off.y), 0.0, 1.0)).r;
			float d_d = texture(depth_map, clamp(final_uv + vec2(0.0, d_off.y), 0.0, 1.0)).r;
			n_vec = normalize(vec3((d_l - d_r) * 24.0, (d_u - d_d) * 24.0, 0.70));
		}

		vec3 key_dir = normalize(vec3(light_xy.x * 0.86, light_xy.y * 0.86, 0.50));

		// 3. Cel-Shading ArcSys 2.5D + ILM AO + Protección Facial + Especular + Angel Ring
		if (cel_strength > 0.005) {
			float eff_ao = mix(ilm_m.g, max(ilm_m.g, 0.52), hair_mat_w);
			float ao_bias = (eff_ao - 0.54) * 0.65 * ilm_ao_strength;
			float ndotl_biased = dot(n_vec, key_dir) + ao_bias;
			float ndotl_adj = mix(ndotl_biased, max(ndotl_biased, 0.46), max(is_face * face_shadow_protect, eye_protect));

			float cel_thr = 0.34;
			float lit_mask = smoothstep(cel_thr - 0.04, cel_thr + 0.04, ndotl_adj);
			float mid_mask = smoothstep(cel_thr - 0.28, cel_thr - 0.18, ndotl_adj);
			float shadow_w = (1.0 - lit_mask) * mix(1.0, mix(1.0, 0.54, mid_mask), 0.45);

			vec3 tint_srgb = linear_to_srgb(max(cel_shadow_tint.rgb, vec3(0.0)));
			vec3 hair_sh_tint = mix(tint_srgb, vec3(0.58, 0.62, 0.80), 0.60);
			vec3 sh_tint = is_skin ? vec3(0.85, 0.65, 0.69) : mix(tint_srgb, hair_sh_tint, hair_mat_w);
			vec3 shadow_col = compute_arcsys_shadow_srgb(rgb_srgb, sh_tint, 0.22, orig_luma, is_skin);

			float hair_sh_scale = mix(1.0, 0.62, hair_mat_w);
			float eye_sh_scale = mix(1.0, 0.12, eye_protect);
			float face_sh_scale = 1.0 - is_face * face_shadow_protect * 0.78;
			float cel_mix = shadow_w * cel_strength * hair_sh_scale * eye_sh_scale * face_sh_scale * not_ink * (1.0 - acc_w * 0.65);
			vec3 shaded = mix(rgb_srgb, shadow_col, clamp(cel_mix, 0.0, 0.68));
			// Suave realce en lado iluminado
			shaded = mix(shaded, min(shaded * vec3(1.06, 1.04, 1.02), vec3(1.0)), lit_mask * cel_strength * 0.35 * (1.0 - is_face * 0.6) * not_ink);

			// Banda cálida SSS sutil en borde de sombra sobre piel (busto/brazos/hombros)
			if (is_skin && eye_protect < 0.1) {
				float sss_band = exp(-pow((ndotl_adj - cel_thr) * 9.0, 2.0));
				shaded += vec3(0.97, 0.40, 0.34) * sss_band * 0.12 * cel_strength * (1.0 - is_face * 0.65) * not_ink;
			}

			// Especular metálico (brazales/hombreras) + Angel Ring en cabello plateado
			if (specular_strength > 0.01) {
				vec3 half_v = normalize(key_dir + vec3(0.0, 0.0, 0.85));
				float spec_hard = pow(max(dot(n_vec, half_v), 0.0), 16.0);
				float spec_step = smoothstep(0.36, 0.50, spec_hard);
				shaded += vec3(0.92, 0.96, 1.0) * spec_step * ilm_m.r * specular_strength * 0.38 * lit_mask * not_ink * inner_alpha;

				if (hair_mat_w > 0.20) {
					float crown_band = smoothstep(0.28, 0.08, final_uv.y);
					float angel = smoothstep(0.30, 0.54, spec_hard + crown_band * 0.35) * crown_band;
					shaded += vec3(1.0, 0.99, 1.0) * angel * hair_mat_w * specular_strength * 0.22 * not_ink * inner_alpha;
				}
			}

			rgb_srgb = shaded;
		}

		// 4. Rim-Light Cósmico 3D (Inclinación normal sin(theta) + banda interior 5.5px tras la tinta negra)
		if (rim_light_strength > 0.005) {
			float n_tilt = length(n_vec.xy);
			float n_dir_w = n_tilt > 0.02 ? smoothstep(0.05, 0.68, dot(n_vec.xy / n_tilt, light_xy)) : 0.0;
			float fresnel_rim = smoothstep(0.14, 0.54, n_tilt) * n_dir_w;

			vec2 step_uv = px * 5.5;
			float a_l = texture(TEXTURE, clamp(final_uv - vec2(step_uv.x, 0.0), 0.0, 1.0)).a;
			float a_r = texture(TEXTURE, clamp(final_uv + vec2(step_uv.x, 0.0), 0.0, 1.0)).a;
			float a_u = texture(TEXTURE, clamp(final_uv - vec2(0.0, step_uv.y), 0.0, 1.0)).a;
			float a_d = texture(TEXTURE, clamp(final_uv + vec2(0.0, step_uv.y), 0.0, 1.0)).a;
			float min_nb = min(min(a_l, a_r), min(a_u, a_d));
			float edge_band = clamp(1.0 - smoothstep(0.10, 0.96, min_nb), 0.0, 1.0);
			vec2 sil_out = vec2(a_l - a_r, a_u - a_d);
			float sil_len = length(sil_out);
			float sil_dir = sil_len > 0.02 ? smoothstep(-0.15, 0.68, dot(sil_out / sil_len, light_xy)) : 0.30;

			float rim_pulse = living_enabled ? (0.96 + 0.04 * sin(anim_time * 1.4)) : 1.0;
			float zone_protect = (1.0 - eye_protect * 0.88) * (1.0 - is_face * 0.72) * (not_ink * not_ink) * inner_alpha;
			float rim_mask = clamp(fresnel_rim * 0.75 + edge_band * sil_dir * 0.85, 0.0, 1.0) * rim_light_strength * rim_pulse * zone_protect;
			vec3 rim_srgb = linear_to_srgb(max(rim_light_color.rgb, vec3(0.0)));
			rgb_srgb += rim_srgb * rim_mask * 0.82;
		}

		// 5. Monóculo HUD Táctico + Shimmer Ojo Amatista (protección HSV Invariante #7)
		float active_shimmer = eye_shimmer_strength * 0.38 + speech_pulse * 0.34;
		if (eye_protect > 0.05 && active_shimmer > 0.01) {
			float is_monocle = clamp(acc_w, 0.0, 1.0);
			float is_open_eye = 1.0 - is_monocle;
			float hsv_v = max(rgb_srgb.r, max(rgb_srgb.g, rgb_srgb.b));
			float pupil_guard = smoothstep(0.16, 0.38, hsv_v);

			// Ojo amatista: brillo suave en iris sin lavar pupila ni delineado
			float eye_hi = smoothstep(0.22, 0.66, hsv_v);
			vec3 eye_glow_col = mix(vec3(0.68, 0.45, 1.0), linear_to_srgb(max(rim_light_color.rgb, vec3(0.0))) + vec3(0.18), 0.30);
			rgb_srgb += eye_glow_col * eye_protect * is_open_eye * pupil_guard * eye_hi * active_shimmer * 0.42;

			// Monóculo rojo: barrido scanner táctico sutil
			float scan_line = 0.5 + 0.5 * sin(final_uv.y * 520.0 - anim_time * 6.5);
			float sweep = exp(-pow(fract(final_uv.y * 12.0 - anim_time * 0.55) - 0.5, 2.0) * 18.0);
			vec3 mono_col = skin_recolor_enabled ? linear_to_srgb(max(skin_accent_color.rgb, vec3(0.0))) * 1.35 : vec3(1.25, 0.32, 0.46);
			rgb_srgb += mono_col * eye_protect * is_monocle * (scan_line * 0.14 + sweep * 0.35) * active_shimmer * not_ink;
		}

		// 6. Modo Transmisión Radio / Comms
		if (comms_amount > 0.005) {
			float scan = 0.5 + 0.5 * sin(base_uv.y * 420.0 + anim_time * 12.0);
			float scan_mod = mix(1.0, 0.78 + 0.22 * scan, comms_amount);
			float flicker = living_enabled ? (0.96 + 0.04 * sin(anim_time * 27.0) * sin(anim_time * 11.3)) : 1.0;
			vec3 holo_tint = linear_to_srgb(max(comms_tint_color.rgb, vec3(0.0)));
			float luma_c = dot(rgb_srgb, vec3(0.299, 0.587, 0.114));
			vec3 comms_rgb = mix(rgb_srgb, mix(rgb_srgb * holo_tint * 1.25, holo_tint * (0.25 + luma_c * 0.85), 0.32), comms_amount * 0.52);
			rgb_srgb = comms_rgb * scan_mod * mix(1.0, flicker, comms_amount);
		}

		// Protección integral de trazos/outlines anime antes de turno y grade
		rgb_srgb = mix(rgb_srgb, orig_srgb * 0.90, ink_core * 0.88);

		// 7. Dinámica de turno (Hablando vs Escuchando)
		float dim_k = mix(listening_dim_brightness, 1.0, focus_amount);
		float desat_k = mix(listening_desaturate, 0.0, focus_amount);
		float l_turn = dot(rgb_srgb, vec3(0.299, 0.587, 0.114));
		rgb_srgb = mix(rgb_srgb, vec3(l_turn), desat_k) * dim_k;

		vec3 hdr_excess = max(rgb_srgb - vec3(1.0), vec3(0.0));
		vec3 graded = apply_cinematic_grade_srgb(clamp(rgb_srgb, vec3(0.0), vec3(1.0)), 1.04, 1.03);
		vec3 out_lin = srgb_to_linear(graded) + hdr_excess;

		float bottom_fade = 1.0;
		if (base_uv.y > bottom_fade_start) {
			float t_fade = clamp((base_uv.y - bottom_fade_start) / max(1.0 - bottom_fade_start, 0.001), 0.0, 1.0);
			bottom_fade = pow(1.0 - t_fade, bottom_fade_power);
		}

		COLOR = vec4(out_lin, clean_alpha * fade_alpha * bottom_fade);
	}
}
