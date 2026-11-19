// Módulo de proyección espacial canónica (v_rig_pos) y Falsa Perspectiva 2.5D Post-Skinning.
// Presupuesto Forward Mobile: sin varyings propios; empaqueta resultados en los 3 vec4 de pilot_rig_stylizer.gdshader.

float safe_cos_jacobian(float phi, float j_floor) {
	float c = cos(phi);
	float jf2 = j_floor * j_floor;
	return sqrt((1.0 - jf2) * (c * c) + jf2);
}

vec2 compute_rig_space_pos(vec2 vertex_pos, mat4 model_mat, mat4 inv_pivot_mat) {
	vec4 canvas_pos = model_mat * vec4(vertex_pos, 0.0, 1.0);
	return (inv_pivot_mat * canvas_pos).xy;
}

vec2 apply_limb_perspective_25d(
	vec2 pos,
	vec2 uv01,
	vec2 p_root,
	vec2 p_mid,
	vec2 p_tip,
	float v_knee_pivot,
	float phi_seg1,
	float phi_seg2,
	float cam_tan_alpha,
	float jacobian_floor,
	float k_conicity,
	float k_volume,
	float distal_amp,
	float distal_toe_heel_bias,
	bool has_zone_mask,
	vec4 zone_mask,
	out float out_z_local,
	out float out_kappa_tuck,
	out float out_comp_ratio,
	out float out_uv_relief_shift
) {
	float u_hat = clamp(uv01.x * 2.0 - 1.0, -1.0, 1.0);
	float v_hat = clamp(uv01.y, 0.0, 1.0);

	vec2 d_seg1 = p_mid - p_root;
	vec2 d_seg2 = p_tip - p_mid;
	float L1 = max(length(d_seg1), 1.0);
	float L2 = max(length(d_seg2), 1.0);
	vec2 t1 = d_seg1 / L1;
	vec2 n1 = vec2(-t1.y, t1.x);
	vec2 t2 = d_seg2 / L2;
	vec2 n2 = vec2(-t2.y, t2.x);

	float dir_y1 = (abs(t1.y) > 0.001) ? sign(t1.y) : 1.0;
	float dir_y2 = (abs(t2.y) > 0.001) ? sign(t2.y) : 1.0;

	float c1 = safe_cos_jacobian(phi_seg1, jacobian_floor);
	float s1 = sin(phi_seg1);
	float c2 = safe_cos_jacobian(phi_seg2, jacobian_floor);
	float s2 = sin(phi_seg2);

	float distal_mask = has_zone_mask
		? smoothstep(0.82, 0.94, zone_mask.r)
		: smoothstep(0.72, 0.90, v_hat) * (1.0 + distal_toe_heel_bias * u_hat);
	float c2_effective = c2;

	vec2 p_mid_proj = p_root + (L1 * c1) * t1 + vec2(0.0, L1 * cam_tan_alpha * s1 * dir_y1);
	vec2 p_tip_proj = p_mid_proj + (L2 * c2) * t2 + vec2(0.0, L2 * cam_tan_alpha * s2 * dir_y2);

	vec2 v_rel1 = pos - p_root;
	float axial_1 = dot(v_rel1, t1);
	float trans_1 = dot(v_rel1, n1);

	vec2 v_rel2 = pos - p_mid;
	float axial_2 = dot(v_rel2, t2);
	float trans_2 = dot(v_rel2, n2);

	float v_seg1_01 = clamp(v_hat / max(v_knee_pivot, 0.05), 0.0, 1.0);
	float v_seg2_01 = clamp((v_hat - v_knee_pivot) / max(1.0 - v_knee_pivot, 0.05), 0.0, 1.0);
	float w_seg2 = has_zone_mask
		? smoothstep(0.46, 0.56, zone_mask.r)
		: smoothstep(v_knee_pivot - 0.055, v_knee_pivot + 0.055, v_hat);

	float z1 = v_seg1_01 * s1;
	float z2 = s1 + v_seg2_01 * (L2 / L1) * s2;
	float z_depth_offset = has_zone_mask ? (zone_mask.b - 0.5) * 0.70 : 0.0;
	float z_foot_recede = distal_amp * 0.75 * clamp(distal_mask, 0.0, 1.0);
	float z_local = clamp(mix(z1, z2, w_seg2) + z_depth_offset + z_foot_recede, -1.0, 1.0);

	float rigidity = has_zone_mask ? zone_mask.g : 0.0;
	float soft_w = 1.0 - rigidity;

	float conicity_scale = 1.0 / clamp(1.0 - k_conicity * z_local, 0.65, 1.45);
	float belly_1 = sin(v_seg1_01 * 3.14159265);
	float belly_2 = sin(v_seg2_01 * 3.14159265);
	float vol_scale1 = 1.0 + k_volume * soft_w * (s1 * s1) * (belly_1 * belly_1);
	float vol_scale2 = 1.0 + k_volume * soft_w * (s2 * s2) * (belly_2 * belly_2);
	float distal_scale = 1.0 + distal_amp * clamp(distal_mask, 0.0, 1.5);

	float kappa_tuck = clamp((s1 - s2) / 1.2, -1.0, 1.0);
	float tuck_sign = (abs(kappa_tuck) > 0.001) ? sign(kappa_tuck) : 0.0;
	float v_fold_center = v_knee_pivot + 0.035 * tuck_sign;
	float dv_fold = (v_hat - v_fold_center) / 0.075;
	float fold_bell = exp(-0.5 * dv_fold * dv_fold);
	float tuck_axial_shift = kappa_tuck * L1 * 0.14 * fold_bell * (1.0 - 0.5 * u_hat * u_hat) * soft_w;
	float patella_bulge = 1.0 + 0.16 * abs(kappa_tuck) * exp(-0.5 * pow((v_hat - v_knee_pivot) / 0.06, 2.0)) * soft_w;

	float scale_perp1 = conicity_scale * vol_scale1 * patella_bulge;
	float scale_perp2 = conicity_scale * vol_scale2 * patella_bulge;

	float seam_env = smoothstep(0.04, 0.22, v_hat);
	float axial_1_pos = max(axial_1, 0.0);
	float axial_1_neg = min(axial_1, 0.0);
	float eff_scale_perp1 = 1.0 + (scale_perp1 - 1.0) * seam_env;

	vec2 pos_1 = p_root
		+ (axial_1_neg + axial_1_pos * mix(1.0, c1, seam_env) + tuck_axial_shift * seam_env) * t1
		+ vec2(0.0, axial_1_pos * cam_tan_alpha * s1 * dir_y1 * seam_env)
		+ (trans_1 * eff_scale_perp1) * n1;

	vec2 pos_2 = p_mid_proj
		+ (axial_2 * c2_effective + tuck_axial_shift) * t2
		+ vec2(0.0, axial_2 * cam_tan_alpha * s2 * dir_y2)
		+ (trans_2 * scale_perp2) * n2;

	// Pivote distal en el tobillo (p_tip_proj) para no arrastrar el pie hacia la rodilla
	vec2 v_foot = pos_2 - p_tip_proj;
	vec2 foot_scaled = vec2(
		v_foot.x * clamp(1.0 + distal_amp * 0.42, 0.72, 1.25),
		v_foot.y * clamp(1.0 + distal_amp * 0.85, 0.60, 1.25)
	);
	// Al apuntar hacia atras (distal_amp < 0), el pie sube y se recoge levemente hacia la linea media
	float inward_sign = (abs(p_root.x) > 0.001) ? -sign(p_root.x) : 1.0;
	vec2 foot_recede_shift = vec2(inward_sign * (-distal_amp) * 4.0, distal_amp * 10.0);
	pos_2 = mix(pos_2, p_tip_proj + foot_scaled + foot_recede_shift, clamp(distal_mask, 0.0, 1.0));

	out_z_local = z_local;
	out_kappa_tuck = kappa_tuck;
	out_comp_ratio = mix(c1, c2_effective, w_seg2);
	float local_v_phase = mix(v_seg1_01, v_seg2_01, w_seg2);
	out_uv_relief_shift = 0.0;

	return mix(pos_1, pos_2, w_seg2);
}

