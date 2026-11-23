// Módulo de vida facial, soldadura cervical, monóculo táctico y rayos-X faciales (Valentina v2).
// Incluido desde pilot_rig_stylizer.gdshader después de rig_color_recolor.gdshaderinc.

vec2 apply_neck_weld_uv(
	vec2 uv,
	vec2 texel_size,
	vec2 neck_pivot_uv,
	float weld_w,
	float rot_rad,
	vec2 shift_px
) {
	if (weld_w <= 0.001) {
		return uv;
	}
	float eff_rot = rot_rad * weld_w;
	vec2 eff_shift = shift_px * weld_w;
	vec2 inv_px = 1.0 / max(texel_size, vec2(0.00001));
	vec2 local_px = (uv - neck_pivot_uv) * inv_px;
	float c = cos(eff_rot);
	float s = sin(eff_rot);
	// Forward transform (p_world = R(+rot) * p_local + shift) mantiene la base del cuello fija sobre el torso.
	vec2 rot_px = vec2(local_px.x * c - local_px.y * s, local_px.x * s + local_px.y * c) + eff_shift;
	return clamp(neck_pivot_uv + rot_px * texel_size, vec2(0.001), vec2(0.999));
}

vec2 apply_face_feature_warp_uv(
	vec2 uv,
	vec2 texel_size,
	vec4 flm,
	float is_collar_blue,
	float brow_y_px,
	float brow_tilt,
	float mouth_smile,
	float mouth_open,
	out float out_mouth_core
) {
	out_mouth_core = 0.0;
	vec2 warped = uv;

	// Cejas (flm.b): elevación/fruncido e inclinación angular acotada
	float w_brow = smoothstep(0.12, 0.65, flm.b) * (1.0 - is_collar_blue);
	if (w_brow > 0.005) {
		float tilt_dx = (uv.x - 0.5) * 90.0 * brow_tilt;
		float dy = clamp(brow_y_px + tilt_dx, -3.8, 3.8);
		warped.y = clamp(warped.y - dy * texel_size.y * w_brow, 0.001, 0.999);
	}

	// Boca / Labios (flm.a fuera del cuello): sonrisa en comisuras + apertura vertical para lip-sync
	float w_mouth = smoothstep(0.14, 0.72, flm.a) * (1.0 - is_collar_blue);
	if (w_mouth > 0.005) {
		float corner_dist = clamp(abs(uv.x - 0.5) * 14.0, 0.0, 1.0);
		float smile_dy = mouth_smile * corner_dist * 2.2;
		float open_stretch = 1.0 / (1.0 + clamp(mouth_open, 0.0, 1.0) * 0.55);
		// Detectar banda central de labios para cavidad bucal cuando mouth_open > 0
		float center_env = smoothstep(0.45, 0.92, flm.a) * (1.0 - corner_dist * 0.65);
		out_mouth_core = center_env * clamp(mouth_open, 0.0, 1.0);
		float local_dy = smile_dy + (uv.y - 0.66) * (open_stretch - 1.0) * 12.0;
		warped.y = clamp(warped.y + clamp(local_dy, -2.8, 2.8) * texel_size.y * w_mouth, 0.001, 0.999);
	}

	return warped;
}

