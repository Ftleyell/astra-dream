shader_type canvas_item;
render_mode blend_mix;

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
uniform bool is_cape_part = false;
uniform bool is_hips_legs_part = false;

uniform float leg_weight_shift : hint_range(-1.0, 1.0) = 0.0;

uniform vec4 accent_color : source_color = vec4(1.0, 0.12, 0.35, 1.0);
uniform vec4 panel_color : source_color = vec4(0.36, 0.39, 0.48, 1.0);
uniform vec4 suit_dark_color : source_color = vec4(0.11, 0.12, 0.18, 1.0);
uniform vec4 hair_color : source_color = vec4(0.86, 0.89, 0.96, 1.0);
uniform vec4 hair_secondary_color : source_color = vec4(1.0, 0.12, 0.35, 1.0);

uniform bool is_torso_elastic_bust = false;
uniform vec2 bust_uv_disp_l = vec2(0.0, 0.0);
uniform vec2 bust_uv_disp_r = vec2(0.0, 0.0);

uniform float cape_wind_strength : hint_range(0.0, 2.0) = 1.0;

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

// Inspector Rayos-X (0=Render Final, 1=Clown-Pass ID, 2=Luminancia Original, 3=Solo Tinta/Bordes)
uniform int debug_view_mode : hint_range(0, 3) = 0;

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

