shader_type canvas_item;
// Shader 2.5D para armamento en Anillo Orbital (Guns Lab — Valentina v2).
// Combina deformación trapezoidal proyectiva, extrusión 3D multi-tap,
// pipeline multi-mapa Rig v2 (ID Mask + ILM + Ink SDF 2x sin mipmaps),
// recoloreo dinámico por Skin, iluminación especular rotacional, rim-light,
// atenuación por profundidad y pulso HDR de disparo.

uniform float barrel_z : hint_range(-1.0, 1.0) = 0.0;
uniform float orbit_depth : hint_range(-1.0, 1.0) = 0.0;
uniform float orbit_angle : hint_range(-6.2832, 6.2832) = 0.0;
uniform float pivot_u : hint_range(0.0, 1.0) = 0.355;
uniform float trapezoid_strength : hint_range(0.0, 1.0) = 0.42;
uniform float extrude_depth_px : hint_range(0.0, 16.0) = 5.5;
uniform vec2 extrude_dir = vec2(-0.35, 0.92);
uniform vec4 extrude_tint : source_color = vec4(0.10, 0.16, 0.28, 0.92);
uniform float depth_back_dim : hint_range(0.0, 0.8) = 0.28;
uniform vec4 depth_back_tint : source_color = vec4(0.32, 0.36, 0.62, 1.0);
uniform float rim_strength : hint_range(0.0, 1.5) = 0.55;
uniform vec4 rim_color : source_color = vec4(0.84, 0.90, 0.98, 1.0);
uniform float specular_sweep_strength : hint_range(0.0, 1.5) = 0.42;
uniform float fire_flash : hint_range(0.0, 2.0) = 0.0;
uniform vec4 fire_glow_color : source_color = vec4(0.95, 0.18, 0.36, 1.0);

// Pipeline Multi-Mapa Rig v2
uniform bool has_multi_maps = false;
uniform sampler2D id_mask_tex : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D ilm_mask_tex : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D ink_sdf_tex : hint_default_white, filter_linear, repeat_disable;

uniform bool skin_recolor_enabled = false;
uniform vec4 skin_accent_color : source_color = vec4(0.95, 0.18, 0.36, 1.0);
uniform vec4 skin_panel_color : source_color = vec4(0.84, 0.90, 0.98, 1.0);
uniform vec4 skin_dark_color : source_color = vec4(0.12, 0.15, 0.24, 1.0);

uniform float ink_sdf_strength : hint_range(0.0, 1.0) = 0.92;
uniform float ink_sdf_width_px : hint_range(0.4, 3.0) = 1.5;
uniform vec4 ink_color : source_color = vec4(0.06, 0.07, 0.12, 1.0);

vec2 warp_trapezoid_uv(vec2 uv) {
	float u_rel = uv.x - pivot_u;
	float v_rel = uv.y - 0.5;
	// w > 1.0 en la boca cuando barrel_z > 0 (boca hacia cámara => se ensancha)
	float w = clamp(1.0 + u_rel * barrel_z * trapezoid_strength * 1.65, 0.35, 2.25);
	float v_mapped = 0.5 + (v_rel / w);
	// Ligero desplazamiento no-lineal en U para reforzar escorzo proyectivo
	float u_mapped = pivot_u + (u_rel / mix(1.0, w, 0.32));
	return vec2(u_mapped, v_mapped);
}

vec4 sample_warped(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, uv);
}

