shader_type canvas_item;
render_mode blend_mix;

varying float v_modulate_alpha;

void vertex() {
	v_modulate_alpha = COLOR.a;
}

uniform sampler2D id_mask_tex : hint_default_black, filter_linear_mipmap;

// 9 Estilos de Identidad Visual (Post-Procesado / Look Global):
// 0 = Original Upscayl 4x
// 1 = Studio Trigger Clean Cel
// 2 = Skullgirls Classic Screentone
// 3 = Guilty Gear / Hades Rim-Lit
// 4 = Spider-Verse / Hi-Fi Rush Dual-Tone
// 5 = Persona 5 / Gurren Lagann Graphic Noir
// 6 = Cyberpunk Edgerunners Dual-Rim
// 7 = Kill la Kill / Promare Manga Hatch
// 8 = Arcane / Nikke Specular Metal
uniform int pipeline_style_mode : hint_range(0, 8) = 2;

// 5 Algoritmos Matemáticos de Recoloreo:
// 0 = Multiplicativo Proporcional Clásico
// 1 = Gradiente de 3 Tonos (Skullgirls / ArcSys: Sombra Fría -> Base -> Brillo Cálido)
// 2 = Remapeo Perceptual de Contraste (Permite colores oscuros en pelo blanco sin lavar)
// 3 = Fusión Overlay / Hard-Light (Clip Studio / Photoshop: Máxima saturación media)
// 4 = Cel-Ramp Indexado 3-Bandas (Guilty Gear / DBFZ: Sombra Plana + Base + Especular)
uniform int recolor_method : hint_range(0, 4) = 1;

// 4 Modos de Estilo de Cabello:
// 0 = Sólido Cel-Shaded (Natural 2-Tonos)
// 1 = Bicolor Trigger / Edgerunners (Sombra teñida con Color Secundario/Acento)
// 2 = Puntas Teñidas / Dip-Dye (Raíz a Puntas con Color Secundario/Acento)
// 3 = Halo Especular Anime ("Angel Ring" + Sombra Profunda)
uniform int hair_style_mode : hint_range(0, 3) = 0;

uniform bool enable_shader_recolor = false;
uniform bool enable_hair_recolor = false;
uniform bool is_head_part = false;
uniform bool is_leg_part = false;
uniform int arm_layer_pass : hint_range(0, 2) = 0; // 0=Normal, 1=BajoTorso (completo), 2=SobreTorso (antebrazo/mano)
uniform sampler2D arm_over_mask_tex : hint_default_black, filter_linear;
uniform bool use_arm_over_mask = false;
uniform bool arm_over_from_anim_mask = false;
uniform int head_layer_pass : hint_range(0, 2) = 0; // 0=Completo, 1=BajoTorso (Cuello/Mentón/Collar), 2=SobreTorso (Pelo en N / Pelo+Cara en S)
uniform float head_over_face_keep : hint_range(0.0, 1.0) = 0.0;

uniform vec4 accent_color : source_color = vec4(1.0, 0.12, 0.35, 1.0);
uniform vec4 panel_color : source_color = vec4(0.36, 0.39, 0.48, 1.0);
uniform vec4 suit_dark_color : source_color = vec4(0.11, 0.12, 0.18, 1.0);
uniform vec4 hair_color : source_color = vec4(0.86, 0.89, 0.96, 1.0);
uniform vec4 hair_secondary_color : source_color = vec4(1.0, 0.12, 0.35, 1.0);

uniform sampler2D secondary_jiggle_mask_tex : hint_default_black, filter_linear;
uniform bool enable_secondary_jiggle = false;
uniform vec2 secondary_jiggle_l_px = vec2(0.0, 0.0);
uniform vec2 secondary_jiggle_r_px = vec2(0.0, 0.0);

uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;

// Controles Finos de Trama / Semitono (Sección 1 - Filtro)
uniform bool enable_halftone = true;
uniform int halftone_pattern_type : hint_range(0, 5) = 0;
uniform int halftone_zone_mode : hint_range(0, 3) = 0;
uniform float halftone_scale : hint_range(40.0, 320.0) = 165.0;
uniform float halftone_strength : hint_range(0.0, 1.0) = 0.38;
uniform float halftone_angle_deg : hint_range(0.0, 180.0) = 45.0;
uniform float halftone_threshold : hint_range(0.15, 0.85) = 0.38;

// Controles Finos de Sombra, Tinta, Especular y Rim-Light (Sección 1 - Filtro)
uniform float cel_step_strength : hint_range(0.0, 1.0) = 0.0;
uniform float noir_shadow_crush : hint_range(0.0, 1.0) = 0.0;
uniform float noir_shadow_threshold : hint_range(0.10, 0.45) = 0.24;
uniform float metal_sheen_strength : hint_range(0.0, 1.5) = 0.0;
uniform float rim_light_strength : hint_range(0.0, 1.5) = 0.30;
uniform float rim_width_px : hint_range(1.0, 14.0) = 5.0;
uniform float dual_rim_strength : hint_range(0.0, 1.5) = 0.0;
uniform float ink_boost : hint_range(0.0, 1.0) = 0.22;
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.25;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.6;

// Controles Finos de Curva de Recoloreo y Medias (Sección 2 - Recolor)
uniform float recolor_contrast : hint_range(0.4, 2.2) = 1.0;
uniform float recolor_highlight : hint_range(0.0, 2.0) = 1.0;
uniform float recolor_saturation : hint_range(0.0, 2.0) = 1.0;
uniform float stocking_tint_strength : hint_range(0.0, 1.0) = 0.28;

// Controles Finos de Cabello (Sección 4 - Pelo)
uniform float hair_effect_strength : hint_range(0.0, 1.0) = 0.90;
uniform float hair_cut_height : hint_range(0.05, 0.85) = 0.42;
uniform float hair_cut_softness : hint_range(0.01, 0.40) = 0.14;

// Inspector Rayos-X (0=Final, 1=Clown-Pass ID, 2=Luminancia, 3=Solo Tinta, 4=Normales 2.5D, 5=Profundidad 2.5D)
uniform int debug_view_mode : hint_range(0, 5) = 0;