vec2 apply_torso_perspective_25d(
	vec2 pos,
	vec2 uv01,
	vec2 p_root,
	vec2 p_tip,
	float torso_trapezoid,
	float yaw_twist,
	float phi_seg1,
	float jacobian_floor,
	out float out_z_local,
	out float out_comp_ratio
) {
	float u_hat = clamp(uv01.x * 2.0 - 1.0, -1.0, 1.0);
	float v_hat = clamp(uv01.y, 0.0, 1.0);
	vec2 axis = p_tip - p_root;
	float len_a = max(length(axis), 1.0);
	vec2 t = axis / len_a;
	vec2 n = vec2(-t.y, t.x);

	vec2 rel = pos - p_root;
	float axial = dot(rel, t);
	float trans = dot(rel, n);

	// En body_core: v_hat = 0 es hombro/cuello, v_hat = 1 es cadera/pelvis.
	float c1 = safe_cos_jacobian(phi_seg1, jacobian_floor);
	float trap_scale = 1.0 + torso_trapezoid * (1.0 - 2.0 * v_hat);
	float cross_arc = torso_trapezoid * 14.0 * (1.0 - u_hat * u_hat);
	float twist_shift_x = yaw_twist * 18.0 * (1.0 - 2.0 * v_hat) * (1.0 - 0.3 * u_hat * u_hat);
	float twist_shift_y = -yaw_twist * 11.0 * u_hat * (1.0 - v_hat);

	out_z_local = clamp(torso_trapezoid * 3.0 * (0.5 - v_hat) + yaw_twist * u_hat * 1.4, -1.0, 1.0);
	out_comp_ratio = c1;

	return p_root + (axial * c1) * t + (trans * trap_scale) * n + vec2(twist_shift_x, cross_arc + twist_shift_y);
}

