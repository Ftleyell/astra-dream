shader_type canvas_item;
// Shader Live Banner 2.5D — Pasada 1 (Estándar ArcSys Razor Sharp + Ojo Amatista Profundo).
// Se combina con pilot_rig_pass2.gdshader sobre UnifiedBannerGroup (CanvasGroup) para obtener
// el mismo contorno exterior caligráfico, soldador de costuras, CAS Sharpen e Impact Frames del rig de combate.

#include "res://sandbox/pilot_rig_lab/shaders/rig_color_recolor.gdshaderinc"
#include "res://sandbox/pilot_rig_lab/shaders/rig_stylized_lighting.gdshaderinc"

uniform sampler2D motion_mask : hint_default_black;
uniform sampler2D fx_mask : hint_default_black;
uniform sampler2D depth_map : hint_default_white;
uniform sampler2D normal_map : hint_normal;
uniform sampler2D ink_sdf : hint_default_white, filter_linear;

uniform bool has_motion_mask = false;
uniform bool has_fx_mask = false;
uniform bool has_depth_map = false;
uniform bool has_normal_map = false;
uniform bool has_ink_sdf = false;

uniform float anim_time = 0.0;
uniform vec2 mouse_offset = vec2(0.0, 0.0);
uniform vec2 jiggle_offset = vec2(0.0, 0.0);
uniform float blink_amount : hint_range(0.0, 1.0) = 0.0;

uniform vec2 chest_center_uv = vec2(0.4969, 0.2736);
uniform float breath_speed = 1.45;
uniform float breath_expand_amp = 0.008;
uniform float breath_lift_px = 2.2;

uniform float hair_sway_speed = 1.85;
uniform float hair_sway_amp_px = 4.2;
uniform float hair_wave_freq = 9.5;

uniform float body_sway_speed = 0.85;
uniform float body_sway_amp_px = 2.2;

// Ojo Amatista Profundo (Invariante #7) + Monóculo HUD (calibrados a Valentina v2)
uniform vec2 eye_center_uv = vec2(0.4625, 0.1290);
uniform vec4 eye_almond_bounds_uv = vec4(0.4430, 0.1152, 0.4810, 0.1322);
uniform vec4 monocle_bounds_uv = vec4(0.5000, 0.1120, 0.5506, 0.1491);
uniform float eye_glow_boost = 0.45;
uniform float eye_track_amp_px = 1.2;

uniform float mouse_parallax_strength = 0.0;
uniform float rim_light_strength = 0.55;
uniform vec4 rim_light_color : source_color = vec4(0.87, 0.95, 1.0, 1.0);
uniform float emissive_pulse_speed = 2.4;
uniform float emissive_boost = 0.42;

// Estilo Combate ArcSys (02_valentina_razor_sharp)
uniform bool cel_shading_enabled = true;
uniform float cel_strength : hint_range(0.0, 1.0) = 0.34;
uniform float cel_light_angle_deg = -40.0;
uniform vec4 cel_shadow_tint : source_color = vec4(0.145, 0.145, 0.335, 1.0);
uniform float cel_specular_strength : hint_range(0.0, 1.5) = 0.65;

uniform bool ink_sdf_enabled = false;
uniform float ink_strength : hint_range(0.0, 1.0) = 0.72;
uniform float ink_width_bias : hint_range(-0.15, 0.15) = -0.04;
uniform vec4 ink_color : source_color = vec4(0.055, 0.055, 0.13, 1.0);

uniform bool skin_recolor_enabled = false;
uniform vec4 skin_accent_color : source_color = vec4(0.86, 0.18, 0.32, 1.0);
uniform vec4 skin_hair_color : source_color = vec4(0.82, 0.85, 0.92, 1.0);