// Pipeline 2.5D Normal + Depth + Conic Rim + HDR (Opcional, retrocompatible si use_normal_depth = false)
uniform sampler2D normal_depth_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D conic_rim_lut : source_color, hint_default_white, filter_linear;
uniform float q_time = 0.0;
uniform bool use_normal_depth = false;
uniform vec2 light_dir_2d = vec2(-0.58, -0.81);
uniform float normal_flip_x = 1.0;
uniform float normal_cel_influence : hint_range(0.0, 1.0) = 0.52;
uniform float normal_rim_strength : hint_range(0.0, 2.5) = 0.78;
uniform float depth_parallax_px : hint_range(0.0, 12.0) = 3.2;
uniform vec2 banking_tilt_2d = vec2(0.0, 0.0);
uniform float crt_hdr_boost : hint_range(1.0, 3.0) = 1.0;
uniform float zoom_scale : hint_range(0.35, 4.0) = 1.0;

// Transiciones Estilizadas 2.5D (0=Off, 1=Depth-Parallax+Cel-Rim, 2=Anime Ink-Smear+Flash, 3=Holo-Sweep Cyber-Cut)
uniform int transition_fx_mode : hint_range(0, 3) = 0;
uniform float transition_fx_strength : hint_range(0.0, 1.0) = 0.0;
uniform float transition_turn_dir : hint_range(-1.0, 1.0) = 0.0;
uniform float holo_sweep_pos : hint_range(-1.0, 2.0) = -1.0;
uniform float holo_keep_side : hint_range(-1.0, 1.0) = 0.0;
uniform vec2 holo_sweep_dir = vec2(0.22, 0.92);
uniform vec4 part_rig_rect = vec4(-0.22, -0.50, 0.44, 0.96);
uniform float suppress_alpha_rim = 0.0;
uniform sampler2D head_outline_sdf_tex : hint_default_white, filter_linear;
uniform bool use_head_outline_sdf = false;
uniform float head_outline_strength : hint_range(0.0, 1.0) = 1.0;
uniform float head_outline_width_px : hint_range(0.5, 24.0) = 5.5;

float compute_halftone_pattern(vec2 frag_coord, float scale, int pat_type, float angle_deg) {
	float rad = radians(angle_deg);
	float c = cos(rad);
	float s = sin(rad);
	vec2 rot_uv = vec2(
		frag_coord.x * c - frag_coord.y * s,
		frag_coord.x * s + frag_coord.y * c
	) / (1080.0 / max(scale, 10.0));

	if (pat_type == 0) {
		// 0: Puntos CMYK Clásicos
		vec2 cell = fract(rot_uv) - vec2(0.5);
		return 1.0 - smoothstep(0.28, 0.38, length(cell));
	} else if (pat_type == 1) {
		// 1: Líneas Manga Paralelas
		float wave = abs(fract(rot_uv.x * 1.15) - 0.5);
		return 1.0 - smoothstep(0.17, 0.27, wave);
	} else if (pat_type == 2) {
		// 2: Trama Cruzada (Crosshatch)
		vec2 cell = abs(fract(rot_uv) - vec2(0.5));
		float line_a = 1.0 - smoothstep(0.14, 0.22, cell.x);
		float line_b = 1.0 - smoothstep(0.14, 0.22, cell.y);
		return max(line_a, line_b);
	} else if (pat_type == 3) {
		// 3: Micro-Punto Escalonado
		vec2 grid = rot_uv * 1.35;
		grid.x += 0.5 * step(0.5, fract(grid.y * 0.5));
		vec2 cell = fract(grid) - vec2(0.5);
		return 1.0 - smoothstep(0.24, 0.34, length(cell));
	} else if (pat_type == 4) {
		// 4: Panal Hexagonal Sci-Fi
		vec2 q = vec2(rot_uv.x * 1.1547, rot_uv.y + rot_uv.x * 0.57735);
		vec2 cell = abs(fract(q) - vec2(0.5));
		float hex_d = max(cell.x, cell.y);
		return smoothstep(0.32, 0.44, hex_d);
	} else {
		// 5: Scanlines Horizontales CRT
		float scan = abs(fract(frag_coord.y / (1080.0 / max(scale, 20.0))) - 0.5);
		return 1.0 - smoothstep(0.16, 0.28, scan);
	}
}

vec3 adjust_saturation(vec3 col, float sat) {
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	return clamp(mix(vec3(l), col, sat), vec3(0.0), vec3(1.0));
}

vec3 linear_to_srgb(vec3 lin) {
	vec3 c = clamp(lin, vec3(0.0), vec3(1.0));
	vec3 lo = c * 12.92;
	vec3 hi = 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055;
	return mix(lo, hi, step(vec3(0.0031308), c));
}

vec3 srgb_to_linear(vec3 srgb) {
	vec3 c = clamp(srgb, vec3(0.0), vec3(1.0));
	vec3 lo = c / 12.92;
	vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}

// Evalúa el color recoloreado de un material según el Algoritmo Matemático (`recolor_method = 0..4`)
vec3 apply_recolor_algorithm(vec3 target_col_in, float t_norm_in, float raw_luma, float ref_mid_luma, int method) {
	vec3 target_col = adjust_saturation(target_col_in, recolor_saturation);
	float t_norm = clamp((t_norm_in - 0.5) * recolor_contrast + 0.5, 0.0, 1.0);
	float hi_gain = recolor_highlight;

	if (method == 0) {
		// 0: Multiplicativo Proporcional Clásico
		float ratio = (raw_luma / max(ref_mid_luma, 0.08) - 1.0) * recolor_contrast + 1.0;
		float mult = clamp(ratio, 0.32, 1.15 + 0.35 * hi_gain);
		return clamp(target_col * mult, vec3(0.0), vec3(1.0));
	} else if (method == 1) {
		// 1: Gradiente Artístico de 3 Tonos (Skullgirls / ArcSys)
		vec3 shadow_col = target_col * vec3(0.42, 0.36, 0.58);
		vec3 hi_col = mix(target_col * (1.0 + 0.35 * hi_gain), vec3(1.0, 0.98, 0.92), 0.28 * hi_gain);
		vec3 low_to_mid = mix(shadow_col, target_col, smoothstep(0.0, 0.55, t_norm));
		return clamp(mix(low_to_mid, hi_col, smoothstep(0.55, 1.0, t_norm)), vec3(0.0), vec3(1.0));
	} else if (method == 2) {
		// 2: Remapeo Perceptual de Contraste Relativo (HSL / OKLab-like)
		float delta = (t_norm - 0.52) * 0.78;
		vec3 dark_pole = target_col * vec3(0.32, 0.28, 0.44);
		vec3 light_pole = mix(target_col * (1.0 + 0.38 * hi_gain), vec3(0.96, 0.97, 1.0), 0.32 * hi_gain);
		if (delta < 0.0) {
			return clamp(mix(target_col, dark_pole, clamp(-delta * 1.8, 0.0, 1.0)), vec3(0.0), vec3(1.0));
		} else {
			return clamp(mix(target_col, light_pole, clamp(delta * 1.8, 0.0, 1.0)), vec3(0.0), vec3(1.0));
		}
	} else if (method == 3) {
		// 3: Fusión Overlay / Hard-Light (Estilo Clip Studio / Photoshop)
		vec3 t_vec = vec3(clamp(t_norm, 0.0, 1.0));
		vec3 dark_branch = 2.0 * t_vec * target_col;
		vec3 light_branch = vec3(1.0) - 2.0 * (vec3(1.0) - t_vec) * (vec3(1.0) - target_col);
		vec3 ov = mix(dark_branch, light_branch, smoothstep(0.32, 0.68, t_norm));
		vec3 res = mix(ov, target_col, 0.22);
		return clamp(res * (0.85 + 0.18 * hi_gain), vec3(0.0), vec3(1.0));
	} else {
		// 4: Cel-Ramp Indexado de 3 Bandas (Guilty Gear Strive / DBFZ)
		vec3 shadow_cel = target_col * vec3(0.44, 0.38, 0.56);
		vec3 hi_cel = mix(target_col * (1.0 + 0.35 * hi_gain), vec3(1.0), 0.34 * hi_gain);
		float step_mid = smoothstep(0.34, 0.40, t_norm);
		float step_hi = smoothstep(0.76, 0.82, t_norm);
		vec3 cel = mix(shadow_cel, target_col, step_mid);
		return clamp(mix(cel, hi_cel, step_hi), vec3(0.0), vec3(1.0));
	}
}