float eval_ink_sdf_mask(vec2 base_uv, vec2 px_size) {
	if (base_uv.x < 0.0 || base_uv.x > 1.0 || base_uv.y < 0.0 || base_uv.y > 1.0) {
		return 0.0;
	}
	vec2 duv_dx = dFdx(base_uv) / max(px_size, vec2(1e-6));
	vec2 duv_dy = dFdy(base_uv) / max(px_size, vec2(1e-6));
	float texels_per_px = max(length(duv_dx), length(duv_dy));
	float eff_tpp = clamp(texels_per_px, 1.0, 1.85);
	float bias_px = clamp((ink_sdf_width_px - 1.5) * 0.45, -0.40, 0.55);
	float aa_px = 0.48;

	if (texels_per_px <= 1.85) {
		float sdf_tex = (textureLod(ink_sdf_tex, base_uv, 0.0).r - 0.5) * 16.0;
		return 1.0 - smoothstep(-aa_px + bias_px, aa_px + bias_px, sdf_tex / eff_tpp);
	}

	float s_foot = clamp(texels_per_px * 0.32, 0.6, 2.0);
	vec2 s_rgss[4] = vec2[4](
		vec2(-0.35, -0.85), vec2(0.85, -0.35),
		vec2(0.35, 0.85), vec2(-0.85, 0.35)
	);
	float cov_sum = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 suv = clamp(base_uv + s_rgss[i] * s_foot * px_size, vec2(0.0), vec2(1.0));
		float stex = (textureLod(ink_sdf_tex, suv, 0.0).r - 0.5) * 16.0;
		cov_sum += 1.0 - smoothstep(-aa_px + bias_px, aa_px + bias_px, stex / eff_tpp);
	}
	return cov_sum * 0.25;
}

vec3 recolor_ramp_3tone(vec3 target_col, float t_norm, vec3 shadow_tint, float hi_boost) {
	vec3 sh_col = target_col * shadow_tint;
	vec3 mid_col = target_col * 1.12;
	vec3 hi_col = mix(target_col * (1.15 + hi_boost), vec3(1.0), 0.36);
	float step_mid = smoothstep(0.28, 0.46, t_norm);
	float step_hi = smoothstep(0.76, 0.90, t_norm);
	vec3 cel = mix(sh_col, mid_col, step_mid);
	return clamp(mix(cel, hi_col, step_hi), vec3(0.0), vec3(1.25));
}

