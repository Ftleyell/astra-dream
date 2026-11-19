// Módulo de conversión de espacio de color, recoloreo y estabilización de luminancia.
// Incluido desde pilot_rig_stylizer.gdshader.

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

// Evalúa el color recoloreado de un material según el Algoritmo Matemático (recolor_method = 0..4)
vec3 apply_recolor_algorithm(
	vec3 target_col_in,
	float t_norm_in,
	float raw_luma,
	float ref_mid_luma,
	int method,
	float contrast,
	float hi_gain,
	float sat
) {
	vec3 target_col = adjust_saturation(target_col_in, sat);
	float t_norm = clamp((t_norm_in - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec3 warm_white = srgb_to_linear(vec3(1.0, 0.98, 0.92));
	vec3 cool_white = srgb_to_linear(vec3(0.96, 0.97, 1.0));
	vec3 shadow_tint_1 = srgb_to_linear(vec3(0.42, 0.36, 0.58));
	vec3 shadow_tint_2 = srgb_to_linear(vec3(0.32, 0.28, 0.44));
	vec3 shadow_tint_4 = srgb_to_linear(vec3(0.44, 0.38, 0.56));

	if (method == 0) {
		float ratio = (raw_luma / max(ref_mid_luma, 0.08) - 1.0) * contrast + 1.0;
		float mult = clamp(ratio, 0.32, 1.15 + 0.35 * hi_gain);
		return clamp(target_col * mult, vec3(0.0), vec3(1.0));
	} else if (method == 1) {
		vec3 shadow_col = target_col * shadow_tint_1;
		vec3 hi_col = mix(target_col * (1.0 + 0.35 * hi_gain), warm_white, 0.28 * hi_gain);
		vec3 low_to_mid = mix(shadow_col, target_col, smoothstep(0.0, 0.55, t_norm));
		return clamp(mix(low_to_mid, hi_col, smoothstep(0.55, 1.0, t_norm)), vec3(0.0), vec3(1.0));
	} else if (method == 2) {
		float delta = (t_norm - 0.52) * 0.78;
		vec3 dark_pole = target_col * shadow_tint_2;
		vec3 light_pole = mix(target_col * (1.0 + 0.38 * hi_gain), cool_white, 0.32 * hi_gain);
		if (delta < 0.0) {
			return clamp(mix(target_col, dark_pole, clamp(-delta * 1.8, 0.0, 1.0)), vec3(0.0), vec3(1.0));
		} else {
			return clamp(mix(target_col, light_pole, clamp(delta * 1.8, 0.0, 1.0)), vec3(0.0), vec3(1.0));
		}
	} else if (method == 3) {
		vec3 t_vec = vec3(clamp(t_norm, 0.0, 1.0));
		vec3 dark_branch = 2.0 * t_vec * target_col;
		vec3 light_branch = vec3(1.0) - 2.0 * (vec3(1.0) - t_vec) * (vec3(1.0) - target_col);
		vec3 ov = mix(dark_branch, light_branch, smoothstep(0.32, 0.68, t_norm));
		vec3 res = mix(ov, target_col, 0.22);
		return clamp(res * (0.85 + 0.18 * hi_gain), vec3(0.0), vec3(1.0));
	} else {
		vec3 shadow_cel = target_col * shadow_tint_4;
		vec3 hi_cel = mix(target_col * (1.0 + 0.35 * hi_gain), vec3(1.0), 0.34 * hi_gain);
		float step_mid = smoothstep(0.34, 0.40, t_norm);
		float step_hi = smoothstep(0.76, 0.82, t_norm);
		vec3 cel = mix(shadow_cel, target_col, step_mid);
		return clamp(mix(cel, hi_cel, step_hi), vec3(0.0), vec3(1.0));
	}
}