vec3 apply_live_eyes_and_mouth_color(
	vec3 base_rgb_lin,
	vec4 flm,
	float is_collar_blue,
	vec2 eye_look_px,
	vec3 iris_src_rgb,
	vec4 iris_src_flm,
	float iris_src_sdf,
	bool has_ink_sdf_ref,
	float blink_amt,
	float squint_amt,
	vec4 above_flm,
	vec3 lid_skin_raw_rgb,
	vec4 skin_src_flm,
	float mouth_open,
	float mouth_core,
	inout float io_sdf_ink,
	inout float io_dark_luma,
	out float out_lid_ink
) {
	vec3 col = base_rgb_lin;
	out_lid_ink = 0.0;
	if (is_collar_blue > 0.45) {
		return col;
	}

	float eye_open_w = smoothstep(0.22, 0.62, flm.g);
	float lid_zone_w = smoothstep(0.12, 0.48, max(flm.g, flm.r));

	// 1. Eye-tracking / micro-sacadas dentro de toda la almendra ocular (sin arrastrar pestañas externas)
	if (eye_open_w > 0.01 && dot(eye_look_px, eye_look_px) > 0.0004) {
		float src_iris_w = smoothstep(0.56, 0.88, iris_src_flm.g);
		vec3 sclera_lin = srgb_to_linear(vec3(0.95, 0.95, 0.97));
		vec3 eye_col = mix(sclera_lin, iris_src_rgb, src_iris_w);
		col = mix(col, eye_col, eye_open_w);

		// Sincronizar luma y SDF de tinta dentro del ojo con el iris desplazado
		vec3 src_srgb = linear_to_srgb(max(eye_col, vec3(0.0)));
		float src_luma = dot(src_srgb, vec3(0.299, 0.587, 0.114));
		io_dark_luma = mix(io_dark_luma, mix(0.94, src_luma, src_iris_w), eye_open_w);
		if (has_ink_sdf_ref) {
			float src_sdf = (iris_src_sdf - 0.5) * 16.0;
			float shifted_ink = 1.0 - smoothstep(-0.35, 0.35, src_sdf);
			io_sdf_ink = mix(io_sdf_ink, shifted_ink * src_iris_w, eye_open_w);
		}
	}

	// 2. Parpadeo y Squint: barrido descendente del párpado superior sobre toda la almendra
	float close_amt = clamp(max(blink_amt, squint_amt * 0.62), 0.0, 1.0);
	if (lid_zone_w > 0.01 && close_amt > 0.01) {
		float lid_cover = (1.0 - smoothstep(0.10, 0.50, above_flm.g)) * lid_zone_w;
		if (close_amt > 0.88) {
			lid_cover = max(lid_cover, smoothstep(0.88, 0.99, close_amt) * eye_open_w);
		}

		// Color limpio del párpado superior (muestreado de piel limpia sin cejas/ojos)
		vec3 fallback_skin_lin = srgb_to_linear(vec3(0.91, 0.71, 0.66));
		float raw_skin_luma = dot(linear_to_srgb(max(lid_skin_raw_rgb, vec3(0.0))), vec3(0.299, 0.587, 0.114));
		float valid_skin_sample = (1.0 - smoothstep(0.12, 0.35, max(skin_src_flm.b, skin_src_flm.r))) * smoothstep(0.32, 0.50, raw_skin_luma);
		vec3 lid_skin_lin = mix(fallback_skin_lin, lid_skin_raw_rgb, valid_skin_sample);

		col = mix(col, lid_skin_lin, lid_cover);

		// Pestaña descendente nítida en la frontera del párpado
		float lash_band = smoothstep(0.08, 0.30, above_flm.g) * (1.0 - smoothstep(0.30, 0.62, above_flm.g)) * lid_zone_w;
		float closed_lash = (close_amt > 0.84)
			? smoothstep(0.84, 0.98, close_amt) * smoothstep(0.14, 0.38, flm.g) * (1.0 - smoothstep(0.45, 0.85, flm.g))
			: 0.0;
		out_lid_ink = clamp(max(lash_band, closed_lash) * smoothstep(0.04, 0.18, close_amt), 0.0, 1.0);

		// Suprimir tinta estática del iris abierto debajo del párpado cerrado
		io_sdf_ink = mix(io_sdf_ink, 0.0, lid_cover);
		io_dark_luma = mix(io_dark_luma, 0.68, lid_cover);
		io_sdf_ink = max(io_sdf_ink, out_lid_ink);
	}

	// 3. Apertura de boca para diálogo / comms
	if (mouth_open > 0.04 && mouth_core > 0.02) {
		vec3 cavity_lin = srgb_to_linear(vec3(0.28, 0.09, 0.13));
		float cavity_w = smoothstep(0.04, 0.35, mouth_open) * smoothstep(0.10, 0.55, mouth_core);
		col = mix(col, cavity_lin, cavity_w * 0.86);
		io_dark_luma = mix(io_dark_luma, 0.24, cavity_w * 0.65);
	}

	return col;
}