void fragment() {
	vec2 sample_uv = UV;
	float bounce_shade = 0.0;

	// 1. Deformación Elástica Autónoma del Busto en el Torso
	if (is_torso_elastic_bust) {
		vec2 center_l = vec2(0.45, 0.34);
		vec2 center_r = vec2(0.75, 0.35);
		vec2 radii_l = vec2(0.28, 0.20);
		vec2 radii_r = vec2(0.26, 0.20);

		vec2 dl = (UV - center_l) / radii_l;
		vec2 dr = (UV - center_r) / radii_r;

		float wl = exp(-dot(dl, dl) * 2.2);
		float wr = exp(-dot(dr, dr) * 2.2);

		float border_lock = smoothstep(0.12, 0.22, UV.y) * (1.0 - smoothstep(0.54, 0.66, UV.y));
		wl *= border_lock;
		wr *= border_lock;

		vec2 total_uv_shift = bust_uv_disp_l * wl + bust_uv_disp_r * wr;
		sample_uv = clamp(UV - total_uv_shift, vec2(0.001), vec2(0.999));
		bounce_shade = (bust_uv_disp_l.y * wl + bust_uv_disp_r.y * wr) * 1.35;
	}

	// 2. Swing de Balance de Peso entre Piernas (Botas 100% plantadas en el piso)
	if (is_hips_legs_part && abs(leg_weight_shift) > 0.0001) {
		float swing_profile = smoothstep(0.91, 0.18, UV.y);
		float knee_flex = sin(swing_profile * 3.14159265) * 0.12;
		float horiz_weight = clamp(swing_profile + knee_flex * (1.0 - swing_profile), 0.0, 1.0);

		float dx_uv = leg_weight_shift * 0.026 * horiz_weight;
		float hip_tilt_y = (UV.x - 0.48) * leg_weight_shift * 0.011 * swing_profile;
		float arc_dip_y = (1.0 - abs(leg_weight_shift)) * 0.0025 * swing_profile;

		sample_uv.x = clamp(sample_uv.x - dx_uv, 0.001, 0.999);
		sample_uv.y = clamp(sample_uv.y - (hip_tilt_y + arc_dip_y), 0.001, 0.999);
	}

	// 3. Ondulación de Viento en la Capa
	if (is_cape_part && cape_wind_strength > 0.01) {
		float cloth_weight = smoothstep(0.18, 0.85, UV.y);
		float wave1 = sin(TIME * 2.4 - UV.y * 5.2 + UV.x * 2.0) * 0.014;
		float wave2 = cos(TIME * 3.8 - UV.y * 8.5) * 0.006;
		sample_uv.x = clamp(sample_uv.x + (wave1 + wave2) * cloth_weight * cape_wind_strength, 0.001, 0.999);
	}

	vec4 base = texture(TEXTURE, sample_uv);
	if (base.a < 0.01) {
		discard;
	}

	vec4 mask = texture(id_mask_tex, sample_uv);
	vec3 rgb = base.rgb;
	float orig_luma = dot(rgb, vec3(0.299, 0.587, 0.114));

	float mat_weight = clamp(mask.r + mask.g + mask.b + (is_head_part ? mask.a : 0.0), 0.0, 1.0);
	float armor_suit_weight = clamp(mask.b + mask.g + mask.r * 0.6, 0.0, 1.0);

	// 4. Recoloreo de Traje, Armadura, Acentos y Medias (Usando `recolor_method`)
	if (enable_shader_recolor) {
		// Normalizar la luminancia interna de cada material respecto a su rango en el dibujo original:
		// - Traje Oscuro (mask.b): orig_luma va de ~0.12 (sombra) a ~0.27 (luz)
		// - Paneles Armadura (mask.g): orig_luma va de ~0.20 (sombra) a ~0.46 (luz)
		// - Acentos Rojos (mask.r): orig_luma va de ~0.18 (sombra) a ~0.42 (luz)
		float t_suit = clamp((orig_luma - 0.11) / 0.17, 0.0, 1.0);
		float t_panel = clamp((orig_luma - 0.19) / 0.27, 0.0, 1.0);
		float t_acc = clamp((orig_luma - 0.17) / 0.25, 0.0, 1.0);

		vec3 target_suit = apply_recolor_algorithm(suit_dark_color.rgb, t_suit, orig_luma, 0.19, recolor_method);
		vec3 target_panel = apply_recolor_algorithm(panel_color.rgb, t_panel, orig_luma, 0.32, recolor_method);
		vec3 target_acc = apply_recolor_algorithm(accent_color.rgb, t_acc, orig_luma, 0.29, recolor_method);

		rgb = mix(rgb, target_suit, mask.b);
		rgb = mix(rgb, target_panel, mask.g);
		rgb = mix(rgb, target_acc, mask.r);

		if (is_hips_legs_part && mask.a > 0.01) {
			float garter_or_edge = 1.0 - smoothstep(0.20, 0.32, orig_luma);
			float nylon_opacity = clamp(stocking_tint_strength * (0.45 + 0.65 * garter_or_edge), 0.0, 0.85);
			vec3 nylon_tint = mix(base.rgb * (suit_dark_color.rgb * 3.2 + vec3(0.35)), target_suit, 0.55);
			rgb = mix(rgb, clamp(nylon_tint, vec3(0.0), vec3(1.0)), mask.a * nylon_opacity);
		}
	}

	// 5. Laboratorio de Recoloreo y Estilo de Cabello (`is_head_part` + `mask.a`)
	if (is_head_part && mask.a > 0.01 && (enable_shader_recolor || enable_hair_recolor || hair_style_mode > 0)) {
		float t_hair = clamp((orig_luma - 0.48) / 0.36, 0.0, 1.0);
		vec3 base_hair_col = apply_recolor_algorithm(hair_color.rgb, t_hair, orig_luma, 0.74, recolor_method);
		float soft = max(hair_cut_softness, 0.015);

		if (hair_style_mode == 1) {
			// Modo 1: Bicolor Trigger / Edgerunners (Umbral regulable por hair_cut_height y hair_cut_softness)
			float is_lit_strand = smoothstep(hair_cut_height - soft * 0.5, hair_cut_height + soft * 0.5, t_hair);
			vec3 under_dye = mix(hair_secondary_color.rgb * 0.88, base_hair_col, 1.0 - hair_effect_strength);
			base_hair_col = mix(under_dye, base_hair_col, is_lit_strand);
		} else if (hair_style_mode == 2) {
			// Modo 2: Puntas Teñidas / Dip-Dye (Altura y transición regulables)
			float tip_factor = smoothstep(hair_cut_height - soft, hair_cut_height + soft, UV.y);
			vec3 tip_col = apply_recolor_algorithm(hair_secondary_color.rgb, t_hair, orig_luma, 0.74, recolor_method);
			base_hair_col = mix(base_hair_col, tip_col, tip_factor * hair_effect_strength);
		} else if (hair_style_mode == 3) {
			// Modo 3: Halo Especular Anime ("Angel Ring" en la corona superior)
			float arch_y = (hair_cut_height * 0.65) + sin(UV.x * 3.14159) * 0.045;
			float halo_band = 1.0 - smoothstep(soft * 0.14, soft * 0.38, abs(UV.y - arch_y));
			float lit_gate = smoothstep(0.32, 0.58, t_hair);
			vec3 ring_col = mix(hair_secondary_color.rgb, vec3(1.0), 0.55);
			base_hair_col = mix(base_hair_col * 0.90, ring_col, halo_band * lit_gate * hair_effect_strength);
		}

		rgb = mix(rgb, clamp(base_hair_col, vec3(0.0), vec3(1.0)), mask.a * 0.96);
	}

	// 6. Personalidad de Sombreado por Identidad Visual (Regulable por Sliders del Filtro)
	vec3 abyssal_ink = vec3(0.031, 0.031, 0.071);

	float eff_cel_step = cel_step_strength;
	if (eff_cel_step > 0.01) {
		float b1 = smoothstep(0.20, 0.24, orig_luma);
		float b2 = smoothstep(0.37, 0.42, orig_luma);
		float stepped_factor = (0.72 + b1 * 0.22 + b2 * 0.22);
		rgb = mix(rgb, clamp(rgb * stepped_factor, vec3(0.0), vec3(1.0)), armor_suit_weight * eff_cel_step);
	}

	if (noir_shadow_crush > 0.01) {
		float p5_shadow = (1.0 - smoothstep(noir_shadow_threshold - 0.02, noir_shadow_threshold + 0.02, orig_luma)) * clamp(mask.b + mask.g * 0.7, 0.0, 1.0);
		rgb = mix(rgb, abyssal_ink, p5_shadow * noir_shadow_crush);
		rgb = mix(rgb, clamp(rgb * (1.0 + 0.28 * noir_shadow_crush), vec3(0.0), vec3(1.0)), mask.r);
	}

	if (metal_sheen_strength > 0.01) {
		float spec_band = smoothstep(0.36, 0.46, orig_luma) * (1.0 - smoothstep(0.54, 0.66, orig_luma));
		float aniso_wave = 0.5 + 0.5 * sin((UV.x * 6.0 + UV.y * 10.0) + TIME * 1.4);
		vec3 metal_sheen = mix(panel_color.rgb, vec3(1.0), 0.65) * spec_band * (0.55 + 0.45 * aniso_wave);
		rgb = clamp(rgb + metal_sheen * mask.g * metal_sheen_strength * 0.55, vec3(0.0), vec3(1.0));
		float sub_band = smoothstep(0.16, 0.24, orig_luma) * (1.0 - smoothstep(0.26, 0.34, orig_luma));
		rgb = clamp(rgb + accent_color.rgb * sub_band * (mask.b + mask.g) * (metal_sheen_strength * 0.18), vec3(0.0), vec3(1.0));
	}

	// 7. Refuerzo de Tinta Negra (#080812)
	if (ink_boost > 0.01) {
		float ink_zone = (1.0 - smoothstep(0.09, 0.19, orig_luma));
		rgb = mix(rgb, abyssal_ink, clamp(ink_zone * ink_boost, 0.0, 0.94));
	}

	// 8. Sistema de Trama Semitono / Hatching (Control Total de Patrón, Ángulo, Umbral y Zona)
	if (enable_halftone && halftone_strength > 0.01) {
		float pat_shadow = compute_halftone_pattern(FRAGCOORD.xy, halftone_scale, halftone_pattern_type, halftone_angle_deg);
		float zone_mask = 0.0;
		float thr = halftone_threshold;
		if (halftone_zone_mode == 0) {
			float shadow_band = smoothstep(0.12, 0.18, orig_luma) * (1.0 - smoothstep(thr - 0.06, thr + 0.06, orig_luma));
			zone_mask = shadow_band * armor_suit_weight;
		} else if (halftone_zone_mode == 1) {
			float mid_dark = smoothstep(0.12, 0.18, orig_luma) * (1.0 - smoothstep(thr + 0.12, thr + 0.26, orig_luma));
			zone_mask = mid_dark * armor_suit_weight;
		} else if (halftone_zone_mode == 2) {
			zone_mask = smoothstep(0.12, 0.18, orig_luma) * (1.0 - smoothstep(thr + 0.08, thr + 0.24, orig_luma)) * mat_weight;
		} else {
			float shadow_band = smoothstep(0.12, 0.18, orig_luma) * (1.0 - smoothstep(thr - 0.05, thr + 0.06, orig_luma));
			zone_mask = shadow_band * armor_suit_weight;
		}
		rgb = mix(rgb, abyssal_ink, pat_shadow * zone_mask * clamp(halftone_strength, 0.0, 0.92));

		if (halftone_zone_mode == 3 || pipeline_style_mode == 4) {
			float pat_light = compute_halftone_pattern(FRAGCOORD.xy + vec2(3.5, 3.5), halftone_scale * 0.90, 0, halftone_angle_deg + 15.0);
			float hi_band = smoothstep(thr - 0.04, thr + 0.06, orig_luma) * clamp(mask.g + mask.r + (is_head_part ? mask.a * 0.5 : 0.0), 0.0, 1.0);
			vec3 pop_hi = mix(rgb, vec3(1.0), 0.45) + accent_color.rgb * 0.18;
			rgb = mix(rgb, clamp(pop_hi, vec3(0.0), vec3(1.0)), pat_light * hi_band * clamp(halftone_strength * 1.15, 0.0, 0.88));
		}
	}

	// 9. Luz de Reborde (Rim-Light Simple y Dual-Rim con Ancho e Intensidad Regulables)
	if (rim_light_strength > 0.01 || dual_rim_strength > 0.01) {
		vec2 px = TEXTURE_PIXEL_SIZE * rim_width_px;
		if (rim_light_strength > 0.01) {
			float a_left = texture(TEXTURE, clamp(sample_uv + vec2(-px.x, -px.y * 0.6), vec2(0.0), vec2(1.0))).a;
			float rim_left = clamp(base.a - a_left, 0.0, 1.0) * smoothstep(0.14, 0.26, orig_luma);
			vec3 rim_col_a = mix(accent_color.rgb, vec3(1.0), 0.35);
			rgb = clamp(rgb + rim_col_a * rim_left * rim_light_strength * mat_weight, vec3(0.0), vec3(1.0));
		}
		if (dual_rim_strength > 0.01) {
			float a_right = texture(TEXTURE, clamp(sample_uv + vec2(px.x * 1.1, -px.y * 0.4), vec2(0.0), vec2(1.0))).a;
			float rim_right = clamp(base.a - a_right, 0.0, 1.0) * smoothstep(0.14, 0.26, orig_luma);
			vec3 cyan_rim = vec3(0.0, 0.94, 1.0);
			rgb = clamp(rgb + cyan_rim * rim_right * dual_rim_strength * mat_weight, vec3(0.0), vec3(1.0));
		}
	}

	// 10. Sombras dinámicas del rebote elástico + Pulso Holográfico
	rgb = clamp(rgb + vec3(bounce_shade), vec3(0.0), vec3(1.0));

	float pulse = 1.0 + 0.14 * sin(TIME * pulse_speed);
	vec3 emissive_boost = rgb * (glow_intensity * pulse) * mask.r * 0.42;
	rgb = clamp(rgb + emissive_boost, vec3(0.0), vec3(1.0));

	// 11. Inspector de Rayos-X (1-Click Debug)
	if (debug_view_mode == 1) {
		// Clown-Pass ID Visual: Rojo=Acentos, Azul=Paneles, Magenta=Traje, Cian=Pelo, Verde=Medias, Amarillo=Piel
		vec3 dbg = vec3(1.0, 0.92, 0.15); // Piel por defecto
		dbg = mix(dbg, vec3(0.95, 0.15, 0.95), mask.b);
		dbg = mix(dbg, vec3(0.10, 0.40, 1.00), mask.g);
		dbg = mix(dbg, vec3(1.00, 0.12, 0.18), mask.r);
		if (is_head_part) {
			dbg = mix(dbg, vec3(0.0, 0.95, 1.0), mask.a);
		} else if (is_hips_legs_part) {
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
	}

	COLOR = vec4(rgb, base.a);
}