uniform bool is_arm_layer = false;
uniform float arm_depth_shade = 0.0;
uniform float wings_light_intensity : hint_range(0.0, 2.5) = 0.0;
uniform vec4 wings_light_color : source_color = vec4(1.0, 0.16, 0.32, 1.0);
uniform float hair_burst_lift = 0.0;
uniform int debug_view_mode = 0; // 0=Final, 1=Motion, 2=FX, 3=Depth, 4=Normal, 5=InkSDF

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 base_uv = UV;

	vec4 m_mask = has_motion_mask ? texture(motion_mask, base_uv) : vec4(0.0);
	vec4 f_mask = has_fx_mask ? texture(fx_mask, base_uv) : vec4(0.0);
	float depth_val = has_depth_map ? texture(depth_map, base_uv).r : 0.5;

	if (debug_view_mode == 1) {
		COLOR = vec4(m_mask.rgb, 1.0);
	} else if (debug_view_mode == 2) {
		COLOR = vec4(f_mask.rgb, 1.0);
	} else if (debug_view_mode == 3) {
		COLOR = vec4(vec3(depth_val), 1.0);
	} else if (debug_view_mode == 4) {
		COLOR = vec4(has_normal_map ? texture(normal_map, base_uv).rgb : vec3(0.5, 0.5, 1.0), 1.0);
	} else if (debug_view_mode == 5) {
		float sdf_dbg = has_ink_sdf ? textureLod(ink_sdf, base_uv, 0.0).r : 1.0;
		float ink_dbg = 1.0 - smoothstep(0.47 + ink_width_bias, 0.53 + ink_width_bias, sdf_dbg);
		COLOR = vec4(vec3(1.0 - ink_dbg), 1.0);
	} else {
		// 1. Respiración sutil en busto/torso (100% interior)
		float chest_dist = length((base_uv - chest_center_uv) * vec2(1.45, 1.15));
		float chest_focus = exp(-chest_dist * chest_dist * 6.5);
		float breath_phase = sin(anim_time * breath_speed);
		float breath_weight = is_arm_layer ? 0.0 : (m_mask.r * chest_focus);

		vec2 to_chest = base_uv - chest_center_uv;
		vec2 breath_uv_off = -to_chest * (breath_phase * breath_expand_amp * breath_weight);
		breath_uv_off.y += breath_phase * (breath_lift_px * px.y) * breath_weight;
		vec2 jiggle_uv_off = -jiggle_offset * (0.55 * breath_weight);

		// 2. Cabello Zero-G + salto ascendente al abrir las alas
		float hair_w = is_arm_layer ? 0.0 : m_mask.g;
		float wave_a = sin(anim_time * hair_sway_speed + base_uv.y * hair_wave_freq + base_uv.x * 4.0);
		float wave_b = cos(anim_time * (hair_sway_speed * 0.67) - base_uv.x * (hair_wave_freq * 0.7));
		float hair_side = sign(base_uv.x - 0.50);
		vec2 wing_wind_uv = vec2(-hair_side * hair_burst_lift * 12.0 * px.x, hair_burst_lift * 24.0 * px.y);
		vec2 hair_uv_off = (vec2(
			(wave_a * 0.75 + wave_b * 0.25) * hair_sway_amp_px * px.x,
			wave_b * (hair_sway_amp_px * 0.35) * px.y
		) + wing_wind_uv) * hair_w;

		// 3. Sin desplazamiento UV horizontal en cuerpo (soldadura 100% fija entre hombrera y brazo libre)
		vec2 final_uv = base_uv + breath_uv_off + jiggle_uv_off + hair_uv_off;
		if (final_uv.x < 0.0 || final_uv.x > 1.0 || final_uv.y < 0.0 || final_uv.y > 1.0) {
			discard;
		}

		vec4 tex = texture(TEXTURE, final_uv);
		if (tex.a < 0.01) {
			discard;
		}

		vec3 base_rgb = linear_to_srgb(tex.rgb);
		float orig_luma = dot(base_rgb, vec3(0.299, 0.587, 0.114));

		// Materiales desde FX Mask (R=traje, G=monóculo/trim, B=almendra ojo) y Motion Mask (G=pelo)
		float eye_w = is_arm_layer ? 0.0 : (has_fx_mask ? f_mask.b : 0.0);
		float suit_w = has_fx_mask ? f_mask.r : 0.0;
		float emissive_w = has_fx_mask ? f_mask.g : 0.0;
		float hair_mat_w = has_motion_mask ? smoothstep(0.15, 0.45, m_mask.g) : 0.0;
		float skin_w = clamp(1.0 - max(max(suit_w, hair_mat_w), max(emissive_w, eye_w)), 0.0, 1.0);
		bool is_skin = (skin_w > 0.5);

		vec3 rgb = base_rgb;

		// Recolor por Skin Preset de Valentina v2
		if (skin_recolor_enabled) {
			if (emissive_w > 0.15) {
				float val = max(rgb.r, max(rgb.g, rgb.b));
				rgb = mix(rgb, skin_accent_color.rgb * max(val, 0.22) * 1.18, emissive_w * 0.85);
			}
			if (hair_mat_w > 0.25) {
				rgb = mix(rgb, skin_hair_color.rgb * (orig_luma * 1.15), hair_mat_w * 0.55);
			}
		}

		// =========================================================================
		// 4. OJO AMATISTA PROFUNDO FIEL AL ARTE BASE + PÁRPADO ARQUEADO (FACE LAB)
		// =========================================================================
		float eyelid_cover = 0.0;
		float eye_lash_ink = 0.0;
		if (eye_w > 0.05) {
			vec2 almond_min = eye_almond_bounds_uv.xy;
			vec2 almond_max = eye_almond_bounds_uv.zw;
			vec2 almond_sz = max(almond_max - almond_min, vec2(0.001));
			vec2 eye_uv = clamp((final_uv - almond_min) / almond_sz, vec2(0.0), vec2(1.0));

			// Preservar el dibujo original nítido del ojo y realzar el iris Amatista Profundo
			float iris_detect = smoothstep(0.06, 0.20, rgb.b - rgb.g) * eye_w;
			float hsv_val = max(rgb.r, max(rgb.g, rgb.b));
			// Protección HSV (Invariante #7): conserva pupila #100816 y delineado oscuro intactos
			float pupil_guard = smoothstep(0.18, 0.42, hsv_val);

			vec2 iris_rad = vec2(0.013, 0.009);
			vec2 iris_d = (final_uv - eye_center_uv) / iris_rad;
			float iris_y = clamp(iris_d.y * 0.5 + 0.5, 0.0, 1.0);

			if (iris_detect > 0.05) {
				// Realce cromático hacia paleta canónica #421D70 -> #8B5CF6 -> #DFC4FF
				vec3 col_top = vec3(0.259, 0.114, 0.439);
				vec3 col_mid = vec3(0.545, 0.361, 0.965);
				vec3 col_bot = vec3(0.875, 0.769, 1.000);
				vec3 target_amethyst = mix(col_top, col_mid, smoothstep(0.15, 0.58, iris_y));
				target_amethyst = mix(target_amethyst, col_bot, smoothstep(0.58, 0.92, iris_y));

				rgb = mix(rgb, target_amethyst * max(hsv_val, 0.38) * 1.12, iris_detect * pupil_guard * 0.62);

				// Media luna luminosa táctica en la mitad inferior del iris
				float lower_crescent = smoothstep(0.52, 0.82, iris_y) * iris_detect * pupil_guard;
				rgb += col_bot * lower_crescent * eye_glow_boost * 0.34;
			}

			// Dos micro-catchlights nítidos alineados al centro real del iris (sutiles sin tapar arte)
			float s1 = (1.0 - smoothstep(0.14, 0.24, length((iris_d - vec2(-0.30, -0.28)) * vec2(1.0, 1.15)))) * eye_w;
			float s2 = (1.0 - smoothstep(0.08, 0.16, length(iris_d - vec2(0.32, 0.32)))) * 0.55 * eye_w;
			float catch_w = clamp(max(s1, s2), 0.0, 1.0) * (1.0 - step(0.95, 1.0 - iris_detect * 0.6));
			rgb = mix(rgb, vec3(1.14, 1.12, 1.20), catch_w * 0.78);

			// Parpadeo anatómico por barrido descendente del párpado superior (piel #E3B2A6 + pestaña #160D1A)
			if (blink_amount > 0.005) {
				float arch = (eye_uv.x - 0.5) * (eye_uv.x - 0.5) * 0.35;
				float sweep_y = blink_amount * 1.12 - arch * (1.0 - blink_amount * 0.65);
				eyelid_cover = (1.0 - smoothstep(sweep_y - 0.06, sweep_y + 0.04, eye_uv.y)) * eye_w;
				float lash_band = exp(-pow((eye_uv.y - sweep_y) / 0.085, 2.0)) * smoothstep(0.05, 0.25, blink_amount) * eye_w;
				eye_lash_ink = clamp(lash_band, 0.0, 1.0);
				vec3 lid_skin = mix(vec3(0.890, 0.698, 0.651), vec3(0.796, 0.588, 0.561), smoothstep(0.0, 0.85, eye_uv.y));
				rgb = mix(rgb, lid_skin, eyelid_cover);
				rgb = mix(rgb, vec3(0.086, 0.051, 0.102), eye_lash_ink * 0.96);
			}
		}

		// =========================================================================
		// 5. MONÓCULO TÁCTICO HUD VIVO (ESTILO FACE LAB)
		// =========================================================================
		bool in_monocle_box = (final_uv.x >= monocle_bounds_uv.x && final_uv.x <= monocle_bounds_uv.z
			&& final_uv.y >= monocle_bounds_uv.y && final_uv.y <= monocle_bounds_uv.w);
		float monocle_w = (in_monocle_box && !is_arm_layer) ? emissive_w : 0.0;
		if (monocle_w > 0.15) {
			vec2 m_uv = clamp((final_uv - monocle_bounds_uv.xy) / max(monocle_bounds_uv.zw - monocle_bounds_uv.xy, vec2(0.001)), vec2(0.0), vec2(1.0));
			float scan = 0.5 + 0.5 * sin(m_uv.y * 42.0 - anim_time * 7.5);
			float sweep_pos = fract(anim_time * 0.34);
			float sweep_band = exp(-pow((m_uv.y - sweep_pos) / 0.11, 2.0));
			float reticle_d = length(m_uv - vec2(0.50, 0.50));
			float reticle_ring = exp(-pow((reticle_d - 0.30) / 0.055, 2.0));
			vec3 hud_col = skin_recolor_enabled ? (skin_accent_color.rgb * 1.45) : vec3(1.35, 0.32, 0.48);
			float activity = 0.55 + wings_light_intensity * 0.55;
			rgb += hud_col * (scan * 0.08 + sweep_band * 0.24 + reticle_ring * 0.22) * monocle_w * activity;
		}

		// =========================================================================
		// 6. CEL-SHADING 2.5D ARCSYS (02_valentina_razor_sharp)
		// =========================================================================
		vec3 n_vec = vec3(0.0, 0.0, 1.0);
		if (has_normal_map) {
			vec3 n_raw = texture(normal_map, final_uv).rgb * 2.0 - 1.0;
			n_vec = normalize(vec3(n_raw.x, n_raw.y, max(n_raw.z, 0.20)));
		}

		if (cel_shading_enabled && has_normal_map && cel_strength > 0.01) {
			float l_rad = radians(cel_light_angle_deg) + mouse_offset.x * 0.12;
			vec3 key_dir = normalize(vec3(cos(l_rad), sin(l_rad), 0.76));
			float ndotl = dot(n_vec, key_dir);

			// Protección facial (face_shadow_protect = 0.92): rostro y ojo siempre limpios y luminosos
			float is_face = is_skin ? smoothstep(0.20, 0.13, final_uv.y) : 0.0;
			float ndotl_adj = mix(ndotl, max(ndotl, 0.26), max(is_face * 0.90, eye_w));

			float cel_lit = smoothstep(0.06, 0.18, ndotl_adj);
			float cel_mid = smoothstep(-0.12, 0.06, ndotl_adj);

			vec3 sh_tint = is_skin ? vec3(0.86, 0.66, 0.70) : cel_shadow_tint.rgb;
			vec3 shadow_col = compute_arcsys_shadow_srgb(rgb, sh_tint, 0.42, orig_luma, is_skin);
			vec3 mid_col = mix(shadow_col, rgb, 0.58);
			vec3 lit_col = rgb * vec3(1.04, 1.02, 0.98);

			vec3 shaded = mix(shadow_col, mid_col, cel_mid * 0.42);
			shaded = mix(shaded, lit_col, cel_lit);

			if (is_skin && eye_w < 0.1) {
				float sss_band = exp(-pow((ndotl_adj - 0.11) * 9.0, 2.0));
				shaded += vec3(0.97, 0.40, 0.34) * sss_band * 0.10 * cel_strength;
			}

			if (cel_specular_strength > 0.01) {
				vec3 half_v = normalize(key_dir + vec3(0.0, 0.0, 1.0));
				float spec = pow(max(dot(n_vec, half_v), 0.0), 24.0);
				float spec_step = smoothstep(0.38, 0.50, spec);
				shaded += vec3(0.88, 0.94, 1.0) * spec_step * suit_w * cel_specular_strength * 0.28 * cel_lit;
				if (hair_mat_w > 0.25) {
					float angel = smoothstep(0.46, 0.66, spec) * smoothstep(0.16, 0.07, final_uv.y);
					shaded += vec3(1.0, 0.98, 1.0) * angel * hair_mat_w * 0.24;
				}
			}

			rgb = mix(rgb, shaded, cel_strength * (1.0 - max(emissive_w * 0.75, eye_w * 0.92)));
		}

		// Sombreado sutil de profundidad 2.5D en el brazo libre
		if (is_arm_layer && abs(arm_depth_shade) > 0.001) {
			rgb *= (1.0 + arm_depth_shade);
		}

		// =========================================================================
		// 7. CONTRA-LUZ DIRECCIONAL SIMÉTRICA DE LAS ALAS (CERO MANCHA ROJA!)
		// =========================================================================
		if (wings_light_intensity > 0.01 && has_normal_map) {
			float side_sgn = mix(-1.0, 1.0, step(0.50, final_uv.x));
			vec2 wing_dir = normalize(vec2(side_sgn * 0.92, -0.38));

			float grazing = pow(clamp(1.0 - max(n_vec.z, 0.0), 0.0, 1.0), 3.0);
			float dir_face = smoothstep(0.35, 0.72, dot(n_vec.xy, wing_dir));
			float wing_slice = smoothstep(0.16, 0.34, grazing * dir_face);

			// Proteger rostro, pecho y abdomen central de cualquier mancha roja
			float outside_core = smoothstep(0.09, 0.19, abs(final_uv.x - 0.50));
			float hair_top_ok = hair_mat_w * smoothstep(0.12, 0.05, final_uv.y);
			float zone_allow = max(outside_core, hair_top_ok) * smoothstep(0.95, 0.12, final_uv.y);

			vec3 w_col = skin_recolor_enabled ? skin_accent_color.rgb : wings_light_color.rgb;
			rgb += w_col * wing_slice * zone_allow * wings_light_intensity * 1.15;
		}

		// Pulso suave en paneles carmesí del traje (monóculo ya tiene su HUD propio arriba)
		if (emissive_w > 0.15 && monocle_w < 0.1) {
			float pulse = 0.75 + 0.25 * sin(anim_time * emissive_pulse_speed);
			rgb += rgb * emissive_w * emissive_boost * pulse * (0.45 + wings_light_intensity * 0.35);
		}

		// =========================================================================
		// 8. TINTA INTERNA RAZOR-SHARP SDF (CON PROTECCIÓN HSV PARA OJO AMATISTA!)
		// =========================================================================
		if (ink_sdf_enabled && has_ink_sdf && ink_strength > 0.01) {
			vec2 uv_dx = dFdx(final_uv) / px;
			vec2 uv_dy = dFdy(final_uv) / px;
			float px_in_tex = max(0.5 * (length(uv_dx) + length(uv_dy)), 0.25);

			float sdf_norm = textureLod(ink_sdf, final_uv, 0.0).r;
			float sdf_tex = (sdf_norm - 0.5) * 16.0;
			float sdf_scr = sdf_tex / px_in_tex;
			float bias_scr = ink_width_bias * 6.0;
			float ink_cov = 1.0 - smoothstep(bias_scr - 0.42, bias_scr + 0.42, sdf_scr);

			// Protección HSV (Invariante #7): nunca ennegrecer el violeta #421D70 del ojo amatista
			float eye_protect = 1.0 - clamp(eye_w * (1.0 - eye_lash_ink), 0.0, 1.0);
			vec3 tinted_ink = mix(ink_color.rgb, vec3(0.24, 0.11, 0.12), skin_w * 0.85);
			float ink_a = ink_cov * ink_strength * eye_protect;
			rgb = mix(rgb, tinted_ink, clamp(ink_a, 0.0, 1.0));
		}

		// Grading cinematográfico ArcSys en sRGB y conversión final a Linear (preservando HDR > 1.0)
		vec3 hdr_excess = max(rgb - vec3(1.0), vec3(0.0));
		vec3 graded_srgb = apply_cinematic_grade_srgb(clamp(rgb, vec3(0.0), vec3(1.0)), 1.06, 1.05);
		vec3 out_lin = srgb_to_linear(graded_srgb) + hdr_excess;

		COLOR = vec4(out_lin, tex.a);
	}
}