vec3 apply_live_eyes_v2_and_mouth_color(
	vec3 base_rgb_lin,
	vec4 flm,
	float is_collar_blue,
	vec2 eye_look_px,
	vec2 light_dir_2d_n,
	vec2 iris_local_uv,
	vec4 eye_iris_s,
	vec4 eye_closed_s,
	vec4 lid_skin_patch_s,
	float lid_sh_far_g,
	float lid_sh_near_g,
	float lid_shadow_strength,
	float far_eye_clarity,
	float blink_amt,
	float squint_amt,
	vec4 above_flm,
	vec3 above_lid_rgb,
	float above_lid_sdf,
	float mouth_open,
	float mouth_core,
	inout float io_sdf_ink,
	inout float io_dark_luma,
	out float out_lid_ink,
	out float out_eye_spec,
	out float out_eye_emit
) {
	vec3 col = base_rgb_lin;
	out_lid_ink = 0.0;
	out_eye_spec = 0.0;
	out_eye_emit = 0.0;
	if (is_collar_blue > 0.45) {
		return col;
	}

	// Capa 1 + 2: Esclerótica limpia + Iris Completo 360° recortado por la almendra (flm.g) + Sombra fija de párpado superior
	float eye_open_w = smoothstep(0.14, 0.56, flm.g);
	float lid_zone_w = smoothstep(0.10, 0.46, max(flm.g, flm.r));
	float raw_spec = 0.0;
	float raw_emit = 0.0;

	if (eye_open_w > 0.005) {
		vec3 sclera_lin = mix(
			srgb_to_linear(vec3(0.96, 0.96, 0.98)),
			srgb_to_linear(vec3(0.985, 0.988, 1.0)),
			far_eye_clarity
		);
		vec3 iris_rgb = eye_iris_s.rgb;
		if (far_eye_clarity > 0.01) {
			float iris_val_lin = max(iris_rgb.r, max(iris_rgb.g, iris_rgb.b));
			float dark_ink_w = 1.0 - smoothstep(0.012, 0.048, iris_val_lin);
			float iris_luma_lin = dot(iris_rgb, vec3(0.299, 0.587, 0.114));
			vec3 sat_iris = max(mix(vec3(iris_luma_lin), iris_rgb, 1.12), vec3(0.0));
			vec3 iris_far_rich = mix(sat_iris, iris_rgb * 0.65, dark_ink_w * 0.45);
			iris_rgb = mix(iris_rgb, iris_far_rich, far_eye_clarity);
		}
		vec3 eye_col = mix(sclera_lin, iris_rgb, eye_iris_s.a);

		// Sombra proyectada fija del párpado superior (no sigue la mirada del iris -> efecto real de profundidad detrás del párpado)
		float upper_sh_band = 1.0 - smoothstep(0.12, 0.72, lid_sh_far_g);
		float upper_sh_core = 1.0 - smoothstep(0.12, 0.65, lid_sh_near_g);
		float sh_w = clamp((upper_sh_band * 0.55 + upper_sh_core * 0.45) * lid_shadow_strength, 0.0, 0.88);
		eye_col *= mix(vec3(1.0), srgb_to_linear(vec3(0.68, 0.64, 0.78)), sh_w);

		col = mix(col, eye_col, eye_open_w);

		// Sincronizar valor HSV y SDF de tinta con el ojo compuesto para proteger tonos violeta profundos sin pintar negro falso
		vec3 eye_srgb = linear_to_srgb(max(eye_col, vec3(0.0)));
		float eye_val_srgb = max(eye_srgb.r, max(eye_srgb.g, eye_srgb.b));
		io_dark_luma = mix(io_dark_luma, eye_val_srgb, eye_open_w);
		float new_iris_ink = (1.0 - smoothstep(0.08, 0.22, eye_val_srgb)) * smoothstep(0.35, 0.75, eye_iris_s.a);
		io_sdf_ink = mix(io_sdf_ink, new_iris_ink, eye_open_w);

		// Brillo especular (catchlight) estabilizado frente a luz rotatoria y con presencia limpia a distancia
		vec2 look_n = clamp(eye_look_px / 3.5, vec2(-1.0), vec2(1.0));
		vec2 spec1_c = vec2(0.30, 0.34) + light_dir_2d_n * vec2(0.035, 0.025) + look_n * 0.032;
		float d1 = length((iris_local_uv - spec1_c) * vec2(1.0, 1.15));
		float r1_in = mix(0.054, 0.072, far_eye_clarity);
		float r1_out = mix(0.092, 0.118, far_eye_clarity);
		float s1 = 1.0 - smoothstep(r1_in, r1_out, d1);

		vec2 spec2_c = vec2(0.68, 0.66) - light_dir_2d_n * vec2(0.030, 0.025) + look_n * 0.022;
		float d2 = length(iris_local_uv - spec2_c);
		float s2 = (1.0 - smoothstep(0.032, 0.062, d2)) * 0.45;

		vec3 iris_srgb = linear_to_srgb(max(iris_rgb, vec3(0.0)));
		float iris_val_srgb = max(iris_srgb.r, max(iris_srgb.g, iris_srgb.b));
		float iris_interior = smoothstep(0.50, 0.86, eye_iris_s.a) * smoothstep(0.18, 0.40, iris_val_srgb);
		float eye_lit_mask = eye_open_w * iris_interior * (1.0 - upper_sh_core * 0.35);
		raw_spec = clamp(max(s1, s2), 0.0, 1.0) * eye_lit_mask * mix(1.0, 1.08, far_eye_clarity);

		// Micro-luminiscencia táctica solo en la media luna inferior del iris (excluye pupila, anillo y párpados)
		float dist_iris_c = length((iris_local_uv - vec2(0.50, 0.54)) * vec2(1.0, 1.06));
		float lower_crescent = smoothstep(0.46, 0.64, iris_local_uv.y) * (1.0 - smoothstep(0.33, 0.41, dist_iris_c));
		float fill_only = smoothstep(0.50, 0.86, eye_iris_s.a) * smoothstep(0.36, 0.62, iris_val_srgb);
		raw_emit = clamp(lower_crescent * fill_only * eye_open_w * (1.0 - upper_sh_core * 0.55) * mix(0.45, 0.85, far_eye_clarity), 0.0, 1.0);
	}

	// Capa 3: Deslizamiento real del delineado/pestaña superior dibujada (above_uv) + transición al parche de ojo cerrado
	float close_amt = clamp(max(blink_amt, squint_amt * 0.70), 0.0, 1.0);
	float closed_pose_mix = smoothstep(0.62, 0.94, close_amt);
	if (close_amt > 0.005 || (far_eye_clarity > 0.01 && lid_zone_w > 0.01)) {
		float lid_cover = (1.0 - smoothstep(0.10, 0.50, above_flm.g)) * lid_zone_w;
		if (lid_zone_w > 0.01 && lid_cover > 0.005) {
			vec3 fallback_skin_lin = srgb_to_linear(vec3(0.91, 0.71, 0.66));
			vec3 patch_skin_lin = mix(fallback_skin_lin, lid_skin_patch_s.rgb, smoothstep(0.4, 0.9, lid_skin_patch_s.a));
			float above_lash_w = smoothstep(0.08, 0.45, above_flm.r);
			vec3 above_srgb = linear_to_srgb(max(above_lid_rgb, vec3(0.0)));
			float above_luma = dot(above_srgb, vec3(0.299, 0.587, 0.114));
			float above_ink = max(above_lid_sdf, 1.0 - smoothstep(0.08, 0.28, above_luma));

			vec3 lid_rgb = mix(patch_skin_lin, above_lid_rgb, above_lash_w);
			float lid_sdf = mix(0.0, above_ink, above_lash_w);
			float lid_luma = mix(0.68, above_luma, above_lash_w);

			float sweep_w = lid_cover * (1.0 - closed_pose_mix);
			col = mix(col, lid_rgb, sweep_w);
			io_sdf_ink = mix(io_sdf_ink, lid_sdf, sweep_w);
			io_dark_luma = mix(io_dark_luma, lid_luma, sweep_w);
			out_lid_ink = clamp(above_ink * above_lash_w * sweep_w, 0.0, 1.0);
		}

		if (closed_pose_mix > 0.005 && eye_closed_s.a > 0.01) {
			float closed_w = eye_closed_s.a * closed_pose_mix;
			col = mix(col, eye_closed_s.rgb, closed_w);
			vec3 c_srgb = linear_to_srgb(max(eye_closed_s.rgb, vec3(0.0)));
			float c_luma = dot(c_srgb, vec3(0.299, 0.587, 0.114));
			io_dark_luma = mix(io_dark_luma, c_luma, closed_w);
			float closed_lash_ink = 1.0 - smoothstep(0.08, 0.28, c_luma);
			io_sdf_ink = mix(io_sdf_ink, closed_lash_ink, closed_w);
			out_lid_ink = mix(out_lid_ink, closed_lash_ink, closed_w);
		}

		float lid_occlude = 1.0 - clamp(max(lid_cover, closed_pose_mix), 0.0, 1.0);
		raw_spec *= lid_occlude;
		raw_emit *= lid_occlude;
	}
	out_eye_spec = raw_spec;
	out_eye_emit = raw_emit;

	// Boca abierta para diálogo / comms
	if (mouth_open > 0.04 && mouth_core > 0.02) {
		vec3 cavity_lin = srgb_to_linear(vec3(0.28, 0.09, 0.13));
		float cavity_w = smoothstep(0.04, 0.35, mouth_open) * smoothstep(0.10, 0.55, mouth_core);
		col = mix(col, cavity_lin, cavity_w * 0.86);
		io_dark_luma = mix(io_dark_luma, 0.24, cavity_w * 0.65);
	}

	return col;
}