// Estabiliza la luminancia dentro de la misma región semántica sin cruzar tinta ni bordes de material
float sample_same_id_luma(sampler2D col_tex, sampler2D id_tex, vec2 uv, vec2 px_sz, vec4 center_m, float center_luma, bool head_mode) {
	float l_sum = center_luma * 1.4;
	float w_sum = 1.4;
	vec2 offs[4] = vec2[4](vec2(1.5, 0.0), vec2(-1.5, 0.0), vec2(0.0, 1.5), vec2(0.0, -1.5));
	for (int i = 0; i < 4; i++) {
		vec2 tuv = clamp(uv + offs[i] * px_sz, vec2(0.0), vec2(1.0));
		vec4 tc = textureLod(col_tex, tuv, 0.0);
		if (tc.a > 0.35) {
			vec3 ts = linear_to_srgb(tc.rgb);
			float tl = dot(ts, vec3(0.299, 0.587, 0.114));
			vec4 tm = textureLod(id_tex, tuv, 0.0);
			float id_sim = head_mode
				? 1.0 - clamp(abs(tm.a - center_m.a) + abs(tm.r - center_m.r) + abs(tm.b - center_m.b), 0.0, 1.0)
				: clamp(dot(normalize(tm + vec4(0.0001)), normalize(center_m + vec4(0.0001))), 0.0, 1.0);
			float not_ink = smoothstep(0.08, 0.16, tl);
			float tone_w = exp(-abs(tl - center_luma) * 14.0);
			float w = id_sim * not_ink * tone_w;
			l_sum += tl * w;
			w_sum += w;
		}
	}
	return mix(center_luma, l_sum / w_sum, 0.72);
}