vec3 apply_perspective_depth_and_occlusion(
	vec3 rgb,
	vec2 uv01,
	float z_depth,
	float kappa_tuck,
	float v_knee_pivot,
	float leg_depth_phase,
	float rim_sweep_dir,
	float n_rim_z_threshold,
	vec3 depth_near_tint_lin,
	vec3 depth_far_tint_lin,
	vec3 rim_occ_col_lin,
	float edge_px_norm,
	float ink_protect
) {
	float u_hat = clamp(uv01.x * 2.0 - 1.0, -1.0, 1.0);
	float v_hat = clamp(uv01.y, 0.0, 1.0);

	// 1. Bolsillo de oclusión articular y cresta iluminada (Knee-Over-Shin / Elbow Tuck)
	float tuck_abs = abs(kappa_tuck);
	float tuck_s = (tuck_abs > 0.005) ? sign(kappa_tuck) : 0.0;
	float s_behind = (v_hat - v_knee_pivot) * tuck_s;
	float pocket_band = smoothstep(0.005, 0.035, s_behind) * (1.0 - smoothstep(0.04, 0.13, s_behind));
	float radial_mask = clamp(1.0 - 0.55 * u_hat * u_hat, 0.0, 1.0);
	float shadow_pocket = tuck_abs * pocket_band * radial_mask;

	float s_crest = (v_knee_pivot - v_hat) * tuck_s;
	float crest_band = smoothstep(-0.01, 0.015, s_crest) * (1.0 - smoothstep(0.015, 0.045, s_crest));
	float sil_rim_gate = smoothstep(0.76, 0.96, abs(u_hat));
	float crest_rim = tuck_abs * crest_band * sil_rim_gate * 0.35;

	// 2. Depth-cueing térmico (combina z_depth local + leg_depth_phase en e/w)
	float z_eff = clamp(z_depth + leg_depth_phase * 0.65, -1.0, 1.0);
	vec3 depth_mod = mix(
		mix(vec3(1.0), depth_far_tint_lin, clamp(-z_eff, 0.0, 1.0)),
		depth_near_tint_lin,
		clamp(z_eff, 0.0, 1.0)
	);
	vec3 out_rgb = rgb * depth_mod * (1.0 - 0.32 * shadow_pocket);
	return out_rgb;
}
