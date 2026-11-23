shader_type canvas_item;
// Shader Live Banner 2.5D — Pasada 1 (Estándar ArcSys Razor Sharp + Ojo Amatista Profundo).
// Se combina con pilot_rig_pass2.gdshader sobre UnifiedBannerGroup (CanvasGroup) para obtener
// el mismo contorno exterior caligráfico, soldador de costuras, CAS Sharpen e Impact Frames del rig de combate.

#include "res://scenes/pilots/shaders/rig_color_recolor.gdshaderinc"
#include "res://scenes/pilots/shaders/rig_stylized_lighting.gdshaderinc"

uniform sampler2D motion_mask : hint_default_black;
uniform sampler2D fx_mask : hint_default_black;
uniform sampler2D depth_map : hint_default_white;
uniform sampler2D normal_map : hint_normal;
uniform sampler2D ilm_map : hint_default_white;
uniform sampler2D ink_sdf : hint_default_white, filter_linear;
uniform sampler2D eye_iris_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform sampler2D eye_closed_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;

uniform bool has_motion_mask = false;
uniform bool has_fx_mask = false;
uniform bool has_depth_map = false;
uniform bool has_normal_map = false;
uniform bool has_ilm_map = false;
uniform bool has_ink_sdf = false;
uniform bool has_eye_live2d_assets = false;

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

// Ojo Amatista Profundo Live2D (Invariante #7) + Monóculo HUD (calibrados a Valentina v2)
uniform vec2 eye_center_uv = vec2(0.4647, 0.1275);
uniform vec4 eye_almond_bounds_uv = vec4(0.4421, 0.1152, 0.4810, 0.1322);
uniform vec2 eye_iris_size_uv = vec2(0.0250, 0.0180);
uniform vec4 monocle_bounds_uv = vec4(0.5000, 0.1120, 0.5506, 0.1491);
uniform float eye_glow_boost = 0.45;
uniform float eye_track_amp_px = 2.2;

uniform float mouse_parallax_strength = 0.0;
uniform float rim_light_strength = 0.55;
uniform vec4 rim_light_color : source_color = vec4(0.87, 0.95, 1.0, 1.0);
uniform float emissive_pulse_speed = 2.4;
uniform float emissive_boost = 0.42;

// Estilo Combate ArcSys (02_valentina_razor_sharp)
uniform bool cel_shading_enabled = true;
uniform float cel_strength : hint_range(0.0, 1.0) = 0.72;
uniform float cel_light_angle_deg = -40.0;
uniform vec4 cel_shadow_tint : source_color = vec4(0.145, 0.145, 0.335, 1.0);
uniform float cel_specular_strength : hint_range(0.0, 1.5) = 0.95;
uniform float ilm_ao_strength : hint_range(0.0, 1.0) = 0.78;
uniform float albedo_de_shade : hint_range(0.0, 0.6) = 0.28;

uniform bool ink_sdf_enabled = true;
uniform float ink_strength : hint_range(0.0, 1.0) = 0.86;
uniform float ink_width_bias : hint_range(-0.15, 0.15) = -0.025;
uniform float ink_color_tint_mix : hint_range(0.0, 1.0) = 0.82;
uniform vec4 ink_color : source_color = vec4(0.055, 0.055, 0.13, 1.0);

uniform bool skin_recolor_enabled = false;
uniform vec4 skin_accent_color : source_color = vec4(0.86, 0.18, 0.32, 1.0);
uniform vec4 skin_panel_color : source_color = vec4(0.36, 0.38, 0.44, 1.0);
uniform vec4 skin_dark_color : source_color = vec4(0.16, 0.15, 0.20, 1.0);
uniform vec4 skin_hair_color : source_color = vec4(0.82, 0.85, 0.92, 1.0);
uniform vec4 wings_skin_accent_color : source_color = vec4(1.0, 0.16, 0.32, 1.0);
uniform bool use_custom_wings_accent = false;
uniform float skin_star_glow : hint_range(0.0, 1.5) = 0.0;