void fragment() {
	vec2 sample_uv = UV;
	vec2 tex_coord_px = UV / TEXTURE_PIXEL_SIZE;
	float screen_px_in_texels = clamp(0.5 * (length(dFdx(tex_coord_px)) + length(dFdy(tex_coord_px))), 0.5, 24.0);

	float holo_beam = 0.0;
	if (transition_fx_mode == 3 && holo_sweep_pos > -0.5) {
		// Mismo espacio unificado del personaje entero (cabeza + cuello + torso + extremidades)
		vec2 char_p = part_rig_rect.xy + sample_uv * part_rig_rect.zw;
		char_p.x *= normal_flip_x;
		vec2 norm_p = vec2(char_p.x / 0.22, (char_p.y - 0.08) / 0.49);
		vec2 s_dir = normalize(holo_sweep_dir);
		float proj = dot(norm_p, s_dir);
		float diag = clamp(proj * 0.44 + 0.50, 0.0, 1.0);
		if (abs(holo_keep_side) > 0.5) {
			float dist = (diag - holo_sweep_pos) * holo_keep_side;
			if (dist < 0.0) {
				discard;
			}
			holo_beam = (1.0 - smoothstep(0.0, 0.065, dist)) * (0.65 + 0.35 * step(0.32, fract(proj * 22.0)));
		} else if (transition_fx_strength > 0.01) {
			float band_d = abs(diag - holo_sweep_pos);
			holo_beam = (1.0 - smoothstep(0.0, 0.11, band_d)) * transition_fx_strength * (0.65 + 0.35 * step(0.32, fract(proj * 22.0)));
		}
		float jitter = holo_beam * sin(proj * 60.0) * 0.008 * (abs(transition_turn_dir) + 0.35);
		sample_uv.x = clamp(sample_uv.x + jitter, 0.001, 0.999);
	}

	if (enable_secondary_jiggle && (dot(secondary_jiggle_l_px, secondary_jiggle_l_px) > 0.0001 || dot(secondary_jiggle_r_px, secondary_jiggle_r_px) > 0.0001)) {
		vec2 sec_m = texture(secondary_jiggle_mask_tex, sample_uv).rg;
		vec2 jiggle_uv = (secondary_jiggle_l_px * sec_m.r + secondary_jiggle_r_px * sec_m.g) * TEXTURE_PIXEL_SIZE;
		sample_uv = clamp(sample_uv - jiggle_uv, vec2(0.001), vec2(0.999));
	}

	vec4 nd_sample = vec4(0.5, 0.5, 1.0, 0.5);
	if (use_normal_depth) {
		nd_sample = texture(normal_depth_tex, sample_uv);
		vec2 total_tilt = banking_tilt_2d;
		float px_mul = depth_parallax_px;
		if (transition_fx_mode == 1 && transition_fx_strength > 0.005) {
			total_tilt += vec2(transition_turn_dir * transition_fx_strength * 3.2, 0.0);
			px_mul = max(px_mul, 5.4);
		}
		float pre_a = texture(TEXTURE, sample_uv).a;
		float parallax_edge_w = smoothstep(0.55, 0.90, pre_a);
		if (dot(total_tilt, total_tilt) > 0.0001 && px_mul > 0.01 && parallax_edge_w > 0.001) {
			vec2 parallax_uv = clamp(
				sample_uv - total_tilt * (nd_sample.a - 0.45) * px_mul * parallax_edge_w * TEXTURE_PIXEL_SIZE,
				vec2(0.001),
				vec2(0.999)
			);
			vec4 p_base = texture(TEXTURE, parallax_uv);
			if (p_base.a > 0.28) {
				sample_uv = mix(sample_uv, parallax_uv, parallax_edge_w);
				nd_sample = texture(normal_depth_tex, sample_uv);
			}
		}
	}

	vec4 base = texture(TEXTURE, sample_uv);
	float aa_a = clamp(fwidth(base.a) * 0.85, 0.10, 0.45);
	bool valid_nd = use_normal_depth && (dot(nd_sample.rgb, nd_sample.rgb) > 0.01);
	vec3 n25 = vec3(0.0, 0.0, 1.0);
	float ndl = 0.5;
	if (valid_nd) {
		n25 = normalize(nd_sample.rgb * 2.0 - vec3(1.0));
		n25.x *= normal_flip_x;
		vec3 l3 = normalize(vec3(light_dir_2d, 0.58));
		ndl = dot(n25, l3);
	}
	vec4 raw_mask = textureLod(id_mask_tex, sample_uv, 0.0);
	float w_r = raw_mask.r;
	float w_g = raw_mask.g;
	float w_b = raw_mask.b;
	float w_a = raw_mask.a;
	float w_skin = clamp(1.0 - (w_r + w_g + w_b + w_a), 0.0, 1.0);
	// Normalización cúbica por canal: mantiene frontera subpíxel limpia asegurando suma == 1.0 sin halos del color original
	float p_r = w_r * w_r * w_r;
	float p_g = w_g * w_g * w_g;
	float p_b = w_b * w_b * w_b;
	float p_a = w_a * w_a * w_a;
	float p_s = w_skin * w_skin * w_skin;
	float p_sum = max(p_r + p_g + p_b + p_a + p_s, 0.0001);
	vec4 mask = vec4(p_r, p_g, p_b, p_a) / p_sum;
	float hair_cov = 0.0;
	if (is_head_part) {
		vec2 hc_px = TEXTURE_PIXEL_SIZE * max(head_outline_width_px, 4.0) * 0.70710678;
		hair_cov = raw_mask.a;
		hair_cov = max(hair_cov, texture(id_mask_tex, clamp(sample_uv + vec2(0.0, -TEXTURE_PIXEL_SIZE.y * 2.5), vec2(0.0), vec2(1.0))).a);
		hair_cov = max(hair_cov, texture(id_mask_tex, clamp(sample_uv + vec2(hc_px.x, hc_px.y), vec2(0.0), vec2(1.0))).a);
		hair_cov = max(hair_cov, texture(id_mask_tex, clamp(sample_uv + vec2(-hc_px.x, hc_px.y), vec2(0.0), vec2(1.0))).a);
		hair_cov = max(hair_cov, texture(id_mask_tex, clamp(sample_uv + vec2(hc_px.x, -hc_px.y), vec2(0.0), vec2(1.0))).a);
		hair_cov = max(hair_cov, texture(id_mask_tex, clamp(sample_uv + vec2(-hc_px.x, -hc_px.y), vec2(0.0), vec2(1.0))).a);
	}
	float is_hair = is_head_part ? smoothstep(0.12, 0.38, hair_cov) : 0.0;

	float head_out_alpha = 0.0;
	bool allow_head_outline = (head_layer_pass != 1) || (head_over_face_keep < 0.5) || (is_hair < 0.5);
	if (is_head_part && allow_head_outline && head_outline_strength > 0.01 && base.a < 0.98) {
		float neck_fade = mix(1.0 - smoothstep(0.80, 0.86, sample_uv.y), 1.0, is_hair);
		if (use_head_outline_sdf) {
			float dist_px = texture(head_outline_sdf_tex, sample_uv).r * 32.0;
			float head_zoom_fade = 1.0 - smoothstep(5.5, 13.0, screen_px_in_texels) * 0.55;
			float eff_head_w = head_outline_width_px * head_zoom_fade;
			float aa_half = clamp(screen_px_in_texels * 0.25, 0.50, max(eff_head_w * 0.45, 1.25));
			float edge_aa = 1.0 - smoothstep(max(eff_head_w - aa_half, 0.0), eff_head_w + aa_half, dist_px);
			head_out_alpha = edge_aa * head_outline_strength * neck_fade;
		} else {
			vec2 opx = TEXTURE_PIXEL_SIZE * min(head_outline_width_px, 4.0);
			float max_na = 0.0;
			max_na = max(max_na, texture(TEXTURE, clamp(sample_uv + vec2(opx.x, 0.0), vec2(0.0), vec2(1.0))).a);
			max_na = max(max_na, texture(TEXTURE, clamp(sample_uv + vec2(-opx.x, 0.0), vec2(0.0), vec2(1.0))).a);
			max_na = max(max_na, texture(TEXTURE, clamp(sample_uv + vec2(0.0, opx.y), vec2(0.0), vec2(1.0))).a);
			max_na = max(max_na, texture(TEXTURE, clamp(sample_uv + vec2(0.0, -opx.y), vec2(0.0), vec2(1.0))).a);
			head_out_alpha = smoothstep(0.22, 0.48, max_na) * head_outline_strength * neck_fade;
		}
		if (head_layer_pass == 1) {
			head_out_alpha *= (1.0 - is_hair);
		}
	}
	if (base.a < 0.02 && head_out_alpha < 0.01) {
		discard;
	}

	vec3 rgb = base.rgb;
	vec3 srgb_base = linear_to_srgb(base.rgb);
	float orig_luma = dot(srgb_base, vec3(0.299, 0.587, 0.114));

	// Las máscaras 1:1 cerradas por tinta ya separan Piel, Medias, Traje, Armadura, Acentos y Pelo sin override por color RGB.

	// 3.5 Separación Z Automática Cabeza vs Torso (Pelo sobre Torso / Cuello y Mentón bajo Torso en N)
	float layer_alpha = 1.0;
	float is_hair_pass = 0.0;
	if (is_head_part && head_layer_pass > 0) {
		is_hair_pass = is_hair;
		if (head_layer_pass == 1) {
			// Pass 1 (Detrás del torso): recortar borde exterior del cabello para evitar fantasmas tras Pass 2.
			layer_alpha = mix(1.0, smoothstep(0.82, 0.98, base.a), is_hair);
		} else if (head_layer_pass == 2) {
			if (head_over_face_keep < 0.5) {
				// Vista Espalda (N): SOLO el cabello y su tinta exterior van por encima del torso
				layer_alpha = is_hair * max(smoothstep(0.0, 0.12, base.a), smoothstep(0.0, 0.08, head_out_alpha));
			} else {
				// Vista Frente (S): cabello + rostro/mentón van encima, el cuello/collar inferior se mete detrás del torso sin fantasmas
				float is_collar = smoothstep(0.80, 0.85, sample_uv.y) * (1.0 - is_hair);
				layer_alpha = 1.0 - is_collar;
			}
		}
		if (layer_alpha < 0.02) {
			discard;
		}
	}

	if (!is_head_part && arm_layer_pass > 0) {
		float over_w = 0.0;
		if (use_arm_over_mask) {
			vec4 am = texture(arm_over_mask_tex, sample_uv);
			if (arm_over_from_anim_mask) {
				over_w = smoothstep(0.30, 0.58, (am.g + am.b) - am.r * 0.65);
			} else {
				over_w = smoothstep(0.35, 0.65, am.r);
			}
		} else {
			over_w = smoothstep(0.34, 0.46, sample_uv.y);
		}
		if (arm_layer_pass == 1) {
			layer_alpha *= 1.0 - smoothstep(0.54, 0.64, over_w);
		} else if (arm_layer_pass == 2) {
			if (over_w < 0.48) {
				discard;
			}
			layer_alpha *= smoothstep(0.48, 0.56, over_w);
		}
		if (layer_alpha < 0.02) {
			discard;
		}
	}

	float hair_fx_weight = is_head_part ? mask.a * 0.85 : 0.0;
	float mat_weight = clamp(mask.r + mask.g + mask.b + (is_head_part ? mask.a : 0.0), 0.0, 1.0);
	float armor_suit_weight = clamp(mask.b + mask.g + mask.r * 0.6 + hair_fx_weight, 0.0, 1.0);

	// 4. Recoloreo de Traje, Armadura, Acentos y Medias (Usando `recolor_method` + Luminancia Estabilizada)
	bool need_hair_recolor = is_head_part && mask.a > 0.01 && (enable_shader_recolor || enable_hair_recolor || hair_style_mode > 0);
	float stab_luma = orig_luma;
	if ((enable_shader_recolor || need_hair_recolor) && debug_view_mode == 0) {
		stab_luma = sample_same_id_luma(TEXTURE, id_mask_tex, sample_uv, TEXTURE_PIXEL_SIZE, raw_mask, orig_luma, is_head_part);
	}
	if (enable_shader_recolor) {
		// Normalizar la luminancia interna de cada material respecto a su rango en el dibujo original:
		// - Traje Oscuro (mask.b): stab_luma va de ~0.12 (sombra) a ~0.27 (luz)
		// - Paneles Armadura (mask.g): stab_luma va de ~0.20 (sombra) a ~0.46 (luz)
		// - Acentos Rojos (mask.r): stab_luma va de ~0.18 (sombra) a ~0.42 (luz)
		float t_suit = clamp((stab_luma - 0.06) / 0.21, 0.0, 1.0);
		float t_panel = clamp((stab_luma - 0.19) / 0.27, 0.0, 1.0);
		float t_acc = clamp((stab_luma - 0.17) / 0.25, 0.0, 1.0);

		vec3 target_suit = apply_recolor_algorithm(suit_dark_color.rgb, t_suit, stab_luma, 0.19, recolor_method);
		vec3 target_panel = apply_recolor_algorithm(panel_color.rgb, t_panel, stab_luma, 0.32, recolor_method);
		vec3 target_acc = apply_recolor_algorithm(accent_color.rgb, t_acc, stab_luma, 0.29, recolor_method);

		float recolor_ink_keep = smoothstep(0.05, 0.13, orig_luma);
		rgb = mix(rgb, target_suit, mask.b * recolor_ink_keep);
		rgb = mix(rgb, target_panel, mask.g * recolor_ink_keep);
		rgb = mix(rgb, target_acc, mask.r * recolor_ink_keep);

		if (!is_head_part && mask.a > 0.01) {
			float garter_protect = smoothstep(0.07, 0.15, stab_luma);
			float nylon_opacity = clamp(stocking_tint_strength * 1.15 * garter_protect, 0.0, 0.90);
			float t_nylon = clamp((stab_luma - 0.10) / 0.28, 0.0, 1.0);
			vec3 nylon_base = apply_recolor_algorithm(suit_dark_color.rgb, t_nylon, stab_luma, 0.22, recolor_method);
			vec3 nylon_sheen = mix(nylon_base, vec3(0.95, 0.88, 0.84) * max(suit_dark_color.rgb * 1.6, vec3(0.28)), smoothstep(0.55, 0.95, t_nylon) * 0.42);
			rgb = mix(rgb, clamp(nylon_sheen, vec3(0.0), vec3(1.0)), mask.a * nylon_opacity * recolor_ink_keep);
		}
	}

	// 5. Laboratorio de Recoloreo y Estilo de Cabello (`is_head_part` + `mask.a`)
	if (need_hair_recolor) {
		float t_hair = clamp((stab_luma - 0.48) / 0.36, 0.0, 1.0);
		vec3 base_hair_col = apply_recolor_algorithm(hair_color.rgb, t_hair, stab_luma, 0.74, recolor_method);
		float soft = max(hair_cut_softness, 0.015);

		if (hair_style_mode == 1) {
			// Modo 1: Bicolor Trigger / Edgerunners (Umbral regulable por hair_cut_height y hair_cut_softness)
			float is_lit_strand = smoothstep(hair_cut_height - soft * 0.5, hair_cut_height + soft * 0.5, t_hair);
			vec3 under_dye = mix(hair_secondary_color.rgb * 0.88, base_hair_col, 1.0 - hair_effect_strength);
			base_hair_col = mix(under_dye, base_hair_col, is_lit_strand);
		} else if (hair_style_mode == 2) {
			// Modo 2: Puntas Teñidas / Dip-Dye (Altura y transición regulables)
			float tip_factor = smoothstep(hair_cut_height - soft, hair_cut_height + soft, UV.y);
			vec3 tip_col = apply_recolor_algorithm(hair_secondary_color.rgb, t_hair, stab_luma, 0.74, recolor_method);
			base_hair_col = mix(base_hair_col, tip_col, tip_factor * hair_effect_strength);
		} else if (hair_style_mode == 3) {
			// Modo 3: Halo Especular Anime ("Angel Ring" en la corona superior)
			float arch_y = (hair_cut_height * 0.65) + sin(UV.x * 3.14159) * 0.045;
			float halo_band = 1.0 - smoothstep(soft * 0.14, soft * 0.38, abs(UV.y - arch_y));
			float lit_gate = smoothstep(0.32, 0.58, t_hair);
			vec3 ring_col = mix(hair_secondary_color.rgb, vec3(1.0), 0.55);
			base_hair_col = mix(base_hair_col * 0.90, ring_col, halo_band * lit_gate * hair_effect_strength);
		}

		float hair_ink_keep = smoothstep(0.08, 0.18, orig_luma);
		rgb = mix(rgb, clamp(base_hair_col, vec3(0.0), vec3(1.0)), mask.a * 0.96 * hair_ink_keep);
	}

	if (is_head_part && head_layer_pass == 1 && debug_view_mode == 0 && is_hair_pass > 0.01) {
		float pass1_hair_ink = smoothstep(0.08, 0.18, orig_luma);
		vec3 hair_mid_fill = hair_color.rgb * 0.72;
		rgb = mix(rgb, hair_mid_fill, is_hair_pass * pass1_hair_ink);
	}

	// 6. Personalidad de Sombreado por Identidad Visual (Regulable por Sliders del Filtro)
	vec3 abyssal_ink = srgb_to_linear(vec3(0.015, 0.015, 0.025));
	// El cabello plateado vive en orig_luma 0.48..0.85; remapeamos su luminancia interna a 0.14..0.56
	// para que Cel-Step, Noir Crush y Halftone respondan igual que en el traje/armadura.
	float hair_fx_luma = clamp((orig_luma - 0.48) / 0.36, 0.0, 1.0) * 0.42 + 0.14;
	float fx_luma = is_head_part ? mix(orig_luma, hair_fx_luma, mask.a) : orig_luma;

	float eff_cel_step = cel_step_strength;
	if (eff_cel_step > 0.01) {
		float b1 = smoothstep(0.20, 0.24, fx_luma);
		float b2 = smoothstep(0.37, 0.42, fx_luma);
		float stepped_factor = (0.72 + b1 * 0.22 + b2 * 0.22);
		rgb = mix(rgb, clamp(rgb * stepped_factor, vec3(0.0), vec3(1.0)), armor_suit_weight * eff_cel_step);
	}

	if (noir_shadow_crush > 0.01) {
		float noir_w = clamp(mask.b + mask.g * 0.7 + (is_head_part ? mask.a * 0.55 : 0.0), 0.0, 1.0);
		float p5_shadow = (1.0 - smoothstep(noir_shadow_threshold - 0.02, noir_shadow_threshold + 0.02, fx_luma)) * noir_w;
		rgb = mix(rgb, abyssal_ink, p5_shadow * noir_shadow_crush);
		rgb = mix(rgb, clamp(rgb * (1.0 + 0.28 * noir_shadow_crush), vec3(0.0), vec3(1.0)), mask.r);
	}

	if (metal_sheen_strength > 0.01) {
		float spec_band = smoothstep(0.36, 0.46, orig_luma) * (1.0 - smoothstep(0.54, 0.66, orig_luma));
		float aniso_wave = 0.5 + 0.5 * sin((UV.x * 6.0 + UV.y * 10.0) + q_time * 1.4);
		vec3 metal_sheen = mix(panel_color.rgb, vec3(1.0), 0.65) * spec_band * (0.55 + 0.45 * aniso_wave);
		rgb = clamp(rgb + metal_sheen * mask.g * metal_sheen_strength * 0.55, vec3(0.0), vec3(1.0));
		float sub_band = smoothstep(0.16, 0.24, orig_luma) * (1.0 - smoothstep(0.26, 0.34, orig_luma));
		rgb = clamp(rgb + accent_color.rgb * sub_band * (mask.b + mask.g) * (metal_sheen_strength * 0.18), vec3(0.0), vec3(1.0));
	}

	// 7. Refuerzo de Tinta Negra (#040406) — estricto sobre línea de tinta sin absorber sombras del traje
	if (ink_boost > 0.01) {
		float ink_zone = (1.0 - smoothstep(0.035, 0.085, orig_luma));
		rgb = mix(rgb, abyssal_ink, clamp(ink_zone * ink_boost, 0.0, 0.94));
	}

	// 8. Sistema de Trama Semitono / Hatching (Curvado por n25.xy * depth)
	if (enable_halftone && halftone_strength > 0.01) {
		vec2 ht_coord = FRAGCOORD.xy + (valid_nd ? n25.xy * nd_sample.a * 14.0 : vec2(0.0));
		float pat_shadow = compute_halftone_pattern(ht_coord, halftone_scale, halftone_pattern_type, halftone_angle_deg);
		float zone_mask = 0.0;
		float thr = halftone_threshold;
		if (halftone_zone_mode == 0) {
			float shadow_band = smoothstep(0.12, 0.18, fx_luma) * (1.0 - smoothstep(thr - 0.06, thr + 0.06, fx_luma));
			zone_mask = shadow_band * armor_suit_weight;
		} else if (halftone_zone_mode == 1) {
			float mid_dark = smoothstep(0.12, 0.18, fx_luma) * (1.0 - smoothstep(thr + 0.12, thr + 0.26, fx_luma));
			zone_mask = mid_dark * armor_suit_weight;
		} else if (halftone_zone_mode == 2) {
			zone_mask = smoothstep(0.12, 0.18, fx_luma) * (1.0 - smoothstep(thr + 0.08, thr + 0.24, fx_luma)) * mat_weight;
		} else {
			float shadow_band = smoothstep(0.12, 0.18, fx_luma) * (1.0 - smoothstep(thr - 0.05, thr + 0.06, fx_luma));
			zone_mask = shadow_band * armor_suit_weight;
		}
		rgb = mix(rgb, abyssal_ink, pat_shadow * zone_mask * clamp(halftone_strength, 0.0, 0.92));

		if (halftone_zone_mode == 3 || pipeline_style_mode == 4) {
			float pat_light = compute_halftone_pattern(ht_coord + vec2(3.5, 3.5), halftone_scale * 0.90, 0, halftone_angle_deg + 15.0);
			float hi_band = smoothstep(thr - 0.04, thr + 0.06, fx_luma) * clamp(mask.g + mask.r + (is_head_part ? mask.a * 0.5 : 0.0), 0.0, 1.0);
			vec3 pop_hi = mix(rgb, vec3(1.0), 0.45) + accent_color.rgb * 0.18;
			rgb = mix(rgb, clamp(pop_hi, vec3(0.0), vec3(1.0)), pat_light * hi_band * clamp(halftone_strength * 1.15, 0.0, 0.88));
		}
	}

	// 9. Luz de Reborde (Rim-Light Simple y Dual-Rim con Ancho e Intensidad Regulables)
	float edge_alpha_guard = smoothstep(0.65, 0.95, base.a);
	if (suppress_alpha_rim < 0.5 && (rim_light_strength > 0.01 || dual_rim_strength > 0.01)) {
		vec2 px = TEXTURE_PIXEL_SIZE * rim_width_px;
		if (rim_light_strength > 0.01) {
			float a_left = texture(TEXTURE, clamp(sample_uv + vec2(-px.x, -px.y * 0.6), vec2(0.0), vec2(1.0))).a;
			float rim_left = clamp(base.a - a_left, 0.0, 1.0) * smoothstep(0.14, 0.26, orig_luma) * edge_alpha_guard;
			vec3 rim_col_a = mix(accent_color.rgb, vec3(1.0), 0.35);
			rgb = clamp(rgb + rim_col_a * rim_left * rim_light_strength * mat_weight, vec3(0.0), vec3(1.0));
		}
		if (dual_rim_strength > 0.01) {
			float a_right = texture(TEXTURE, clamp(sample_uv + vec2(px.x * 1.1, -px.y * 0.4), vec2(0.0), vec2(1.0))).a;
			float rim_right = clamp(base.a - a_right, 0.0, 1.0) * smoothstep(0.14, 0.26, orig_luma) * edge_alpha_guard;
			vec3 cyan_rim = vec3(0.0, 0.94, 1.0);
			rgb = clamp(rgb + cyan_rim * rim_right * dual_rim_strength * mat_weight, vec3(0.0), vec3(1.0));
		}
	}

	// 9.5 Iluminación Direccional 2.5D + Rim Cónico Key/Fill (Sapiens Normals + Depth)
	if (valid_nd) {
		float ink_protect = smoothstep(0.08, 0.16, orig_luma) * edge_alpha_guard;
		float cel_min = is_head_part ? mix(0.90, 0.82, mask.a) : 0.88;
		float cel_max = is_head_part ? mix(1.08, 1.15, mask.a) : 1.15;
		float depth_bias = max(nd_sample.a - 0.5, -0.08) * 0.24;
		float cel_n = mix(cel_min, cel_max, smoothstep(-0.20, 0.34, ndl + depth_bias));
		rgb *= mix(1.0, cel_n, normal_cel_influence * ink_protect);

		if (normal_rim_strength > 0.01) {
			vec2 conic_uv = clamp(vec2(0.5) + n25.xy * 0.46, vec2(0.02), vec2(0.98));
			vec3 conic_col = texture(conic_rim_lut, conic_uv).rgb;
			float grazing = pow(clamp(1.0 - max(n25.z, 0.0), 0.0, 1.0), 2.1);
			float depth_pop = mix(0.65, 1.25, nd_sample.a);
			float rim_scale = is_head_part ? mix(0.28, 0.42, mask.a) : 0.45;
			float key_align = clamp(dot(n25.xy, normalize(light_dir_2d)) * 0.5 + 0.5, 0.0, 1.0);
			float key_rim = smoothstep(0.32, 0.86, key_align);
			float fill_rim = smoothstep(0.32, 0.86, 1.0 - key_align) * 0.42;
			vec3 rim_split = conic_col * (key_rim + fill_rim * vec3(0.65, 0.82, 1.0));
			rgb += rim_split * grazing * depth_pop * normal_rim_strength * ink_protect * rim_scale;
		}

		// Transición Estilizada 1: Barrido de sombra cel direccional + Rim Fresnel siguiendo las Normales 3D
		if (transition_fx_mode == 1 && transition_fx_strength > 0.005) {
			vec3 turn_l = normalize(vec3(light_dir_2d.x + transition_turn_dir * transition_fx_strength * 1.45, light_dir_2d.y, 0.48));
			float turn_ndl = dot(n25, turn_l);
			float cel_sweep_shadow = 1.0 - smoothstep(-0.22, 0.28, turn_ndl);
			rgb = mix(rgb, rgb * vec3(0.52, 0.58, 0.78), cel_sweep_shadow * transition_fx_strength * 0.62 * ink_protect);
			float turn_fresnel = pow(clamp(1.0 - max(n25.z, 0.0), 0.0, 1.0), 1.35) * smoothstep(-0.08, 0.55, abs(n25.x));
			vec3 turn_rim_col = mix(accent_color.rgb, vec3(0.18, 0.96, 1.0), 0.38);
			rgb += turn_rim_col * turn_fresnel * transition_fx_strength * ink_protect * 0.95;
		}
	}

	// Transición Estilizada 2: Anime Ink-Smear + Silhouette Rim-Flash (oculta costuras detrás de flash limpio + tinta intacta)
	if (transition_fx_mode == 2 && transition_fx_strength > 0.005) {
		float ink_protect_smear = smoothstep(0.11, 0.22, orig_luma);
		float flash_w = smoothstep(0.22, 0.88, transition_fx_strength);
		vec3 flash_grad = mix(accent_color.rgb * 1.15, vec3(0.95, 0.99, 1.0), nd_sample.a * 0.62);
		rgb = mix(rgb, flash_grad, flash_w * ink_protect_smear * 0.88);
	}

	// Transición Estilizada 3: Borde láser Holo-Sweep Cyber-Cut
	if (holo_beam > 0.005) {
		vec3 beam_col = mix(accent_color.rgb, vec3(0.15, 0.96, 1.0), 0.58) * 1.45;
		rgb = clamp(mix(rgb, beam_col, holo_beam * 0.92), vec3(0.0), vec3(max(crt_hdr_boost, 1.25)));
	}

	// Sombra de contacto AO sutil en encaje superior de muslos bajo la pelvis (sin recortar alpha)
	if (is_leg_part && debug_view_mode == 0) {
		float hip_ao = 1.0 - smoothstep(0.0, 0.09, sample_uv.y);
		rgb *= mix(1.0, 0.82, hip_ao);
	}

	// 10. Pulso Holográfico + Boost HDR CRT
	float hdr_cap = max(crt_hdr_boost, 1.0);
	rgb = clamp(rgb, vec3(0.0), vec3(hdr_cap));

	float pulse = 1.0 + 0.14 * sin(q_time * pulse_speed);
	vec3 emissive_boost = rgb * (glow_intensity * pulse) * mask.r * 0.42 * hdr_cap * edge_alpha_guard;
	rgb = clamp(rgb + emissive_boost, vec3(0.0), vec3(hdr_cap));

	// 10.5 Outline Exterior de Tinta + De-Matting + Inward Ink-Seal Adaptativo (después de iluminación 2.5D y HDR)
	bool is_neck_seam = (!is_head_part && !is_leg_part && arm_layer_pass == 0 && sample_uv.y < 0.075 && abs(sample_uv.x - 0.42) < 0.14);
	vec2 seal_px = TEXTURE_PIXEL_SIZE * clamp(screen_px_in_texels * 0.45, 1.5, 3.2);
	vec2 seal_diag = seal_px * 0.70710678;
	float min_nb_a = min(
		min(
			min(texture(TEXTURE, clamp(sample_uv + vec2(seal_px.x, 0.0), vec2(0.0), vec2(1.0))).a,
				texture(TEXTURE, clamp(sample_uv + vec2(-seal_px.x, 0.0), vec2(0.0), vec2(1.0))).a),
			min(texture(TEXTURE, clamp(sample_uv + vec2(0.0, seal_px.y), vec2(0.0), vec2(1.0))).a,
				texture(TEXTURE, clamp(sample_uv + vec2(0.0, -seal_px.y), vec2(0.0), vec2(1.0))).a)
		),
		min(
			min(texture(TEXTURE, clamp(sample_uv + vec2(seal_diag.x, seal_diag.y), vec2(0.0), vec2(1.0))).a,
				texture(TEXTURE, clamp(sample_uv + vec2(-seal_diag.x, seal_diag.y), vec2(0.0), vec2(1.0))).a),
			min(texture(TEXTURE, clamp(sample_uv + vec2(seal_diag.x, -seal_diag.y), vec2(0.0), vec2(1.0))).a,
				texture(TEXTURE, clamp(sample_uv + vec2(-seal_diag.x, -seal_diag.y), vec2(0.0), vec2(1.0))).a)
		)
	);
	float seal_edge_gate = clamp((1.0 - smoothstep(0.55, 0.92, base.a)) + (1.0 - smoothstep(0.12, 0.22, orig_luma)), 0.0, 1.0);
	float inward_seal = (1.0 - smoothstep(0.18, 0.62, min_nb_a)) * seal_edge_gate;
	if ((is_leg_part && sample_uv.y < 0.08) || is_neck_seam) {
		inward_seal = 0.0;
	}
	if (is_head_part && (!allow_head_outline || sample_uv.y >= 0.80 || (head_layer_pass == 1 && is_hair > 0.5))) {
		inward_seal = 0.0;
	}
	float head_mip_guard = is_head_part ? (1.0 - smoothstep(5.5, 11.5, screen_px_in_texels) * 0.75) : 1.0;

	if (debug_view_mode == 0) {
		if (head_out_alpha > 0.005) {
			float out_fill = 1.0 - smoothstep(0.32, 0.72, base.a);
			float head_bright_fringe = (1.0 - smoothstep(0.58, 0.92, base.a)) * smoothstep(0.24, 0.46, orig_luma) * head_mip_guard;
			rgb = mix(rgb, abyssal_ink, clamp(max(max(out_fill, head_bright_fringe), inward_seal * head_mip_guard), 0.0, 1.0));
		} else if (!is_head_part && !is_neck_seam && (base.a < 0.92 || inward_seal > 0.01)) {
			float body_aa_ink = 1.0 - smoothstep(0.14, 0.56, base.a);
			float bright_fringe = (1.0 - smoothstep(0.60, 0.92, base.a)) * smoothstep(0.24, 0.44, orig_luma);
			rgb = mix(rgb, abyssal_ink, clamp(max(max(body_aa_ink, bright_fringe), inward_seal), 0.0, 1.0));
		} else if (is_head_part && allow_head_outline && (base.a < 0.92 || inward_seal > 0.01)) {
			float head_aa_ink = 1.0 - smoothstep(0.14, 0.48, base.a);
			float head_bright_fringe = (1.0 - smoothstep(0.58, 0.92, base.a)) * smoothstep(0.24, 0.46, orig_luma) * head_mip_guard;
			rgb = mix(rgb, abyssal_ink, clamp(max(max(head_aa_ink, head_bright_fringe), inward_seal * head_mip_guard), 0.0, 1.0));
		}
	}

	// 11. Inspector de Rayos-X (1-Click Debug)
	if (debug_view_mode == 1) {
		// Clown-Pass ID Visual: Rojo=Acentos, Azul=Paneles, Magenta=Traje, Cian=Pelo, Verde=Medias, Amarillo=Piel
		vec3 dbg = vec3(1.0, 0.92, 0.15); // Piel por defecto
		dbg = mix(dbg, vec3(0.95, 0.15, 0.95), mask.b);
		dbg = mix(dbg, vec3(0.10, 0.40, 1.00), mask.g);
		dbg = mix(dbg, vec3(1.00, 0.12, 0.18), mask.r);
		if (is_head_part) {
			dbg = mix(dbg, vec3(0.0, 0.95, 1.0), mask.a);
		} else if (mask.a > 0.01) {
			dbg = mix(dbg, vec3(0.1, 1.0, 0.2), mask.a);
		}
		float ink_line = 1.0 - smoothstep(0.11, 0.16, orig_luma);
		rgb = mix(dbg, abyssal_ink, ink_line);
	} else if (debug_view_mode == 2) {
		// Mapa de Luminancia Original
		rgb = vec3(orig_luma);
	} else if (debug_view_mode == 3) {
		// Solo Líneas de Tinta y Silueta sobre Blanco Puro
		float ink_line = 1.0 - smoothstep(0.10, 0.22, orig_luma);
		rgb = mix(vec3(1.0), abyssal_ink, clamp(ink_line * (1.0 + ink_boost), 0.0, 1.0));
	} else if (debug_view_mode == 4) {
		// Mapa de Normales 2.5D (Sapiens-Lite)
		rgb = nd_sample.rgb;
	} else if (debug_view_mode == 5) {
		// Mapa de Profundidad 2.5D (Depth-Anything-V2)
		rgb = vec3(nd_sample.a);
	}

	if (hit_flash > 0.0) {
		rgb = mix(rgb, vec3(1.0, 0.25, 0.25), hit_flash);
	}

	float zoom_out_bias = is_head_part ? 0.0 : smoothstep(2.0, 5.5, screen_px_in_texels);
	float alpha_mid = mix(0.50, 0.46, zoom_out_bias);
	float crisp_base_a = is_neck_seam ? base.a : smoothstep(max(alpha_mid - aa_a, 0.02), min(alpha_mid + aa_a, 0.98), base.a);
	float final_alpha = max(crisp_base_a, head_out_alpha);
	COLOR = vec4(rgb, final_alpha * v_modulate_alpha * layer_alpha);
}