vec3 apply_live_monocle_hud(
	vec3 rgb_lin,
	vec2 uv,
	float w_monocle,
	vec3 accent_lin,
	float q_time,
	vec2 eye_look_px,
	float hud_strength,
	float activity,
	float ink_protect
) {
	if (w_monocle <= 0.05 || hud_strength <= 0.005) {
		return rgb_lin;
	}
	float scan = 0.5 + 0.5 * sin(uv.y * 240.0 - q_time * 9.0);
	float sweep_pos = fract(q_time * 0.38);
	float sweep_band = exp(-pow((uv.y - sweep_pos) / 0.045, 2.0));
	float reticle_x = abs((uv.x - 0.58) * 14.0 - eye_look_px.x * 0.18);
	float reticle_y = abs((uv.y - 0.43) * 14.0 - eye_look_px.y * 0.18);
	float reticle_ring = exp(-pow((length(vec2(reticle_x, reticle_y)) - 0.55) / 0.14, 2.0));

	vec3 hud_col = mix(accent_lin * 1.45 + vec3(0.22, 0.05, 0.08), vec3(1.0, 0.52, 0.64), 0.35);
	float sig = (scan * 0.18 + sweep_band * (0.45 + activity * 0.65) + reticle_ring * (0.35 + activity * 0.55)) * hud_strength;
	return rgb_lin + hud_col * sig * w_monocle * ink_protect * 0.52;
}

vec3 compute_face_live_debug_rgb(
	int debug_mode,
	vec4 flm,
	vec3 hair_m,
	float is_collar_blue,
	vec3 fallback_rgb
) {
	if (debug_mode == 7) {
		// Face Live Mask: Amarillo=Párpado(R), Cian=Iris(G), Naranja=Cejas(B), Magenta=Boca(A), Azul=Soldadura Cuello
		vec3 dbg = vec3(0.14, 0.14, 0.18);
		dbg += vec3(0.95, 0.85, 0.12) * flm.r;
		dbg += vec3(0.05, 0.95, 0.95) * flm.g;
		dbg += vec3(1.00, 0.42, 0.04) * flm.b;
		vec3 a_col = mix(vec3(1.00, 0.08, 0.52), vec3(0.10, 0.48, 1.00), is_collar_blue);
		dbg += a_col * flm.a;
		return clamp(dbg, vec3(0.0), vec3(1.0));
	}
	if (debug_mode == 8) {
		// Cabello 3 Zonas: R=Flequillo, G=Mechones Laterales, B=Puntas Traseras/Nuca
		return clamp(vec3(0.08, 0.08, 0.10) + hair_m * 0.92, vec3(0.0), vec3(1.0));
	}
	return fallback_rgb;
}