uniform bool is_arm_layer = false;
uniform float arm_depth_shade = 0.0;
uniform float wings_light_intensity : hint_range(0.0, 2.5) = 0.0;
uniform vec4 wings_light_color : source_color = vec4(1.0, 0.16, 0.32, 1.0);
uniform float hair_burst_lift = 0.0;
uniform float lock_eye_flare : hint_range(0.0, 2.0) = 0.0;
uniform float lock_iris_scale : hint_range(0.75, 1.15) = 1.0;
uniform int debug_view_mode = 0; // 0=Final, 1=Motion, 2=FX, 3=Depth, 4=Normal, 5=InkSDF, 6=ILM

vec4 sample_lod0_rgss(sampler2D tex_s, vec2 uv_s) {
	vec2 du = dFdx(uv_s);
	vec2 dv = dFdy(uv_s);
	vec4 c0 = textureLod(tex_s, uv_s + du * 0.125 + dv * 0.375, 0.0);
	vec4 c1 = textureLod(tex_s, uv_s - du * 0.125 - dv * 0.375, 0.0);
	vec4 c2 = textureLod(tex_s, uv_s + du * 0.375 - dv * 0.125, 0.0);
	vec4 c3 = textureLod(tex_s, uv_s - du * 0.375 + dv * 0.125, 0.0);
	return (c0 + c1 + c2 + c3) * 0.25;
}

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
	} else if (debug_view_mode == 6) {
		COLOR = vec4(has_ilm_map ? texture(ilm_map, base_uv).rgb : vec3(0.25, 0.5, 0.0), 1.0);
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

		// Recolor por Skin Preset de Valentina v2 (uniforms : source_color convertidos a sRGB)
		if (skin_recolor_enabled) {
			vec3 acc_srgb = linear_to_srgb(max(skin_accent_color.rgb, vec3(0.0)));
			vec3 hair_srgb = linear_to_srgb(max(skin_hair_color.rgb, vec3(0.0)));
			float suit_body_w = clamp(suit_w * (1.0 - max(max(emissive_w, eye_w), hair_mat_w)) * smoothstep(0.04, 0.14, orig_luma), 0.0, 1.0);
			if (suit_body_w > 0.05) {
				vec3 panel_lin = max(skin_panel_color.rgb, vec3(0.0));
				vec3 dark_lin = max(skin_dark_color.rgb, vec3(0.0));
				float panel_t = smoothstep(0.24, 0.56, orig_luma);
				vec3 target_lin = mix(dark_lin, panel_lin, panel_t);
				float raw_luma_lin = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
				vec3 recolored_lin = apply_recolor_algorithm(target_lin, clamp(orig_luma, 0.0, 1.0), raw_luma_lin, 0.45, 1, 1.05, 0.35, 1.05);
				vec3 recolored_srgb = linear_to_srgb(recolored_lin);
				rgb = mix(rgb, recolored_srgb, suit_body_w * 0.90);
			}
			if (emissive_w > 0.15) {
				float val = max(rgb.r, max(rgb.g, rgb.b));
				rgb = mix(rgb, acc_srgb * max(val, 0.24) * 1.18, emissive_w * 0.85);
			}
			if (hair_mat_w > 0.25) {
				rgb = mix(rgb, hair_srgb * (orig_luma * 1.12), hair_mat_w * 0.55);
			}
		}

		// =========================================================================
		// 4. OJO LIVE2D VECTORIAL SDF + PARPADEO ANATÓMICO (SIN BORDES DENTADOS)
		// =========================================================================
		float eyelid_cover = 0.0;
		float eye_lash_ink = 0.0;
		float eye_open_mask = 0.0;
		vec2 almond_min = eye_almond_bounds_uv.xy;
		vec2 almond_max = eye_almond_bounds_uv.zw;
		vec2 almond_sz = max(almond_max - almond_min, vec2(0.001));
		vec2 box_pad = almond_sz * vec2(0.18, 0.45);
		vec2 box_min = almond_min - box_pad;
		vec2 box_max = almond_max + box_pad;
		bool in_eye_sdf_box = (!is_arm_layer) && (hair_mat_w < 0.60)
			&& final_uv.x >= box_min.x && final_uv.x <= box_max.x
			&& final_uv.y >= box_min.y && final_uv.y <= box_max.y;

		if (in_eye_sdf_box) {
			float u = (final_uv.x - almond_min.x) / almond_sz.x;
			float v = (final_uv.y - almond_min.y) / almond_sz.y;
			float u_c = clamp(u, 0.0, 1.0);
			float arch_top = sin(u_c * 3.14159265);
			float slant = (u_c - 0.5) * 0.14;
			float y_top = 0.53 - 0.48 * pow(arch_top, 0.80) + slant;
			float y_bot = 0.55 + 0.48 * pow(arch_top, 0.84) + slant * 0.85;

			float b_ease = clamp(blink_amount, 0.0, 1.0);
			float y_lid = mix(y_top, y_bot + 0.14, b_ease);
			float y_lash = mix(y_top, y_bot - 0.02 * arch_top, b_ease);

			float aa_v = max(fwidth(v) * 1.15, 0.035);
			float hair_cut = 1.0 - smoothstep(0.28, 0.58, hair_mat_w);
			float u_gate = smoothstep(-0.02, 0.06, u) * (1.0 - smoothstep(0.94, 1.02, u)) * hair_cut;
			float u_lid_gate = smoothstep(-0.12, 0.08, u) * (1.0 - smoothstep(0.92, 1.10, u)) * hair_cut;

			float orig_open_w = smoothstep(y_top - aa_v, y_top + aa_v, v)
				* (1.0 - smoothstep(y_bot - aa_v, y_bot + aa_v, v))
				* u_gate;
			float close_cutoff = 1.0 - smoothstep(0.86, 0.96, b_ease);
			float live_open_w = smoothstep(y_lash - aa_v, y_lash + aa_v, v)
				* (1.0 - smoothstep(y_bot - aa_v, y_bot + aa_v, v))
				* u_gate * close_cutoff;
			float lid_cover_w = smoothstep(y_top - 0.40 - aa_v, y_top - 0.24 + aa_v, v)
				* (1.0 - smoothstep(y_lid - aa_v, y_lid + aa_v, v))
				* u_lid_gate * smoothstep(0.02, 0.18, b_ease);

			vec2 eye_look_uv = clamp(mouse_offset, vec2(-1.0), vec2(1.0)) * (eye_track_amp_px * px) * vec2(1.15, 0.65);
			vec2 iris_center_live = eye_center_uv + eye_look_uv + vec2(0.0, 0.25 * px.y);

			// Capa 1 + 2: Esclerótica blanca limpia + Iris Live2D 360° dentro de la almendra vectorial
			if (live_open_w > 0.004) {
				vec3 sclera_col = vec3(0.965, 0.968, 0.985);
				float open_span = max(y_bot - y_lash, 0.15);
				float lid_sh = 1.0 - smoothstep(0.0, 0.30, (v - y_lash) / open_span);
				sclera_col *= mix(1.0, 0.78, lid_sh * 0.65);

				vec3 eye_col = sclera_col;
				if (has_eye_live2d_assets) {
					vec2 eff_iris_sz = max(eye_iris_size_uv * lock_iris_scale, vec2(0.002));
					vec2 iris_uv = (final_uv - iris_center_live) / eff_iris_sz + vec2(0.5);
					if (iris_uv.x > 0.0 && iris_uv.x < 1.0 && iris_uv.y > 0.0 && iris_uv.y < 1.0) {
						float iris_r = length((iris_uv - vec2(0.5)) * 2.0);
						float iris_circle = 1.0 - smoothstep(0.84, 0.94, iris_r);
						if (iris_circle > 0.005) {
							vec4 iris_s = sample_lod0_rgss(eye_iris_tex, iris_uv);
							vec3 iris_srgb = linear_to_srgb(max(iris_s.rgb, vec3(0.0)));
							float hsv_v = max(iris_srgb.r, max(iris_srgb.g, iris_srgb.b));
							float pupil_guard = smoothstep(0.14, 0.34, hsv_v);
							iris_srgb *= mix(1.0, 0.82, lid_sh * 0.45 * pupil_guard);
							float lower_glow = smoothstep(0.54, 0.86, iris_uv.y) * pupil_guard;
							iris_srgb += vec3(0.875, 0.769, 1.000) * lower_glow * (eye_glow_boost + lock_eye_flare * 0.75) * 0.32;
							iris_srgb += vec3(0.65, 0.42, 1.0) * pupil_guard * lock_eye_flare * 0.28;
							vec2 id = (iris_uv - vec2(0.5)) * 2.0;
							float s1 = 1.0 - smoothstep(0.14, 0.24, length((id - vec2(-0.34, -0.30)) * vec2(1.0, 1.12)));
							float s2 = (1.0 - smoothstep(0.08, 0.15, length(id - vec2(0.32, 0.30)))) * 0.62;
							float catch_w = clamp(max(s1, s2), 0.0, 1.0);
							iris_srgb = mix(iris_srgb, vec3(1.18, 1.14, 1.28) + vec3(0.25, 0.18, 0.35) * lock_eye_flare, catch_w * 0.85);
							eye_col = mix(eye_col, iris_srgb, clamp(iris_s.a * iris_circle, 0.0, 1.0));
						}
					}
				}
				rgb = mix(rgb, eye_col, live_open_w);
				// Destello en cruz (+) fino en el centro del iris durante Lock-In
				if (lock_eye_flare > 0.15) {
					vec2 d_iris = abs(final_uv - iris_center_live) / max(eye_iris_size_uv * 0.85, vec2(0.002));
					float arm_h = exp(-d_iris.y * 12.0) * exp(-d_iris.x * 2.2);
					float arm_v = exp(-d_iris.x * 12.0) * exp(-d_iris.y * 2.2);
					float star_core = exp(-dot(d_iris, d_iris) * 6.5);
					float star_w = clamp(arm_h + arm_v + star_core * 0.85, 0.0, 1.2) * live_open_w;
					rgb += vec3(1.15, 0.92, 1.45) * star_w * max(lock_eye_flare - 0.15, 0.0) * 0.65;
				}
			}

			// Capa 3A: Párpado móvil con piel muestreada del splash (tapa la pestaña superior original al cerrar)
			if (lid_cover_w > 0.004) {
				vec2 lid_sample_uv = clamp(eye_center_uv + vec2(0.008, -0.017), vec2(0.001), vec2(0.999));
				vec3 sampled_skin = linear_to_srgb(max(textureLod(TEXTURE, lid_sample_uv, 0.0).rgb, vec3(0.0)));
				vec3 base_lid_skin = mix(vec3(0.87, 0.68, 0.64), sampled_skin, 0.78);
				float lid_grad = smoothstep(y_top - 0.25, y_lid, v);
				vec3 lid_skin = mix(base_lid_skin * 0.90, base_lid_skin * 1.04, lid_grad);
				rgb = mix(rgb, lid_skin, lid_cover_w);
				eyelid_cover = lid_cover_w;
			}

			// Capa 3B: Única pestaña superior anime vectorial + micro-delineado inferior
			float lash_thick = mix(0.06, 0.17, pow(arch_top, 0.75)) * mix(1.18, 0.78, u_c);
			float d_lash_top = abs(v - (y_lash - lash_thick * 0.35)) - lash_thick * 0.65;
			float lash_upper_w = (1.0 - smoothstep(-aa_v, aa_v, d_lash_top)) * u_gate;

			float bot_thick = 0.055 * pow(max(arch_top, 0.05), 0.55);
			float d_lash_bot = abs(v - (y_bot + bot_thick * 0.30)) - bot_thick * 0.50;
			float lash_lower_w = (1.0 - smoothstep(-aa_v, aa_v, d_lash_bot)) * u_gate * 0.55;

			float total_lash_w = clamp(max(lash_upper_w, lash_lower_w), 0.0, 1.0);
			if (total_lash_w > 0.004) {
				rgb = mix(rgb, vec3(0.075, 0.035, 0.086), total_lash_w * 0.96);
				eye_lash_ink = max(eye_lash_ink, total_lash_w);
			}

			eye_open_mask = clamp(max(max(orig_open_w, live_open_w), max(lash_upper_w, lid_cover_w)), 0.0, 1.0);
		}

		// =========================================================================
		// 5. MONÓCULO TÁCTICO HUD VIVO (ESTILO FACE LAB)
		// =========================================================================
		bool in_monocle_box = (final_uv.x >= monocle_bounds_uv.x && final_uv.x <= monocle_bounds_uv.z
			&& final_uv.y >= monocle_bounds_uv.y && final_uv.y <= monocle_bounds_uv.w);
		float monocle_w = (in_monocle_box && !is_arm_layer) ? emissive_w : 0.0;
		if (monocle_w > 0.15) {
			vec2 m_uv = clamp((final_uv - monocle_bounds_uv.xy) / max(monocle_bounds_uv.zw - monocle_bounds_uv.xy, vec2(0.001)), vec2(0.0), vec2(1.0));
			float spd_mul = 1.0 + lock_eye_flare * 1.35 + wings_light_intensity * 0.35;
			float scan = 0.5 + 0.5 * sin(m_uv.y * 42.0 - anim_time * 7.5 * spd_mul);
			float sweep_pos = fract(anim_time * 0.34 * spd_mul);
			float sweep_band = exp(-pow((m_uv.y - sweep_pos) / 0.11, 2.0));
			float reticle_d = length(m_uv - vec2(0.50, 0.50));
			float reticle_ring = exp(-pow((reticle_d - 0.30) / 0.055, 2.0));
			vec3 acc_srgb = linear_to_srgb(max(skin_accent_color.rgb, vec3(0.0)));
			vec3 hud_col = skin_recolor_enabled ? (acc_srgb * 1.45) : vec3(1.35, 0.32, 0.48);
			float activity = 0.55 + wings_light_intensity * 0.55 + lock_eye_flare * 0.85;
			rgb += hud_col * (scan * 0.08 + sweep_band * 0.24 + reticle_ring * 0.24) * monocle_w * activity;
			if (lock_eye_flare > 0.15) {
				vec2 md = abs(m_uv - vec2(0.50, 0.50));
				float m_star = exp(-md.y * 16.0) * exp(-md.x * 2.8) + exp(-md.x * 16.0) * exp(-md.y * 2.8);
				rgb += (hud_col + vec3(0.65, 0.55, 0.65)) * clamp(m_star, 0.0, 1.0) * monocle_w * max(lock_eye_flare - 0.15, 0.0) * 0.65;
			}
		}

		// =========================================================================
		// 6. CEL-SHADING 2.5D ARCSYS + ILM (02_valentina_razor_sharp EN sRGB REAL)
		// =========================================================================
		vec3 n_vec = vec3(0.0, 0.0, 1.0);
		if (has_normal_map) {
			vec3 n_raw = texture(normal_map, final_uv).rgb * 2.0 - 1.0;
			n_vec = normalize(vec3(n_raw.x, n_raw.y, max(n_raw.z, 0.20)));
		}
		vec3 ilm = has_ilm_map
			? texture(ilm_map, final_uv).rgb
			: vec3(suit_w * 0.55, is_skin ? 0.90 : 0.52, hair_mat_w * 0.5);
		float ilm_metal = ilm.r;
		float ilm_ao = ilm.g;
		float ilm_satin = ilm.b;
		float not_ink_guard = smoothstep(0.06, 0.16, orig_luma);

		if (cel_shading_enabled && has_normal_map && cel_strength > 0.01) {
			// De-shade sutil sobre sombras pre-horneadas para mantener lectura del traje oscuro
			vec3 base_clean = rgb;
			if (albedo_de_shade > 0.01 && eye_open_mask < 0.15 && emissive_w < 0.2 && not_ink_guard > 0.1) {
				float l_cur = max(dot(base_clean, vec3(0.299, 0.587, 0.114)), 0.001);
				float l_lift = mix(l_cur, pow(l_cur, 0.86), albedo_de_shade * not_ink_guard);
				base_clean = clamp(base_clean * (l_lift / l_cur), vec3(0.0), vec3(1.0));
			}

			float l_rad = radians(cel_light_angle_deg) + mouse_offset.x * 0.12;
			vec3 key_dir = normalize(vec3(cos(l_rad), sin(l_rad), 0.76));
			float ndotl = dot(n_vec, key_dir);

			// Sesgo AO desde ILM (sin bajar el pelo plateado a sombra azulada)
			float eff_ao = mix(ilm_ao, max(ilm_ao, 0.46), hair_mat_w);
			float ao_bias = (eff_ao - 0.52) * 0.72 * ilm_ao_strength;
			float ndotl_biased = ndotl + ao_bias;

			// Protección facial (face_shadow_protect = 0.92)
			float is_face = is_skin ? smoothstep(0.20, 0.13, final_uv.y) : 0.0;
			float ndotl_adj = mix(ndotl_biased, max(ndotl_biased, 0.24), max(is_face * 0.92, eye_open_mask));

			// Bandas Cel ArcSys idénticas al Combat Rig (02_valentina_razor_sharp)
			float cel_thr = 0.09;
			float lit_mask = smoothstep(cel_thr - 0.025, cel_thr + 0.025, ndotl_adj);
			float mid_mask = smoothstep(cel_thr - 0.38, cel_thr - 0.30, ndotl_adj);
			float shadow_w = (1.0 - lit_mask) * mix(1.0, mix(1.0, 0.56, mid_mask), 0.42);

			// Convertir uniform cel_shadow_tint (: source_color = Linear) a sRGB antes de compute_arcsys_shadow_srgb
			vec3 sh_tint_srgb = linear_to_srgb(max(cel_shadow_tint.rgb, vec3(0.0)));
			vec3 hair_sh_tint = mix(sh_tint_srgb, vec3(0.58, 0.60, 0.78), 0.60);
			vec3 cool_tint_eff = mix(sh_tint_srgb, hair_sh_tint, hair_mat_w);
			vec3 sh_tint = is_skin ? vec3(0.85, 0.65, 0.69) : cool_tint_eff;

			vec3 shadow_col = compute_arcsys_shadow_srgb(base_clean, sh_tint, 0.34, orig_luma, is_skin);
			// Oclusión AO en grietas reales (bajo busto/mentón/axilas)
			float deep_ao = smoothstep(0.30, 0.10, eff_ao) * ilm_ao_strength * (1.0 - eye_open_mask) * (1.0 - hair_mat_w);
			vec3 ao_col = compute_arcsys_shadow_srgb(base_clean, is_skin ? vec3(0.74, 0.54, 0.58) : vec3(0.26, 0.25, 0.44), 0.15, orig_luma, is_skin);
			shadow_col = mix(shadow_col, ao_col, deep_ao * 0.68);

			float hair_sh_scale = mix(1.0, 0.68, hair_mat_w);
			float eye_sh_scale = mix(1.0, 0.20, eye_open_mask);
			vec3 shaded = mix(base_clean, shadow_col, shadow_w * cel_strength * hair_sh_scale * eye_sh_scale * not_ink_guard);
			// Boost suave de luz clave en zona iluminada (como key_light_boost del Combat Rig)
			shaded = mix(shaded, shaded * vec3(1.04, 1.02, 0.99), lit_mask * cel_strength * mix(1.0, 0.25, is_skin ? 1.0 : 0.0) * not_ink_guard);

			if (is_skin && eye_open_mask < 0.1) {
				float sss_band = exp(-pow((ndotl_adj - cel_thr) * 9.5, 2.0));
				shaded += vec3(0.97, 0.40, 0.34) * sss_band * 0.12 * cel_strength * (1.0 - is_face * 0.55);
			}

			if (cel_specular_strength > 0.01) {
				vec3 half_v = normalize(key_dir + vec3(0.0, 0.0, 1.0));
				float spec_hard = pow(max(dot(n_vec, half_v), 0.0), 22.0);
				float spec_step = smoothstep(0.36, 0.46, spec_hard);
				// Brillo metálico en armadura rígida (ilm_metal)
				shaded += vec3(0.88, 0.94, 1.0) * spec_step * ilm_metal * cel_specular_strength * 0.36 * lit_mask * not_ink_guard;
				// Brillo satinado en bandas/medias (ilm_satin)
				float spec_satin = smoothstep(0.26, 0.46, pow(max(dot(n_vec, half_v), 0.0), 10.0));
				shaded += vec3(0.86, 0.92, 1.0) * spec_satin * ilm_satin * (1.0 - hair_mat_w) * cel_specular_strength * 0.18 * lit_mask * not_ink_guard;
				// Angel Ring nítido en cabello plateado
				if (hair_mat_w > 0.20) {
					float angel_mask = has_ilm_map ? ilm_satin : smoothstep(0.16, 0.07, final_uv.y);
					float angel = smoothstep(0.32, 0.56, spec_hard + angel_mask * 0.34) * angel_mask;
					shaded += vec3(1.0, 0.99, 1.0) * angel * hair_mat_w * 0.28;
				}
			}

			rgb = mix(rgb, shaded, cel_strength * (1.0 - max(emissive_w * 0.72, eye_open_mask * 0.96)));
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

			vec3 w_col = use_custom_wings_accent
				? linear_to_srgb(max(wings_skin_accent_color.rgb, vec3(0.0)))
				: (skin_recolor_enabled
					? linear_to_srgb(max(skin_accent_color.rgb, vec3(0.0)))
					: linear_to_srgb(max(wings_light_color.rgb, vec3(0.0))));
			rgb += w_col * wing_slice * zone_allow * wings_light_intensity * 1.05;
		}

		// Pulso suave en paneles carmesí del traje (monóculo ya tiene su HUD propio arriba)
		if (emissive_w > 0.15 && monocle_w < 0.1) {
			float pulse = 0.75 + 0.25 * sin(anim_time * emissive_pulse_speed);
			rgb += rgb * emissive_w * (emissive_boost + skin_star_glow * 0.25) * pulse * (0.45 + wings_light_intensity * 0.35);
		}

		// =========================================================================
		// 8. TINTA INTERNA RAZOR-SHARP SDF 2x (FINA EN ROSTRO + PROTECCIÓN OJO)
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

			// Protección HSV (Invariante #7): nunca ennegrecer el ojo Live2D ni el párpado/pestaña vectorial
			float eye_protect = 1.0 - clamp(max(eye_open_mask, eye_w), 0.0, 1.0);
			vec3 base_ink_srgb = linear_to_srgb(max(ink_color.rgb, vec3(0.0)));
			vec3 local_dark_ink = clamp(rgb * 0.26, vec3(0.03), vec3(0.22));
			vec3 cool_or_local = mix(base_ink_srgb, local_dark_ink, ink_color_tint_mix * 0.55);
			vec3 tinted_ink = mix(cool_or_local, vec3(0.24, 0.11, 0.12), skin_w * 0.85);
			float skin_ink_scale = mix(1.0, 0.52, skin_w);
			float ink_a = ink_cov * ink_strength * eye_protect * skin_ink_scale;
			rgb = mix(rgb, tinted_ink, clamp(ink_a, 0.0, 0.92));
		}

		// Grading cinematográfico ArcSys en sRGB (02_valentina_razor_sharp) preservando HDR > 1.0
		vec3 hdr_excess = max(rgb - vec3(1.0), vec3(0.0));
		vec3 graded_srgb = apply_cinematic_grade_srgb(clamp(rgb, vec3(0.0), vec3(1.0)), 1.05, 1.04);
		vec3 out_lin = srgb_to_linear(graded_srgb) + hdr_excess;

		COLOR = vec4(out_lin, tex.a);
	}
}
