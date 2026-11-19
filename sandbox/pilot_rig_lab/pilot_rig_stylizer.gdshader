shader_type canvas_item;
render_mode blend_mix;

#include "res://sandbox/pilot_rig_lab/shaders/rig_color_recolor.gdshaderinc"
#include "res://sandbox/pilot_rig_lab/shaders/rig_perspective_25d.gdshaderinc"
#include "res://sandbox/pilot_rig_lab/shaders/rig_stylized_lighting.gdshaderinc"

// Presupuesto <= 3 vec4 varyings (Forward Mobile):
// v_rig_data: xy = v_rig_pos (espacio BodyPivot), z = modulate_alpha, w = v_z_depth
// v_def_rest: xy = VERTEX deformado, zw = rest_px (UV / TEXTURE_PIXEL_SIZE)
// v_persp_data: x = kappa_tuck, y = comp_ratio, z = uv_relief_shift, w = v_hat
varying vec4 v_rig_data;
varying vec4 v_def_rest;
varying vec4 v_persp_data;

uniform mat4 inv_body_pivot_matrix = mat4(1.0);
uniform int persp_mode : hint_range(0, 2) = 0; // 0=Neutro, 1=Extremidad 2-seg, 2=Torso body_core
uniform vec4 persp_anchors_root_mid = vec4(0.0, 0.0, 0.0, 100.0);
uniform vec4 persp_anchors_tip_piv = vec4(0.0, 200.0, 0.5, 0.0); // xy=p_tip, z=v_knee_pivot, w=phi_seg1
uniform vec4 persp_params_a = vec4(0.0, 0.1315, 0.22, 0.16); // x=phi_seg2, y=cam_tan_alpha, z=jacobian_floor, w=k_conicity
uniform vec4 persp_params_b = vec4(0.14, 0.0, 0.0, 0.0); // x=k_volume, y=distal_amp, z=distal_toe_heel_bias, w=torso_trapezoid
uniform vec4 persp_params_c = vec4(0.0, 0.0, 0.35, 0.0); // x=yaw_twist, y=rim_sweep_dir, z=n_rim_z_threshold
uniform vec4 depth_near_tint : source_color = vec4(1.08, 1.06, 1.02, 1.0);
uniform vec4 depth_far_tint : source_color = vec4(0.76, 0.80, 0.92, 1.0);
uniform vec4 rim_occlusion_color : source_color = vec4(0.35, 0.75, 1.0, 1.0);
uniform bool use_persp_zone_mask = false;
uniform sampler2D persp_zone_mask : hint_default_black;