void fragment() {
	vec2 base_uv = warp_trapezoid_uv(UV);
	vec4 front = sample_warped(TEXTURE, base_uv);
	vec2 px_size = TEXTURE_PIXEL_SIZE;

	// Extrusión 3D falsa detrás de la cara frontal (se acentúa cuando el arma gira en perspectiva)
	float extrude_factor = mix(0.35, 1.0, abs(barrel_z));
	vec2 step_uv = extrude_dir * (extrude_depth_px * extrude_factor / 6.0) * px_size;

	vec4 body_col = front;
	bool is_extrude_only = false;
	if (front.a < 0.92 && extrude_depth_px > 0.05) {
		vec4 ext_acc = vec4(0.0);
		for (int i = 1; i <= 6; i++) {
			vec2 s_uv = warp_trapezoid_uv(UV + step_uv * float(i));
			vec4 s_col = sample_warped(TEXTURE, s_uv);
			if (s_col.a > 0.25) {
				float shade = mix(0.95, 0.42, float(i) / 6.0);
				vec3 ext_rgb = mix(s_col.rgb * 0.48, extrude_tint.rgb, 0.55) * shade;
				float ext_a = s_col.a * extrude_tint.a;
				// Mezcla front-to-back detrás de la cara frontal
				ext_acc.rgb = mix(ext_rgb, ext_acc.rgb, ext_acc.a);
				ext_acc.a = max(ext_acc.a, ext_a);
				break;
			}
		}
		if (ext_acc.a > 0.01) {
			vec3 comp_rgb = mix(ext_acc.rgb, front.rgb, front.a);
			float comp_a = max(front.a, ext_acc.a);
			body_col = vec4(comp_rgb, comp_a);
			is_extrude_only = (front.a < 0.20);
		}
	}

	if (body_col.a < 0.01) {
		discard;
	}

	vec3 rgb = body_col.rgb;
	float energy_mask = 0.0;
	float spec_weight = 1.0;
	float rim_weight = 1.0;

	if (has_multi_maps && !is_extrude_only && base_uv.x >= 0.0 && base_uv.x <= 1.0 && base_uv.y >= 0.0 && base_uv.y <= 1.0) {
		vec4 id_m = textureLod(id_mask_tex, base_uv, 0.0);
		vec4 ilm_m = textureLod(ilm_mask_tex, base_uv, 0.0);
		float sdf_ink = eval_ink_sdf_mask(base_uv, px_size);

		float id_sum = max(id_m.r + id_m.g + id_m.b, 0.001);
		vec3 w_id = id_m.rgb / id_sum;

		float front_luma = dot(front.rgb, vec3(0.299, 0.587, 0.114));
		if (skin_recolor_enabled) {
			float t_panel = clamp((front_luma - 0.30) / 0.60, 0.0, 1.0);
			float t_dark = clamp((front_luma - 0.02) / 0.14, 0.0, 1.0);
			float t_acc = clamp((front_luma - 0.04) / 0.38, 0.0, 1.0);

			vec3 col_panel = recolor_ramp_3tone(skin_panel_color.rgb, t_panel, vec3(0.56, 0.56, 0.68), 0.25);
			vec3 col_dark = recolor_ramp_3tone(skin_dark_color.rgb, t_dark, vec3(0.55, 0.55, 0.66), 0.10);
			vec3 col_acc = recolor_ramp_3tone(skin_accent_color.rgb, t_acc, vec3(0.45, 0.38, 0.52), 0.45);

			vec3 recolored = col_acc * w_id.r + col_panel * w_id.g + col_dark * w_id.b;
			// Preservar contorno de tinta frente al recoloreo
			float ink_guard = 1.0 - sdf_ink * 0.72;
			vec3 front_recol = mix(front.rgb, recolored, clamp(id_m.a * ink_guard, 0.0, 1.0));
			rgb = mix(body_col.rgb, front_recol, front.a);
		}

		energy_mask = smoothstep(0.18, 0.85, ilm_m.a);
		spec_weight = mix(0.25, 1.25, ilm_m.r);
		rim_weight = mix(0.35, 1.20, ilm_m.b);

		// Tinta vectorial SDF 2x (nítida en bordes y costuras de paneles)
		float ink_apply = sdf_ink * ink_sdf_strength * front.a * (1.0 - energy_mask * 0.55);
		rgb = mix(rgb, ink_color.rgb, clamp(ink_apply, 0.0, 1.0));
	} else {
		// Fallback legacy para sprites sin multi-mapa (detecta emisivos cian/azul)
		float cyan_energy = clamp((rgb.b + rgb.g * 0.85) - rgb.r * 1.45, 0.0, 1.0);
		energy_mask = smoothstep(0.18, 0.62, cyan_energy);
	}

	// Barrido especular metálico dependiente del ángulo orbital 3D
	float sweep_center = 0.5 + 0.36 * cos(orbit_angle * 1.5);
	float sweep_band = exp(-pow((base_uv.x - sweep_center) * 5.2, 2.0));
	float metallic_mask = (1.0 - energy_mask) * smoothstep(0.08, 0.45, max(rgb.r, max(rgb.g, rgb.b))) * spec_weight;
	rgb += vec3(0.78, 0.90, 1.0) * sweep_band * metallic_mask * specular_sweep_strength * (0.65 + 0.35 * orbit_depth);

	// Rim-light en borde superior/frontal (estima gradiente alfa local)
	if (rim_strength > 0.01 && front.a > 0.25) {
		vec2 rim_off = vec2(0.0, -2.0) * px_size;
		float a_up = sample_warped(TEXTURE, warp_trapezoid_uv(UV + rim_off)).a;
		float edge_rim = clamp(front.a - a_up, 0.0, 1.0);
		float front_boost = mix(0.45, 1.15, orbit_depth * 0.5 + 0.5);
		rgb += rim_color.rgb * edge_rim * rim_strength * rim_weight * front_boost;
	}

	// Pulso HDR en canales de energía y cañón al disparar
	if (fire_flash > 0.001) {
		float muzzle_grad = smoothstep(pivot_u, 0.98, base_uv.x);
		rgb += fire_glow_color.rgb * (energy_mask * 1.15 + muzzle_grad * 0.45) * fire_flash;
	} else {
		// Brillo sutil permanente en los núcleos de energía del arma
		rgb += fire_glow_color.rgb * energy_mask * 0.34;
	}

	// Atenuación atmosférica cuando pasa detrás del piloto (orbit_depth < 0)
	float back_factor = clamp(-orbit_depth, 0.0, 1.0);
	if (back_factor > 0.001 && depth_back_dim > 0.001) {
		float dim_amt = back_factor * depth_back_dim;
		rgb = mix(rgb, rgb * depth_back_tint.rgb, dim_amt * 0.85);
		rgb *= (1.0 - dim_amt * 0.35);
	}

	COLOR = vec4(rgb, body_col.a);
}