void vertex() {
	vec2 tex_size = 1.0 / max(TEXTURE_PIXEL_SIZE, vec2(0.000001));
	vec2 rest_px = UV * tex_size;
	float z_local = 0.0;
	float kappa_tuck = 0.0;
	float comp_ratio = 1.0;
	float uv_relief_shift = 0.0;
	if (persp_mode == 1) {
		vec4 zone_m = use_persp_zone_mask ? textureLod(persp_zone_mask, UV, 0.0) : vec4(0.0);
		VERTEX = apply_limb_perspective_25d(
			VERTEX,
			UV,
			persp_anchors_root_mid.xy,
			persp_anchors_root_mid.zw,
			persp_anchors_tip_piv.xy,
			persp_anchors_tip_piv.z,
			persp_anchors_tip_piv.w,
			persp_params_a.x,
			persp_params_a.y,
			persp_params_a.z,
			persp_params_a.w,
			persp_params_b.x,
			persp_params_b.y,
			persp_params_b.z,
			use_persp_zone_mask,
			zone_m,
			z_local,
			kappa_tuck,
			comp_ratio,
			uv_relief_shift
		);
	} else if (persp_mode == 2) {
		VERTEX = apply_torso_perspective_25d(
			VERTEX,
			UV,
			persp_anchors_root_mid.xy,
			persp_anchors_tip_piv.xy,
			persp_params_b.w,
			persp_params_c.x,
			persp_anchors_tip_piv.w,
			persp_params_a.z,
			z_local,
			comp_ratio
		);
	}
	vec2 rig_pos = compute_rig_space_pos(VERTEX, MODEL_MATRIX, inv_body_pivot_matrix);
	v_rig_data = vec4(rig_pos, COLOR.a, z_local);
	v_def_rest = vec4(VERTEX, rest_px);
	v_persp_data = vec4(kappa_tuck, comp_ratio, uv_relief_shift, clamp(UV.y, 0.0, 1.0));
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
uniform int leg_layer_pass : hint_range(0, 2) = 0; // 0=Completo (bajo torso), 2=Solo media/bota (sobre torso)
uniform int body_hip_skin_pass : hint_range(0, 1) = 0; // 0=Normal, 1=Solo piel de cadera del torso (sobre pierna E/W)
uniform int head_layer_pass : hint_range(0, 2) = 0; // 0=Completo, 1=BajoTorso (Cuello/Mentón/Collar), 2=SobreTorso (Pelo en N / Pelo+Cara en S)
uniform float head_over_face_keep : hint_range(0.0, 1.0) = 0.0;
uniform float neck_seam_u : hint_range(0.0, 1.0) = 0.42;
uniform float neck_seam_half_w : hint_range(0.02, 0.40) = 0.14;
uniform float neck_seam_max_v : hint_range(0.02, 0.25) = 0.085;

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
uniform float rim_light_strength : hint_range(0.0, 1.5) = 0.0;
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

// Inspector Rayos-X (0=Final, 1=Clown-Pass ID, 2=Luminancia, 3=Solo Tinta, 4=Normales 2.5D, 5=Profundidad 2.5D, 6=ILM Mask)
uniform int debug_view_mode : hint_range(0, 6) = 0;

// Máscara ILM opcional (ArcSys / Guilty Gear: R=Spec, G=ShadowBias/AO, B=RimWeight, A=Emissive)
uniform sampler2D ilm_mask_tex : hint_default_white, filter_linear_mipmap;
uniform bool has_ilm_mask = false;
uniform float ilm_shadow_bias_strength : hint_range(0.0, 1.0) = 0.65;
uniform float ilm_spec_strength : hint_range(0.0, 1.5) = 0.75;

// Pipeline 2.5D Normal + Depth + Conic Rim + HDR (Opcional, retrocompatible si use_normal_depth = false)
uniform sampler2D normal_depth_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D conic_rim_lut : source_color, hint_default_white, filter_linear;
uniform float q_time = 0.0;
uniform bool use_normal_depth = false;
uniform vec2 light_dir_2d = vec2(-0.58, -0.81);
uniform float normal_flip_x = 1.0;
uniform float normal_cel_influence : hint_range(0.0, 1.0) = 0.52;
uniform float normal_rim_strength : hint_range(0.0, 2.5) = 0.0;
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

// Activos Fase 1: Máscara de hombrera sobre body_core + SDF de cabeza
uniform sampler2D pauldron_mask_tex : hint_default_black, filter_linear;
uniform bool has_pauldron_mask = false;
uniform sampler2D outline_sdf_tex : hint_default_white, filter_linear;
uniform bool has_outline_sdf = false;
uniform float sdf_pad_px : hint_range(1.0, 64.0) = 24.0;
uniform float head_outline_width_px : hint_range(1.0, 12.0) = 4.0;
uniform bool enable_inward_outline = true;
uniform float inward_outline_px : hint_range(0.0, 4.0) = 1.35;
uniform vec4 inward_outline_color : source_color = vec4(0.015, 0.015, 0.025, 1.0);
uniform bool inward_outline_on_head = false;
uniform bool inward_outline_centered = false;
// Ajuste Fino de Outline por Pieza (Borde transparente que borra PNG + Outline hacia afuera desde el nuevo borde)
uniform bool enable_part_edge_outline = false;
uniform float part_edge_erode_du : hint_range(0.0, 8.0) = 0.0;
uniform float part_edge_outline_du : hint_range(0.0, 8.0) = 0.0;
uniform vec4 part_edge_outline_color : source_color = vec4(0.015, 0.015, 0.025, 1.0);
uniform bool part_edge_respect_seams = false;
uniform bool enable_hip_cast_shadow = false;
uniform sampler2D hip_cast_body_tex : hint_default_transparent;
uniform vec4 hip_cast_body_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 hip_cast_pelvis_delta = vec2(0.0, 0.0);
uniform vec2 hip_cast_shadow_offset_px = vec2(0.8, 3.2);
uniform vec4 hip_cast_shadow_color : source_color = vec4(0.82, 0.68, 0.74, 1.0);
uniform bool enable_stocking_pinch = false;
uniform bool debug_stocking_pinch_overlay = false;
uniform float stocking_pinch_v : hint_range(0.02, 0.75) = 0.25;
uniform float stocking_pinch_center_u : hint_range(0.05, 0.95) = 0.5;
uniform float stocking_pinch_tilt : hint_range(-0.45, 0.45) = 0.0;
uniform float stocking_pinch_strength : hint_range(0.0, 0.45) = 0.045;
uniform float stocking_pinch_width : hint_range(0.005, 0.18) = 0.032;
uniform float stocking_pinch_shadow : hint_range(0.0, 1.0) = 0.20;

// Paquete Oclusivo Fase 1: Normales cilíndricas RNM, Sombras ILM, Mignola, SSS y Nylon
uniform vec2 bone_chain_angles = vec2(0.0, 0.0);
uniform float cylinder_roundness : hint_range(0.0, 1.0) = 0.78;
uniform bool weld_top_seam = false;
uniform bool weld_bottom_seam = false;
uniform float leg_depth_phase : hint_range(-1.0, 1.0) = 0.0;
uniform float stocking_denier : hint_range(0.0, 1.0) = 0.35;
uniform float light_z_tilt : hint_range(0.1, 2.0) = 0.58;
uniform float receiver_height_scale : hint_range(0.0, 40.0) = 18.0;
uniform vec4 caster_capsule_ab = vec4(0.0, -900.0, 0.0, -900.0);
uniform vec2 caster_capsule_radius_height = vec2(0.0, 0.0);
uniform vec4 caster_head_ellipse = vec4(0.0, -900.0, 1.0, 1.0);
uniform float caster_head_height = 0.0;
uniform vec4 shadow_indigo_tint : source_color = vec4(0.56, 0.52, 0.78, 1.0);
uniform vec4 sss_skin_color : source_color = vec4(0.95, 0.42, 0.36, 1.0);
uniform vec4 deep_mignola_ink : source_color = vec4(0.015, 0.015, 0.025, 1.0);
uniform float fold_inner_side = 1.0;
uniform float joint_v_coord : hint_range(0.0, 1.0) = 0.5;
uniform float joint_flexion : hint_range(0.0, 1.0) = 0.0;

// Muestreo morfológico de alfa en radio con signo (unidades de rig `du`):
// r_du > 0.0 -> erosión (borde transparente hacia adentro)
// r_du < 0.0 -> dilatación (expansión de outline hacia afuera)
float sample_morph_alpha(sampler2D tex, vec2 uv, vec2 du_to_uv, float r_du, float base_a) {
	if (abs(r_du) <= 0.001) {
		return base_a;
	}
	bool is_erode = (r_du > 0.0);
	float abs_r = abs(r_du);
	vec2 rad_uv = du_to_uv * abs_r;
	float acc = base_a;
	for (int i = 0; i < 16; i++) {
		float ang = float(i) * 0.3926990817;
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 suv = uv + dir * rad_uv;
		float a = (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) ? 0.0 : textureLod(tex, suv, 0.0).a;
		acc = is_erode ? min(acc, a) : max(acc, a);
	}
	if (abs_r > 0.75) {
		vec2 mid_uv = rad_uv * 0.55;
		for (int j = 0; j < 8; j++) {
			float ang = float(j) * 0.7853981634 + 0.1963495408;
			vec2 dir = vec2(cos(ang), sin(ang));
			vec2 suv = uv + dir * mid_uv;
			float a = (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) ? 0.0 : textureLod(tex, suv, 0.0).a;
			acc = is_erode ? min(acc, a) : max(acc, a);
		}
	}
	if (abs_r > 2.2) {
		vec2 in_uv = rad_uv * 0.28;
		for (int k = 0; k < 8; k++) {
			float ang = float(k) * 0.7853981634;
			vec2 dir = vec2(cos(ang), sin(ang));
			vec2 suv = uv + dir * in_uv;
			float a = (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) ? 0.0 : textureLod(tex, suv, 0.0).a;
			acc = is_erode ? min(acc, a) : max(acc, a);
		}
	}
	return acc;
}

void fragment() {
	vec2 sample_uv = UV;
	vec2 tex_coord_px = UV / TEXTURE_PIXEL_SIZE;
	// Guardia TEST_E_DFDX: usar el eje no comprimido (min) en lugar de promedio isotrópico
	float screen_px_in_texels = clamp(min(length(dFdx(tex_coord_px)), length(dFdy(tex_coord_px))), 0.5, 24.0);
	float def_px_in_tex = clamp(min(length(dFdx(v_def_rest.xy)), length(dFdy(v_def_rest.xy))), 0.25, 24.0);
	float rest_px_step = clamp(min(length(dFdx(v_def_rest.zw)), length(dFdy(v_def_rest.zw))), 0.25, 24.0);
	float s_comp = clamp(def_px_in_tex / max(rest_px_step, 0.0001), 0.25, 4.0);
	vec2 v_rig_pos = v_rig_data.xy;
	float v_modulate_alpha = v_rig_data.z;
	float v_z_depth = v_rig_data.w;
	float v_tuck_factor = v_persp_data.x;
	float v_comp_ratio = v_persp_data.y;
	float v_uv_relief_shift = v_persp_data.z;
	float v_v_hat = v_persp_data.w;

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

	float pinch_dv = 10.0;
	if ((enable_stocking_pinch || debug_stocking_pinch_overlay) && is_leg_part) {
		float y_band = stocking_pinch_v + stocking_pinch_tilt * (sample_uv.x - stocking_pinch_center_u);
		pinch_dv = (sample_uv.y - y_band) / max(stocking_pinch_width, 0.005);
		if (enable_stocking_pinch && stocking_pinch_strength > 0.0005) {
			float pinch_bell = exp(-0.5 * pinch_dv * pinch_dv);
			float puff_bell = exp(-0.5 * pow((pinch_dv + 1.35) / 1.1, 2.0));
			float radial_s = 1.0 + stocking_pinch_strength * (pinch_bell - 0.38 * puff_bell);
			sample_uv.x = clamp(stocking_pinch_center_u + (sample_uv.x - stocking_pinch_center_u) * radial_s, 0.001, 0.999);
		}
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

	vec2 albedo_uv = (persp_mode > 0) ? vec2(sample_uv.x, clamp(sample_uv.y + v_uv_relief_shift, 0.001, 0.999)) : sample_uv;
	float albedo_lod_bias = (persp_mode > 0) ? log2(clamp(v_comp_ratio, 0.25, 1.0)) : 0.0;
	vec4 base = (abs(albedo_lod_bias) > 0.01) ? texture(TEXTURE, albedo_uv, albedo_lod_bias) : texture(TEXTURE, albedo_uv);
	float aa_a = clamp(fwidth(base.a) * 0.85, 0.10, 0.45);
	bool valid_nd = use_normal_depth && (dot(nd_sample.rgb, nd_sample.rgb) > 0.01);
	vec3 n_cyl_local = vec3(0.0, 0.0, 1.0);
	vec3 n25 = vec3(0.0, 0.0, 1.0);
	float ndl = 0.5;
	vec2 l2d = length(light_dir_2d) > 0.001 ? normalize(light_dir_2d) : vec2(-0.58, -0.81);
	float open_bridge = (!is_head_part && weld_top_seam)
		? (1.0 - smoothstep(0.02, 0.18, sample_uv.y)) * smoothstep(0.46, 0.24, abs(sample_uv.x - 0.5))
		: 0.0;
	if (valid_nd) {
		if (is_head_part) {
			n_cyl_local = normalize(nd_sample.rgb * 2.0 - vec3(1.0));
			n_cyl_local.x *= normal_flip_x;
			n25 = n_cyl_local;
		} else {
			float eff_roundness = cylinder_roundness * (1.0 - open_bridge * 0.85);
			float xc = (sample_uv.x * 2.0 - 1.0) * eff_roundness;
			n_cyl_local = normalize(vec3(xc, 0.0, sqrt(max(1.0 - xc * xc, 0.06))));
			n25 = compute_cylindrical_rnm_normal(
				sample_uv,
				nd_sample.rgb,
				eff_roundness,
				weld_top_seam,
				weld_bottom_seam,
				bone_chain_angles,
				normal_flip_x
			);
		}
		vec3 l3 = normalize(vec3(l2d, light_z_tilt));
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
	float hair_cov = is_head_part ? raw_mask.a : 0.0;
	float is_hair = is_head_part ? smoothstep(0.12, 0.38, hair_cov) : 0.0;
	float is_collar_blue = is_head_part ? smoothstep(0.42, 0.58, texture(id_mask_tex, sample_uv).b) : 0.0;
	if (is_head_part) {
		// En cabezas nuevas, el canal azul marca el cuello de piel para dividir capas (Pass 1 bajo torso vs Pass 2 sobre torso), no traje oscuro.
		mask.b = 0.0;
	}

	bool allow_head_outline = (head_layer_pass != 1) || (head_over_face_keep < 0.5) || (is_hair < 0.5);
	bool use_part_edge_outline = enable_part_edge_outline && (part_edge_erode_du > 0.001 || part_edge_outline_du > 0.001);
	float part_edge_fill_a = base.a;
	float part_edge_total_a = base.a;
	if (use_part_edge_outline) {
		vec2 du_to_uv = 1.0 / max(part_rig_rect.zw * 490.0, vec2(1.0));
		float r_outer_du = part_edge_erode_du - part_edge_outline_du;
		part_edge_total_a = sample_morph_alpha(TEXTURE, sample_uv, du_to_uv, r_outer_du, base.a);
		if (part_edge_total_a < 0.02) {
			discard;
		}
		part_edge_fill_a = (part_edge_erode_du > 0.001)
			? ((base.a < 0.02) ? 0.0 : sample_morph_alpha(TEXTURE, sample_uv, du_to_uv, part_edge_erode_du, base.a))
			: base.a;
	} else if (base.a < 0.02) {
		discard;
	}

	vec3 rgb = base.rgb;
	vec3 srgb_base = linear_to_srgb(max(base.rgb, vec3(0.0)));
	float orig_luma = dot(srgb_base, vec3(0.299, 0.587, 0.114));

	float stocking_cuff_alpha = 1.0;
	if (is_leg_part && leg_layer_pass == 2) {
		// Recortar Part_leg_*_stocking solo al cuff superior traslapado (UV.y in [0.25, 0.48]) sin discard
		float cuff_top = smoothstep(0.25, 0.27, sample_uv.y);
		float cuff_bot = 1.0 - smoothstep(0.44, 0.48, sample_uv.y);
		float cuff_mask = smoothstep(0.20, 0.45, raw_mask.a);
		stocking_cuff_alpha = cuff_top * cuff_bot * cuff_mask;
	}
	if (!is_head_part && !is_leg_part && body_hip_skin_pass == 1) {
		if (sample_uv.y <= 0.52) {
			discard;
		}
	}

	// Las máscaras 1:1 cerradas por tinta ya separan Piel, Medias, Traje, Armadura, Acentos y Pelo sin override por color RGB.

	// 3.5 Separación Z Automática Cabeza vs Torso (Pelo sobre Torso / Cuello y Mentón bajo Torso en N)
	float layer_alpha = stocking_cuff_alpha;
	float is_hair_pass = 0.0;
	if (is_head_part && head_layer_pass > 0) {
		is_hair_pass = is_hair;
		float eff_head_a = use_part_edge_outline ? max(base.a, part_edge_total_a) : base.a;
		if (head_layer_pass == 1) {
			// Pass 1 (Detrás del torso): renderizar solo cuello azul y empalme inferior bajo mentón/nuca, descartando cráneo/pelo superior para evitar fantasmas o manchas tras Pass 2.
			float neck_or_seam = max(is_collar_blue, smoothstep(0.55, 0.72, UV.y));
			layer_alpha = neck_or_seam * mix(1.0, smoothstep(0.82, 0.98, eff_head_a), is_hair);
		} else if (head_layer_pass == 2) {
			// Pass 2 (Sobre el torso): descartar estrictamente el cuello azul en todas las vistas, manteniendo pelo real y rostro/mentón encima.
			float is_collar = smoothstep(0.25, 0.45, is_collar_blue) * (1.0 - smoothstep(0.35, 0.65, raw_mask.a));
			if (head_over_face_keep < 0.5) {
				float is_face_skin = smoothstep(0.35, 0.65, w_skin) * (1.0 - is_collar);
				layer_alpha = max(is_hair, is_face_skin) * (1.0 - is_collar) * smoothstep(0.0, 0.12, eff_head_a);
			} else {
				layer_alpha = 1.0 - is_collar;
			}
		}
		if (layer_alpha < 0.02) {
			discard;
		}
	}

	float hair_fx_weight = 0.0;
	float mat_weight = clamp(mask.r + mask.g + mask.b + (is_head_part ? mask.a : 0.0), 0.0, 1.0);
	float armor_suit_weight = clamp(mask.b + mask.g + mask.r * 0.6 + hair_fx_weight, 0.0, 1.0);

	// 4. Recoloreo de Traje, Armadura, Acentos y Medias (Usando `recolor_method` + Luminancia Estabilizada)
	bool need_hair_recolor = is_head_part && mask.a > 0.01 && (enable_shader_recolor || enable_hair_recolor || hair_style_mode > 0);
	float stab_luma = orig_luma;
	if ((enable_shader_recolor || need_hair_recolor) && debug_view_mode == 0) {
		float l_sum = orig_luma * 1.4;
		float w_sum = 1.4;
		vec2 offs[4] = vec2[4](vec2(1.5, 0.0), vec2(-1.5, 0.0), vec2(0.0, 1.5), vec2(0.0, -1.5));
		for (int i = 0; i < 4; i++) {
			vec2 tuv = clamp(sample_uv + offs[i] * TEXTURE_PIXEL_SIZE, vec2(0.0), vec2(1.0));
			vec4 tc = textureLod(TEXTURE, tuv, 0.0);
			if (tc.a > 0.35) {
				vec3 ts = linear_to_srgb(max(tc.rgb, vec3(0.0)));
				float tl = dot(ts, vec3(0.299, 0.587, 0.114));
				vec4 tm = textureLod(id_mask_tex, tuv, 0.0);
				float id_sim = is_head_part
					? 1.0 - clamp(abs(tm.a - raw_mask.a) + abs(tm.r - raw_mask.r) + abs(tm.b - raw_mask.b), 0.0, 1.0)
					: clamp(dot(normalize(tm + vec4(0.0001)), normalize(raw_mask + vec4(0.0001))), 0.0, 1.0);
				float not_ink = smoothstep(0.08, 0.16, tl);
				float tone_w = exp(-abs(tl - orig_luma) * 14.0);
				float w = id_sim * not_ink * tone_w;
				l_sum += tl * w;
				w_sum += w;
			}
		}
		stab_luma = mix(orig_luma, l_sum / w_sum, 0.72);
	}
	if (enable_shader_recolor) {
		// Normalizar la luminancia interna de cada material respecto a su rango en el dibujo original:
		// - Traje Oscuro (mask.b): stab_luma va de ~0.12 (sombra) a ~0.27 (luz)
		// - Paneles Armadura (mask.g): stab_luma va de ~0.20 (sombra) a ~0.46 (luz)
		// - Acentos Rojos (mask.r): stab_luma va de ~0.18 (sombra) a ~0.42 (luz)
		float t_suit = clamp((stab_luma - 0.06) / 0.21, 0.0, 1.0);
		float t_panel = clamp((stab_luma - 0.19) / 0.27, 0.0, 1.0);
		float t_acc = clamp((stab_luma - 0.17) / 0.25, 0.0, 1.0);

		vec3 target_suit = apply_recolor_algorithm(suit_dark_color.rgb, t_suit, stab_luma, 0.19, recolor_method, recolor_contrast, recolor_highlight, recolor_saturation);
		vec3 target_panel = apply_recolor_algorithm(panel_color.rgb, t_panel, stab_luma, 0.32, recolor_method, recolor_contrast, recolor_highlight, recolor_saturation);
		vec3 target_acc = apply_recolor_algorithm(accent_color.rgb, t_acc, stab_luma, 0.29, recolor_method, recolor_contrast, recolor_highlight, recolor_saturation);

		float recolor_ink_keep = smoothstep(0.05, 0.13, orig_luma);
		rgb = mix(rgb, target_suit, mask.b * recolor_ink_keep);
		rgb = mix(rgb, target_panel, mask.g * recolor_ink_keep);
		rgb = mix(rgb, target_acc, mask.r * recolor_ink_keep);

		if (!is_head_part && mask.a > 0.01) {
			float garter_protect = smoothstep(0.07, 0.15, stab_luma);
			float nylon_opacity = clamp(stocking_tint_strength * 1.15 * garter_protect, 0.0, 0.90);
			float t_nylon = clamp((stab_luma - 0.10) / 0.28, 0.0, 1.0);
			vec3 nylon_base = apply_recolor_algorithm(suit_dark_color.rgb, t_nylon, stab_luma, 0.22, recolor_method, recolor_contrast, recolor_highlight, recolor_saturation);
			vec3 under_skin = mix(nylon_base, srgb_to_linear(vec3(0.92, 0.68, 0.60)), 0.65);
			float mu = clamp(n_cyl_local.z, 0.0, 1.0);
			float sheer_trans = pow(mu, 1.85) * (1.0 - stocking_denier);
			vec3 nylon_sheen = mix(nylon_base, under_skin, sheer_trans);
			nylon_sheen = mix(nylon_sheen, srgb_to_linear(vec3(0.95, 0.88, 0.84)) * max(suit_dark_color.rgb * 1.6, srgb_to_linear(vec3(0.28))), smoothstep(0.55, 0.95, t_nylon) * 0.42);
			rgb = mix(rgb, clamp(nylon_sheen, vec3(0.0), vec3(1.0)), mask.a * nylon_opacity * recolor_ink_keep);
		}
	}

	// 5. Laboratorio de Recoloreo y Estilo de Cabello (`is_head_part` + `mask.a`)
	if (need_hair_recolor) {
		float t_hair = clamp((stab_luma - 0.48) / 0.36, 0.0, 1.0);
		vec3 base_hair_col = apply_recolor_algorithm(hair_color.rgb, t_hair, stab_luma, 0.74, recolor_method, recolor_contrast, recolor_highlight, recolor_saturation);
		float soft = max(hair_cut_softness, 0.015);

		if (hair_style_mode == 1) {
			// Modo 1: Bicolor Trigger / Edgerunners (Umbral regulable por hair_cut_height y hair_cut_softness)
			float is_lit_strand = smoothstep(hair_cut_height - soft * 0.5, hair_cut_height + soft * 0.5, t_hair);
			vec3 under_dye = mix(hair_secondary_color.rgb * 0.88, base_hair_col, 1.0 - hair_effect_strength);
			base_hair_col = mix(under_dye, base_hair_col, is_lit_strand);
		} else if (hair_style_mode == 2) {
			// Modo 2: Puntas Teñidas / Dip-Dye (Altura y transición regulables)
			float tip_factor = smoothstep(hair_cut_height - soft, hair_cut_height + soft, UV.y);
			vec3 tip_col = apply_recolor_algorithm(hair_secondary_color.rgb, t_hair, stab_luma, 0.74, recolor_method, recolor_contrast, recolor_highlight, recolor_saturation);
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

	if (false && is_head_part && head_layer_pass == 1 && debug_view_mode == 0 && is_hair_pass > 0.01) {
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

	vec4 ilm_sample = has_ilm_mask ? textureLod(ilm_mask_tex, sample_uv, 0.0) : vec4(0.15, 0.5, 1.0, 0.0);
	float ilm_spec = has_ilm_mask ? ilm_sample.r : 0.0;
	float ilm_shadow_bias = has_ilm_mask ? (ilm_sample.g - 0.5) * 2.0 : 0.0;
	float ilm_rim_weight = has_ilm_mask ? ilm_sample.b : 1.0;
	float ilm_emissive = has_ilm_mask ? ilm_sample.a : 0.0;

	float eff_cel_step = cel_step_strength;
	if (eff_cel_step > 0.01) {
		float cel_luma = clamp(fx_luma + ilm_shadow_bias * 0.22 * ilm_shadow_bias_strength, 0.0, 1.0);
		float b1 = smoothstep(0.20, 0.24, cel_luma);
		float b2 = smoothstep(0.37, 0.42, cel_luma);
		float stepped_factor = (0.72 + b1 * 0.22 + b2 * 0.22);
		rgb = mix(rgb, clamp(rgb * stepped_factor, vec3(0.0), vec3(1.0)), armor_suit_weight * eff_cel_step);
	}
	if (has_ilm_mask && debug_view_mode == 0) {
		// Sombra AO permanente (G < 0.25) y especular duro ILM (R) + emisivo (A)
		float ao_dark = clamp((0.30 - ilm_sample.g) / 0.30, 0.0, 1.0) * ilm_shadow_bias_strength;
		rgb = mix(rgb, rgb * srgb_to_linear(shadow_indigo_tint.rgb * 0.65), ao_dark * 0.72);
		float spec_ndl = smoothstep(0.52, 0.78, ndl);
		rgb = clamp(rgb + vec3(spec_ndl * ilm_spec * ilm_spec_strength * 0.35), vec3(0.0), vec3(max(crt_hdr_boost, 1.25)));
		if (ilm_emissive > 0.05) {
			rgb += accent_color.rgb * ilm_emissive * max(glow_intensity - 0.5, 0.2) * 0.65;
		}
	}

	if (noir_shadow_crush > 0.01) {
		float noir_w = clamp(mask.b + mask.g * 0.7, 0.0, 1.0);
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
			float hi_band = smoothstep(thr - 0.04, thr + 0.06, fx_luma) * clamp(mask.g + mask.r, 0.0, 1.0);
			vec3 pop_hi = mix(rgb, vec3(1.0), 0.45) + accent_color.rgb * 0.18;
			rgb = mix(rgb, clamp(pop_hi, vec3(0.0), vec3(1.0)), pat_light * hi_band * clamp(halftone_strength * 1.15, 0.0, 0.88));
		}
	}

	// 9. Luz de Reborde (Rim-Light Simple y Dual-Rim con Ancho e Intensidad Regulables)
	float edge_alpha_guard = smoothstep(0.65, 0.95, base.a);
	if (false && suppress_alpha_rim < 0.5 && (rim_light_strength > 0.01 || dual_rim_strength > 0.01)) {
		vec2 px = TEXTURE_PIXEL_SIZE * rim_width_px;
		if (rim_light_strength > 0.01) {
			float a_left = texture(TEXTURE, clamp(sample_uv + vec2(-px.x, -px.y * 0.6), vec2(0.0), vec2(1.0))).a;
			float rim_left = clamp(base.a - a_left, 0.0, 1.0) * smoothstep(0.14, 0.26, orig_luma) * edge_alpha_guard;
			vec3 rim_col_a = mix(accent_color.rgb, vec3(1.0), 0.35);
			rgb = clamp(rgb + rim_col_a * rim_left * rim_light_strength * mat_weight * 0.25, vec3(0.0), vec3(1.0));
		}
		if (dual_rim_strength > 0.01) {
			float a_right = texture(TEXTURE, clamp(sample_uv + vec2(px.x * 1.1, -px.y * 0.4), vec2(0.0), vec2(1.0))).a;
			float rim_right = clamp(base.a - a_right, 0.0, 1.0) * smoothstep(0.14, 0.26, orig_luma) * edge_alpha_guard;
			vec3 cyan_rim = srgb_to_linear(vec3(0.0, 0.94, 1.0));
			rgb = clamp(rgb + cyan_rim * rim_right * dual_rim_strength * mat_weight, vec3(0.0), vec3(1.0));
		}
	}

	// 9.5 Iluminación Direccional 2.5D + Sombras Analíticas ILM + Open Anime Ink + Mignola + SSS + Nylon Fresnel
	if (valid_nd) {
		float ink_protect = smoothstep(0.08, 0.16, orig_luma) * edge_alpha_guard;
		float z_rec = nd_sample.a * receiver_height_scale;
		vec2 p_proj_caps = v_rig_pos - l2d * max(0.0, caster_capsule_radius_height.y - z_rec);
		float d_caps = caster_capsule_radius_height.x > 0.01
			? sd_capsule_2d(p_proj_caps, caster_capsule_ab.xy, caster_capsule_ab.zw, caster_capsule_radius_height.x)
			: 100.0;
		vec2 p_proj_head = v_rig_pos - l2d * max(0.0, caster_head_height - z_rec);
		float d_head = (!is_head_part && caster_head_height > 0.01)
			? sd_ellipse_approx(p_proj_head, caster_head_ellipse.xy, caster_head_ellipse.zw)
			: 100.0;
		float cast_shadow = smoothstep(1.25, -1.25, min(d_caps, d_head));
		if (has_pauldron_mask && !is_head_part && !is_leg_part) {
			float p_mask = texture(pauldron_mask_tex, clamp(sample_uv - l2d * TEXTURE_PIXEL_SIZE * 4.5, vec2(0.0), vec2(1.0))).r;
			cast_shadow = max(cast_shadow, p_mask * 0.55);
		}
		float back_leg_factor = is_leg_part ? clamp(-leg_depth_phase, 0.0, 1.0) : 0.0;
		float front_leg_factor = is_leg_part ? clamp(leg_depth_phase, 0.0, 1.0) : 0.0;
		float i_raw = (ndl * 0.5 + 0.5) - cast_shadow * 0.42 - back_leg_factor * 0.16;
		i_raw = mix(i_raw, max(i_raw, 0.54), open_bridge * 0.65);

		float cel_min = is_head_part ? mix(0.90, 0.82, mask.a) : 0.88;
		float cel_max = is_head_part ? mix(1.08, 1.15, mask.a) : 1.15;
		float depth_bias = max(nd_sample.a - 0.5, -0.08) * 0.24;
		float cel_n = mix(cel_min, cel_max, smoothstep(-0.20, 0.34, (i_raw - 0.5) * 2.0 + depth_bias));
		rgb *= mix(1.0, cel_n, normal_cel_influence * ink_protect);

		// SSS cálido en el terminador de piel
		float w_skin_clean = clamp(1.0 - (mask.r + mask.g + mask.b + mask.a), 0.0, 1.0);
		float sss_band = exp(-pow((i_raw - 0.46) / 0.085, 2.0)) * w_skin_clean * (1.0 - cast_shadow * 0.65) * ink_protect;
		rgb = mix(rgb, rgb + sss_skin_color.rgb * 0.22, sss_band);

		// Especular anisotrópico longitudinal de nylon en zona iluminada (sin discard)
		if (!is_head_part && mask.a > 0.01) {
			float mu = clamp(n_cyl_local.z, 0.0, 1.0);
			float aniso_spec = smoothstep(0.16, 0.04, abs(n_cyl_local.x - l2d.x * 0.35)) * step(0.75, mu) * smoothstep(0.45, 0.55, i_raw);
			rgb += srgb_to_linear(vec3(0.78, 0.90, 1.0)) * (aniso_spec * 0.16 * mask.a * ink_protect);
		}

		// Cuña cóncava Scythe-Wedge Mignola en pliegues articulares (confinada al borde real y sutil)
		if (!is_head_part && !is_leg_part && joint_flexion > 0.05) {
			float u_fold = (fold_inner_side >= 0.0) ? (1.0 - sample_uv.x) : sample_uv.x;
			float dv_joint = abs(sample_uv.y - joint_v_coord);
			float wedge_reach = 0.16 * joint_flexion * pow(max(0.0, 1.0 - dv_joint / 0.16), 1.8) + max(0.0, -ndl) * 0.05 * joint_flexion;
			float sigma_u = max(fwidth(u_fold) * s_comp * 0.75, 0.008);
			float mignola_wedge = smoothstep(wedge_reach + sigma_u, wedge_reach - sigma_u, u_fold) * (1.0 - open_bridge) * 0.35;
			rgb = mix(rgb, deep_mignola_ink.rgb, mignola_wedge * ink_protect);
		}

		if (false && normal_rim_strength > 0.01) {
			vec2 conic_uv = clamp(vec2(0.5) + n25.xy * 0.46, vec2(0.02), vec2(0.98));
			vec3 conic_col = texture(conic_rim_lut, conic_uv).rgb;
			float grazing = pow(clamp(1.0 - max(n25.z, 0.0), 0.0, 1.0), 2.1);
			float depth_pop = mix(0.65, 1.25, nd_sample.a);
			float rim_scale = is_head_part ? mix(0.28, 0.42, mask.a) : 0.45;
			float key_align = clamp(dot(n25.xy, l2d) * 0.5 + 0.5, 0.0, 1.0);
			float key_rim = smoothstep(0.32, 0.86, key_align);
			float fill_rim = smoothstep(0.32, 0.86, 1.0 - key_align) * 0.42 + front_leg_factor * 0.35;
			vec3 rim_split = conic_col * (key_rim + fill_rim * srgb_to_linear(vec3(0.65, 0.82, 1.0)));
			rgb += rim_split * grazing * depth_pop * normal_rim_strength * ink_protect * rim_scale * ilm_rim_weight;
		}

		// Transición Estilizada 1: Barrido de sombra cel direccional + Rim Fresnel siguiendo las Normales 3D
		if (transition_fx_mode == 1 && transition_fx_strength > 0.005) {
			vec3 turn_l = normalize(vec3(light_dir_2d.x + transition_turn_dir * transition_fx_strength * 1.45, light_dir_2d.y, 0.48));
			float turn_ndl = dot(n25, turn_l);
			float cel_sweep_shadow = 1.0 - smoothstep(-0.22, 0.28, turn_ndl);
			rgb = mix(rgb, rgb * srgb_to_linear(vec3(0.52, 0.58, 0.78)), cel_sweep_shadow * transition_fx_strength * 0.62 * ink_protect);
			float turn_fresnel = pow(clamp(1.0 - max(n25.z, 0.0), 0.0, 1.0), 1.35) * smoothstep(-0.08, 0.55, abs(n25.x));
			vec3 turn_rim_col = mix(accent_color.rgb, srgb_to_linear(vec3(0.18, 0.96, 1.0)), 0.38);
			rgb += turn_rim_col * turn_fresnel * transition_fx_strength * ink_protect * 0.95;
		}
	}

	if (persp_mode > 0 && debug_view_mode == 0) {
		float edge_px_norm = clamp(2.0 * screen_px_in_texels * TEXTURE_PIXEL_SIZE.x * 2.0, 0.03, 0.28);
		float persp_ink_protect = smoothstep(0.08, 0.16, orig_luma);
		rgb = apply_perspective_depth_and_occlusion(
			rgb,
			sample_uv,
			v_z_depth,
			v_tuck_factor,
			persp_anchors_tip_piv.z,
			is_leg_part ? leg_depth_phase : 0.0,
			persp_params_c.y,
			persp_params_c.z,
			depth_near_tint.rgb,
			depth_far_tint.rgb,
			rim_occlusion_color.rgb,
			edge_px_norm,
			persp_ink_protect
		);
	}

	// Transición Estilizada 2: Anime Ink-Smear + Silhouette Rim-Flash (oculta costuras detrás de flash limpio + tinta intacta)
	if (transition_fx_mode == 2 && transition_fx_strength > 0.005) {
		float ink_protect_smear = smoothstep(0.11, 0.22, orig_luma);
		float flash_w = smoothstep(0.22, 0.88, transition_fx_strength);
		vec3 flash_grad = mix(accent_color.rgb * 1.15, srgb_to_linear(vec3(0.95, 0.99, 1.0)), nd_sample.a * 0.62);
		rgb = mix(rgb, flash_grad, flash_w * ink_protect_smear * 0.88);
	}

	// Transición Estilizada 3: Borde láser Holo-Sweep Cyber-Cut
	if (holo_beam > 0.005) {
		vec3 beam_col = mix(accent_color.rgb, srgb_to_linear(vec3(0.15, 0.96, 1.0)), 0.58) * 1.45;
		rgb = clamp(mix(rgb, beam_col, holo_beam * 0.92), vec3(0.0), vec3(max(crt_hdr_boost, 1.25)));
	}

	// Emparejar tono de piel del stud superior de la pierna con la piel del torso (sin oscurecimiento AO)
	if (is_leg_part && debug_view_mode == 0 && sample_uv.y < 0.13 && orig_luma > 0.35 && orig_luma < 0.72) {
		float stud_y_w = 1.0 - smoothstep(0.06, 0.13, sample_uv.y);
		float stud_luma_w = smoothstep(0.72, 0.56, orig_luma);
		rgb *= mix(1.0, 1.15, stud_y_w * stud_luma_w);
	}

	// 10. Pulso Holográfico + Boost HDR CRT
	float hdr_cap = max(crt_hdr_boost, 1.0);
	rgb = clamp(rgb, vec3(0.0), vec3(hdr_cap));

	float pulse = 1.0 + 0.14 * sin(q_time * pulse_speed);
	vec3 emissive_boost = rgb * (glow_intensity * pulse) * mask.r * 0.42 * hdr_cap * edge_alpha_guard;
	rgb = clamp(rgb + emissive_boost, vec3(0.0), vec3(hdr_cap));

	// 10.5 Outline Exterior de Tinta + De-Matting + Inward Ink-Seal Adaptativo (después de iluminación 2.5D y HDR)
	float neck_seam_mask = 0.0;
	if (!is_head_part && !is_leg_part) {
		float nx = abs(sample_uv.x - neck_seam_u) / max(neck_seam_half_w, 0.001);
		float ny = max(sample_uv.y, 0.0) / max(neck_seam_max_v, 0.001);
		float nd = sqrt(nx * nx + ny * ny);
		neck_seam_mask = 1.0 - smoothstep(0.62, 1.02, nd);
	}
	bool is_leg_top_seam = (is_leg_part && sample_uv.y < 0.012);
	bool is_arm_top_seam = (!is_head_part && !is_leg_part && weld_top_seam && sample_uv.y < 0.12);
	bool is_stocking_overlay = (is_leg_part && leg_layer_pass == 2);
	vec2 seal_px = TEXTURE_PIXEL_SIZE * clamp(screen_px_in_texels * 0.45, 1.5, 3.2);
	vec2 seal_diag = seal_px * 0.70710678;
	float a_hl = texture(TEXTURE, clamp(sample_uv - vec2(seal_px.x * 1.35, 0.0), vec2(0.0), vec2(1.0))).a;
	float a_hr = texture(TEXTURE, clamp(sample_uv + vec2(seal_px.x * 1.35, 0.0), vec2(0.0), vec2(1.0))).a;
	float a_up_2 = texture(TEXTURE, clamp(sample_uv - vec2(0.0, seal_px.y * 2.2), vec2(0.0), vec2(1.0))).a;
	bool is_body_bottom_seam = (!is_head_part && !is_leg_part && weld_bottom_seam && sample_uv.y > 0.78 && base.a < 0.95);
	float outline_seam_keep = clamp(neck_seam_mask + (is_leg_top_seam || is_arm_top_seam || is_body_bottom_seam ? 1.0 : 0.0), 0.0, 1.0);
	float seam_feather_keep = clamp(outline_seam_keep + (is_stocking_overlay ? 1.0 : 0.0), 0.0, 1.0);
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
	float inward_seal = (1.0 - smoothstep(0.18, 0.62, min_nb_a)) * seal_edge_gate * (1.0 - seam_feather_keep);
	bool suppress_head_collar_ink = is_head_part && (is_collar_blue > 0.25 && is_hair < 0.5);
	if (is_head_part && (!allow_head_outline || suppress_head_collar_ink || (head_layer_pass == 1 && is_hair > 0.5))) {
		inward_seal = 0.0;
	}
	float head_mip_guard = is_head_part ? (1.0 - smoothstep(5.5, 11.5, screen_px_in_texels) * 0.75) : 1.0;

	// 10.2 Sombra Cel Plana de Contacto Traje -> Piernas + Micro-sombra de liga (pinch)
	if (enable_stocking_pinch && is_leg_part && stocking_pinch_shadow > 0.005 && debug_view_mode == 0) {
		float p_sh = smoothstep(-1.25, -0.25, pinch_dv) * (1.0 - smoothstep(-0.05, 0.25, pinch_dv)) * (1.0 - mask.a) * stocking_pinch_shadow;
		rgb = mix(rgb, rgb * srgb_to_linear(vec3(0.84, 0.66, 0.70)), p_sh);
	}
	if (debug_stocking_pinch_overlay && is_leg_part) {
		float dbg_pinch = exp(-0.5 * pinch_dv * pinch_dv);
		float dbg_puff = exp(-0.5 * pow((pinch_dv + 1.35) / 1.1, 2.0));
		float dbg_line = 1.0 - smoothstep(0.03, 0.12, abs(pinch_dv));
		rgb = mix(rgb, srgb_to_linear(vec3(1.0, 0.22, 0.85)), dbg_puff * 0.42);
		rgb = mix(rgb, srgb_to_linear(vec3(0.0, 0.95, 1.0)), dbg_pinch * 0.52);
		rgb = mix(rgb, srgb_to_linear(vec3(1.0, 0.95, 0.1)), dbg_line * 0.85);
	}
	if (enable_hip_cast_shadow && is_leg_part && debug_view_mode == 0) {
		vec2 body_size_px = max(hip_cast_body_rect.zw * 490.0, vec2(1.0));
		vec2 leg_in_body_px = (v_rig_pos - hip_cast_pelvis_delta) - (hip_cast_body_rect.xy * 490.0);
		vec2 sample_px = leg_in_body_px - hip_cast_shadow_offset_px;
		vec2 bc_uv = sample_px / body_size_px;
		if (bc_uv.x >= 0.0 && bc_uv.x <= 1.0 && bc_uv.y >= 0.48 && bc_uv.y <= 1.0) {
			float bc_a = textureLod(hip_cast_body_tex, bc_uv, 0.0).a;
			float cel_shadow_mask = smoothstep(0.45, 0.55, bc_a) * smoothstep(0.10, 0.20, orig_luma);
			rgb = mix(rgb, rgb * srgb_to_linear(hip_cast_shadow_color.rgb), cel_shadow_mask);
		}
	}

	// 10.5 Outline Fino (Per-Piece Erosión + Outline Externo o Legacy Inward Outline)
	float centered_outer_alpha = 0.0;
	float part_edge_final_alpha = base.a;
	if (use_part_edge_outline) {
		float edge_aa = clamp(max(fwidth(part_edge_fill_a), fwidth(part_edge_total_a)) * 0.75, 0.06, 0.35);
		float crisp_fill = smoothstep(0.5 - edge_aa, 0.5 + edge_aa, part_edge_fill_a);
		float crisp_total = smoothstep(0.5 - edge_aa, 0.5 + edge_aa, part_edge_total_a);
		float seam_mult = part_edge_respect_seams ? (1.0 - outline_seam_keep) : 1.0;
		if (part_edge_respect_seams && is_head_part && suppress_head_collar_ink) {
			seam_mult = 0.0;
		}
		part_edge_final_alpha = mix(crisp_fill, crisp_total, seam_mult);
		if (part_edge_outline_du > 0.001 && debug_view_mode == 0) {
			vec3 edge_ink_lin = srgb_to_linear(part_edge_outline_color.rgb);
			float outline_mix = (1.0 - crisp_fill) * seam_mult;
			rgb = mix(rgb, edge_ink_lin, outline_mix);
		}
	} else if (enable_inward_outline && debug_view_mode == 0 && (!is_head_part || inward_outline_on_head)) {
		float half_scale = inward_outline_centered ? 0.55 : 1.0;
		float radius_tex = clamp(inward_outline_px * half_scale * clamp(screen_px_in_texels * 0.65, 1.15, 3.2), 0.75, 4.5);
		vec2 o_px = TEXTURE_PIXEL_SIZE * radius_tex;
		vec2 o_diag = o_px * 0.70710678;
		float a0 = texture(TEXTURE, clamp(sample_uv + vec2(o_px.x, 0.0), vec2(0.0), vec2(1.0))).a;
		float a1 = texture(TEXTURE, clamp(sample_uv - vec2(o_px.x, 0.0), vec2(0.0), vec2(1.0))).a;
		float a2 = texture(TEXTURE, clamp(sample_uv + vec2(0.0, o_px.y), vec2(0.0), vec2(1.0))).a;
		float a3 = texture(TEXTURE, clamp(sample_uv - vec2(0.0, o_px.y), vec2(0.0), vec2(1.0))).a;
		float a4 = texture(TEXTURE, clamp(sample_uv + vec2(o_diag.x, o_diag.y), vec2(0.0), vec2(1.0))).a;
		float a5 = texture(TEXTURE, clamp(sample_uv + vec2(-o_diag.x, o_diag.y), vec2(0.0), vec2(1.0))).a;
		float a6 = texture(TEXTURE, clamp(sample_uv + vec2(o_diag.x, -o_diag.y), vec2(0.0), vec2(1.0))).a;
		float a7 = texture(TEXTURE, clamp(sample_uv - vec2(o_diag.x, o_diag.y), vec2(0.0), vec2(1.0))).a;
		float nb_min = min(min(min(a0, a1), min(a2, a3)), min(min(a4, a5), min(a6, a7)));
		float nb_max = max(max(max(a0, a1), max(a2, a3)), max(max(a4, a5), max(a6, a7)));

		float inner_band = (1.0 - smoothstep(0.18, 0.78, nb_min)) * smoothstep(0.08, 0.32, base.a);
		float replace_png_ink = (1.0 - smoothstep(0.08, 0.22, orig_luma)) * (1.0 - smoothstep(0.25, 0.96, nb_min));
		float outer_band = inward_outline_centered ? (smoothstep(0.18, 0.75, nb_max) * (1.0 - smoothstep(0.18, 0.75, base.a))) : 0.0;
		float seam_gate = (1.0 - outline_seam_keep);
		float crisp_w = clamp(max(max(inner_band, replace_png_ink), outer_band), 0.0, 1.0) * seam_gate;
		vec3 ink_lin = srgb_to_linear(inward_outline_color.rgb);
		rgb = mix(rgb, ink_lin, crisp_w);
		if (inward_outline_centered) {
			centered_outer_alpha = outer_band * seam_gate * stocking_cuff_alpha;
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
		// Mapa de Normales 2.5D (Sapiens-Lite + Portador Cilíndrico RNM)
		rgb = valid_nd ? clamp(n25 * 0.5 + 0.5, vec3(0.0), vec3(1.0)) : nd_sample.rgb;
	} else if (debug_view_mode == 5) {
		// Mapa de Profundidad 2.5D (Depth-Anything-V2)
		rgb = vec3(nd_sample.a);
	} else if (debug_view_mode == 6) {
		// Mapa ILM (R=Spec, G=ShadowBias/AO, B=RimWeight, A=Emissive en Magenta)
		rgb = has_ilm_mask ? mix(ilm_sample.rgb, vec3(1.0, 0.0, 1.0), ilm_sample.a) : vec3(0.18, 0.18, 0.22);
	}

	if (hit_flash > 0.0) {
		rgb = mix(rgb, srgb_to_linear(vec3(1.0, 0.25, 0.25)), hit_flash);
	}

	float zoom_out_bias = is_head_part ? 0.0 : smoothstep(2.0, 5.5, screen_px_in_texels);
	float alpha_mid = mix(0.50, 0.46, zoom_out_bias);
	float crisp_base_a = mix(smoothstep(max(alpha_mid - aa_a, 0.02), min(alpha_mid + aa_a, 0.98), base.a), base.a, seam_feather_keep);
	float final_alpha = use_part_edge_outline ? part_edge_final_alpha : max(crisp_base_a, centered_outer_alpha);
	COLOR = vec4(rgb, final_alpha * v_modulate_alpha * layer_alpha);
}
