shader_type canvas_item;
render_mode blend_mix;

#include "res://scenes/pilots/shaders/rig_color_recolor.gdshaderinc"
#include "res://scenes/pilots/shaders/rig_perspective_25d.gdshaderinc"
#include "res://scenes/pilots/shaders/rig_stylized_lighting.gdshaderinc"
#include "res://scenes/pilots/shaders/rig_face_live.gdshaderinc"

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

uniform sampler2D id_mask_tex : hint_default_black, filter_linear;

// Estilizado Definitivo Unificado (ArcSys × Espacial Cinematográfico)
uniform bool stylize_enabled = false;
uniform float cel_strength : hint_range(0.0, 1.0) = 0.0;
uniform float cel_threshold : hint_range(-0.6, 0.6) = 0.05;
uniform float cel_softness : hint_range(0.005, 0.25) = 0.038;
uniform float cel_mid_band_strength : hint_range(0.0, 1.0) = 0.42;
uniform float albedo_de_shade : hint_range(0.0, 1.0) = 0.34;
uniform float ilm_shadow_bias_strength : hint_range(0.0, 1.0) = 0.74;
uniform float ilm_ao_strength : hint_range(0.0, 1.0) = 0.82;
uniform float face_shadow_protect : hint_range(0.0, 1.0) = 0.88;

uniform vec4 key_light_tint : source_color = vec4(1.05, 1.02, 0.96, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.180, 0.169, 0.361, 1.0);
uniform vec4 ao_tint : source_color = vec4(0.098, 0.078, 0.196, 1.0);
uniform vec4 skin_shadow_tint : source_color = vec4(0.68, 0.43, 0.50, 1.0);
uniform vec4 sss_skin_color : source_color = vec4(0.97, 0.37, 0.30, 1.0);
uniform float sss_strength : hint_range(0.0, 1.5) = 0.0;
uniform float color_contrast : hint_range(0.7, 1.6) = 1.0;
uniform float color_saturation : hint_range(0.5, 1.8) = 1.0;
uniform float key_light_boost : hint_range(0.8, 1.5) = 1.0;

uniform float armor_spec_strength : hint_range(0.0, 2.0) = 0.0;
uniform float armor_spec_threshold : hint_range(0.25, 0.95) = 0.65;
uniform float suit_satin_strength : hint_range(0.0, 1.5) = 0.0;
uniform float nylon_sheen_strength : hint_range(0.0, 1.5) = 0.0;
uniform float hair_angel_ring_strength : hint_range(0.0, 2.0) = 0.0;
uniform float emissive_glow_strength : hint_range(0.0, 3.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.6;

uniform float ink_strength : hint_range(0.0, 1.0) = 0.0;
uniform float albedo_lod_bias_offset : hint_range(-1.5, 0.5) = 0.0;
uniform float ink_color_tint_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ink_skin_tint : source_color = vec4(0.24, 0.11, 0.12, 1.0);
uniform vec4 ink_cool_tint : source_color = vec4(0.055, 0.055, 0.130, 1.0);
uniform sampler2D ink_sdf_tex : hint_default_white, filter_linear;
uniform bool has_ink_sdf = false;
uniform float ink_sdf_bias_px : hint_range(-1.5, 2.0) = 0.15;
uniform float ink_sdf_softness : hint_range(0.2, 2.0) = 0.90;

uniform float normal_rim_strength : hint_range(0.0, 2.5) = 0.0;
uniform float counter_rim_strength : hint_range(0.0, 1.5) = 0.0;
uniform vec4 rim_key_color : source_color = vec4(0.94, 0.97, 1.0, 1.0);
uniform bool counter_rim_use_skin_accent = true;
uniform vec4 counter_rim_override_color : source_color = vec4(0.86, 0.18, 0.32, 1.0);

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
uniform vec2 secondary_jiggle_b_px = vec2(0.0, 0.0);
uniform float secondary_jiggle_normal_strength : hint_range(0.0, 0.35) = 0.0;

// Rig Facial Vivo Opt-In (face_lab/)
uniform bool enable_face_live = false;
uniform sampler2D face_live_mask_tex : hint_default_black, filter_linear;
uniform vec2 neck_pivot_uv = vec2(0.5, 0.72);
uniform float face_neck_weld_strength : hint_range(0.0, 1.0) = 1.0;
uniform float face_neck_rot_rad = 0.0;
uniform vec2 face_neck_shift_px = vec2(0.0, 0.0);
uniform vec2 face_eye_look_px = vec2(0.0, 0.0);
uniform float face_blink : hint_range(0.0, 1.0) = 0.0;
uniform float face_squint : hint_range(0.0, 1.0) = 0.0;
uniform float face_brow_offset_px = 0.0;
uniform float face_brow_tilt = 0.0;
uniform float face_mouth_open : hint_range(0.0, 1.0) = 0.0;
uniform float face_mouth_smile : hint_range(-1.0, 1.0) = 0.0;
uniform float face_monocle_hud_strength : hint_range(0.0, 1.5) = 0.0;
uniform float face_monocle_activity : hint_range(0.0, 1.5) = 0.0;
uniform float face_parallax_pivot : hint_range(0.2, 0.85) = 0.60;
uniform float face_chin_shadow_strength : hint_range(0.0, 1.5) = 0.45;
uniform bool has_eye_live2d_assets = false;
uniform sampler2D eye_iris_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform sampler2D eye_closed_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform vec2 eye_center_uv = vec2(0.35, 0.47);
uniform vec2 eye_iris_size_uv = vec2(0.065, 0.058);
uniform vec4 eye_patch_rect_uv = vec4(0.22, 0.35, 0.26, 0.22);
uniform float face_iris_scale : hint_range(0.70, 1.30) = 1.0;
uniform float face_eye_highlight_strength : hint_range(0.0, 1.5) = 0.85;
uniform float face_eye_lid_shadow_strength : hint_range(0.0, 1.5) = 0.72;
uniform float face_eye_far_clarity : hint_range(0.0, 1.0) = 0.90;
uniform float face_eye_combat_glow : hint_range(0.0, 1.5) = 0.0;

uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;

// Controles Finos de Curva de Recoloreo y Medias (Sección 2 - Recolor)
uniform float recolor_contrast : hint_range(0.4, 2.2) = 1.0;
uniform float recolor_highlight : hint_range(0.0, 2.0) = 1.0;
uniform float recolor_saturation : hint_range(0.0, 2.0) = 1.0;
uniform float stocking_tint_strength : hint_range(0.0, 1.0) = 0.28;

// Controles Finos de Cabello (Sección 4 - Pelo)
uniform float hair_effect_strength : hint_range(0.0, 1.0) = 0.90;
uniform float hair_cut_height : hint_range(0.05, 0.85) = 0.42;
uniform float hair_cut_softness : hint_range(0.01, 0.40) = 0.14;

// Inspector Rayos-X (0=Final, 1=Clown-Pass ID, 2=Luminancia, 3=Solo Tinta, 4=Normales 2.5D, 5=Profundidad 2.5D, 6=ILM Mask, 7=Face Live, 8=Hair 3-Zone)
uniform int debug_view_mode : hint_range(0, 8) = 0;

// Máscara ILM (ArcSys / Guilty Gear: R=Spec, G=ShadowBias/AO, B=RimWeight, A=Emissive)
uniform sampler2D ilm_mask_tex : hint_default_white, filter_linear_mipmap;
uniform bool has_ilm_mask = false;

// Pipeline 2.5D Normal + Depth + HDR
uniform sampler2D normal_depth_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D conic_rim_lut : source_color, hint_default_white, filter_linear;
uniform float q_time = 0.0;
uniform bool use_normal_depth = false;
uniform vec2 light_dir_2d = vec2(-0.58, -0.81);
uniform float normal_flip_x = 1.0;
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
uniform bool enable_inward_outline = false;
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

// Paquete Oclusivo Fase 1: Normales cilíndricas RNM, Sombras ILM, Mignola y Nylon
uniform vec2 bone_chain_angles = vec2(0.0, 0.0);
uniform float cylinder_roundness : hint_range(0.0, 1.0) = 0.78;
uniform bool weld_top_seam = false;
uniform bool weld_bottom_seam = false;
uniform float leg_depth_phase : hint_range(-1.0, 1.0) = 0.0;
uniform float stocking_denier : hint_range(0.0, 1.0) = 0.34;
uniform float light_z_tilt : hint_range(0.1, 2.0) = 0.58;
uniform float receiver_height_scale : hint_range(0.0, 40.0) = 18.0;
uniform vec4 caster_capsule_ab = vec4(0.0, -900.0, 0.0, -900.0);
uniform vec2 caster_capsule_radius_height = vec2(0.0, 0.0);
uniform vec4 caster_head_ellipse = vec4(0.0, -900.0, 1.0, 1.0);
uniform float caster_head_height = 0.0;
uniform vec4 deep_mignola_ink : source_color = vec4(0.015, 0.015, 0.025, 1.0);
uniform float fold_inner_side = 1.0;
uniform float joint_v_coord : hint_range(0.0, 1.0) = 0.5;
uniform float joint_flexion : hint_range(0.0, 1.0) = 0.0;

// Muestreo morfológico de alfa inlined en fragment() para evitar pasar TEXTURE como sampler2D (error Vulkan custom_samplers).

void fragment() {
	vec2 sample_uv = UV;
	vec2 tex_coord_px = UV / TEXTURE_PIXEL_SIZE;
	vec2 uv_dx = dFdx(sample_uv);
	vec2 uv_dy = dFdy(sample_uv);
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

	vec2 active_jiggle_px = vec2(0.0);
	if (enable_secondary_jiggle && (dot(secondary_jiggle_l_px, secondary_jiggle_l_px) > 0.0001 || dot(secondary_jiggle_r_px, secondary_jiggle_r_px) > 0.0001 || dot(secondary_jiggle_b_px, secondary_jiggle_b_px) > 0.0001)) {
		vec3 sec_m = texture(secondary_jiggle_mask_tex, sample_uv).rgb;
		active_jiggle_px = secondary_jiggle_l_px * sec_m.r + secondary_jiggle_r_px * sec_m.g + secondary_jiggle_b_px * sec_m.b;
		vec2 jiggle_uv = active_jiggle_px * TEXTURE_PIXEL_SIZE;
		sample_uv = clamp(sample_uv - jiggle_uv, vec2(0.001), vec2(0.999));
	}

	if (is_head_part && enable_face_live) {
		vec4 flm_weld = textureLod(face_live_mask_tex, sample_uv, 0.0);
		float pre_collar = smoothstep(0.42, 0.58, textureLod(id_mask_tex, sample_uv, 0.0).b);
		float weld_w = pre_collar * flm_weld.a * face_neck_weld_strength;
		sample_uv = apply_neck_weld_uv(sample_uv, TEXTURE_PIXEL_SIZE, neck_pivot_uv, weld_w, face_neck_rot_rad, face_neck_shift_px);
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
		float quad_guard = smoothstep(0.01, 0.04, min(min(sample_uv.x, 1.0 - sample_uv.x), min(sample_uv.y, 1.0 - sample_uv.y)));
		float eff_edge_w = (is_head_part && enable_face_live) ? quad_guard : parallax_edge_w;
		if (dot(total_tilt, total_tilt) > 0.0001 && px_mul > 0.01 && eff_edge_w > 0.001) {
			float depth_piv = (is_head_part && enable_face_live) ? face_parallax_pivot : 0.45;
			vec2 parallax_uv = clamp(
				sample_uv - total_tilt * (nd_sample.a - depth_piv) * px_mul * eff_edge_w * TEXTURE_PIXEL_SIZE,
				vec2(0.001),
				vec2(0.999)
			);
			if (is_head_part && enable_face_live) {
				sample_uv = mix(sample_uv, parallax_uv, eff_edge_w);
				nd_sample = texture(normal_depth_tex, sample_uv);
			} else {
				vec4 p_base = texture(TEXTURE, parallax_uv);
				if (p_base.a > 0.28) {
					sample_uv = mix(sample_uv, parallax_uv, parallax_edge_w);
					nd_sample = texture(normal_depth_tex, sample_uv);
				}
			}
		}
	}

	vec4 face_flm = vec4(0.0);
	float face_mouth_core = 0.0;
	if (is_head_part && enable_face_live) {
		face_flm = textureLod(face_live_mask_tex, sample_uv, 0.0);
		float pre_collar_f = smoothstep(0.42, 0.58, textureLod(id_mask_tex, sample_uv, 0.0).b);
		sample_uv = apply_face_feature_warp_uv(
			sample_uv,
			TEXTURE_PIXEL_SIZE,
			face_flm,
			pre_collar_f,
			face_brow_offset_px,
			face_brow_tilt,
			face_mouth_smile,
			face_mouth_open,
			face_mouth_core
		);
	}

	vec2 albedo_uv = (persp_mode > 0) ? vec2(sample_uv.x, clamp(sample_uv.y + v_uv_relief_shift, 0.001, 0.999)) : sample_uv;
	float albedo_lod_bias = ((persp_mode > 0) ? log2(clamp(v_comp_ratio, 0.25, 1.0)) : 0.0) + albedo_lod_bias_offset;
	vec4 base = (abs(albedo_lod_bias) > 0.01) ? texture(TEXTURE, albedo_uv, albedo_lod_bias) : texture(TEXTURE, albedo_uv);
	if (abs(albedo_lod_bias) > 0.01) {
		base.a = texture(TEXTURE, albedo_uv).a;
	}
	bool valid_nd = use_normal_depth && (dot(nd_sample.rgb, nd_sample.rgb) > 0.01);
	vec3 n_cyl_local = vec3(0.0, 0.0, 1.0);
	vec3 n25 = vec3(0.0, 0.0, 1.0);
	float ndl = 0.5;
	vec2 l2d = length(light_dir_2d) > 0.001 ? normalize(light_dir_2d) : vec2(-0.58, -0.81);
	vec3 l3 = normalize(vec3(l2d, light_z_tilt));
	float open_bridge = (!is_head_part && weld_top_seam)
		? (1.0 - smoothstep(0.02, 0.18, sample_uv.y)) * smoothstep(0.46, 0.24, abs(sample_uv.x - 0.5))
		: 0.0;
	if (valid_nd) {
		if (is_head_part) {
			n_cyl_local = normalize(nd_sample.rgb * 2.0 - vec3(1.0));
			n_cyl_local.x *= normal_flip_x;
			n_cyl_local.y = -n_cyl_local.y;
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
		if ((!is_head_part || enable_face_live) && secondary_jiggle_normal_strength > 0.0001 && dot(active_jiggle_px, active_jiggle_px) > 0.0001) {
			vec2 j_tilt = clamp(active_jiggle_px * secondary_jiggle_normal_strength, vec2(-0.26), vec2(0.26));
			n25 = normalize(vec3(n25.x + j_tilt.x * 0.65, n25.y + j_tilt.y, n25.z));
		}
		ndl = dot(n25, l3);
	}
	vec4 raw_mask = textureLod(id_mask_tex, sample_uv, 0.0);
	float w_r = raw_mask.r;
	float w_g = raw_mask.g;
	float w_b = raw_mask.b;
	float w_a = (is_head_part || is_leg_part) ? raw_mask.a : 0.0;
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
	float is_collar_blue = is_head_part ? smoothstep(0.42, 0.58, raw_mask.b) : 0.0;
	if (is_head_part) {
		// En cabezas nuevas, el canal azul marca el cuello de piel para dividir capas (Pass 1 bajo torso vs Pass 2 sobre torso), no traje oscuro.
		mask.b = 0.0;
	}

	bool use_part_edge_outline = enable_part_edge_outline && (part_edge_erode_du > 0.001 || part_edge_outline_du > 0.001);
	float part_edge_fill_a = base.a;
	float part_edge_total_a = base.a;
	if (use_part_edge_outline) {
		vec2 du_to_uv = 1.0 / max(part_rig_rect.zw * 490.0, vec2(1.0));
		float r_outer_du = part_edge_erode_du - part_edge_outline_du;
		if (abs(r_outer_du) > 0.001) {
			bool is_erode_o = (r_outer_du > 0.0);
			float abs_ro = abs(r_outer_du);
			vec2 rad_uv_o = du_to_uv * abs_ro;
			float acc_o = base.a;
			for (int i = 0; i < 16; i++) {
				float ang = float(i) * 0.3926990817;
				vec2 suv = sample_uv + vec2(cos(ang), sin(ang)) * rad_uv_o;
				float a = (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) ? 0.0 : textureLod(TEXTURE, suv, 0.0).a;
				acc_o = is_erode_o ? min(acc_o, a) : max(acc_o, a);
			}
			if (abs_ro > 0.75) {
				vec2 mid_uv_o = rad_uv_o * 0.55;
				for (int j = 0; j < 8; j++) {
					float ang = float(j) * 0.7853981634 + 0.1963495408;
					vec2 suv = sample_uv + vec2(cos(ang), sin(ang)) * mid_uv_o;
					float a = (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) ? 0.0 : textureLod(TEXTURE, suv, 0.0).a;
					acc_o = is_erode_o ? min(acc_o, a) : max(acc_o, a);
				}
			}
			if (abs_ro > 2.2) {
				vec2 in_uv_o = rad_uv_o * 0.28;
				for (int k = 0; k < 8; k++) {
					float ang = float(k) * 0.7853981634;
					vec2 suv = sample_uv + vec2(cos(ang), sin(ang)) * in_uv_o;
					float a = (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) ? 0.0 : textureLod(TEXTURE, suv, 0.0).a;
					acc_o = is_erode_o ? min(acc_o, a) : max(acc_o, a);
				}
			}
			part_edge_total_a = acc_o;
		}
		if (part_edge_total_a < 0.02) {
			discard;
		}
		if (part_edge_erode_du > 0.001) {
			if (base.a < 0.02) {
				part_edge_fill_a = 0.0;
			} else {
				float abs_re = part_edge_erode_du;
				vec2 rad_uv_e = du_to_uv * abs_re;
				float acc_e = base.a;
				for (int i = 0; i < 16; i++) {
					float ang = float(i) * 0.3926990817;
					vec2 suv = sample_uv + vec2(cos(ang), sin(ang)) * rad_uv_e;
					float a = (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) ? 0.0 : textureLod(TEXTURE, suv, 0.0).a;
					acc_e = min(acc_e, a);
				}
				if (abs_re > 0.75) {
					vec2 mid_uv_e = rad_uv_e * 0.55;
					for (int j = 0; j < 8; j++) {
						float ang = float(j) * 0.7853981634 + 0.1963495408;
						vec2 suv = sample_uv + vec2(cos(ang), sin(ang)) * mid_uv_e;
						float a = (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) ? 0.0 : textureLod(TEXTURE, suv, 0.0).a;
						acc_e = min(acc_e, a);
					}
				}
				if (abs_re > 2.2) {
					vec2 in_uv_e = rad_uv_e * 0.28;
					for (int k = 0; k < 8; k++) {
						float ang = float(k) * 0.7853981634;
						vec2 suv = sample_uv + vec2(cos(ang), sin(ang)) * in_uv_e;
						float a = (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) ? 0.0 : textureLod(TEXTURE, suv, 0.0).a;
						acc_e = min(acc_e, a);
					}
				}
				part_edge_fill_a = acc_e;
			}
		}
	} else if (base.a < 0.02) {
		discard;
	}

	vec3 rgb = base.rgb;
	vec3 srgb_base = linear_to_srgb(max(base.rgb, vec3(0.0)));
	float orig_luma = dot(srgb_base, vec3(0.299, 0.587, 0.114));
	float luma_lod0 = orig_luma;
	if (screen_px_in_texels <= 1.65) {
		vec4 base_lod0 = textureLod(TEXTURE, albedo_uv, 0.0);
		vec3 srgb_lod0 = linear_to_srgb(max(base_lod0.rgb, vec3(0.0)));
		luma_lod0 = dot(srgb_lod0, vec3(0.299, 0.587, 0.114));
	} else {
		float l_foot = clamp(screen_px_in_texels * 0.36, 0.6, 2.2);
		vec2 l_rgss[4] = vec2[4](
			vec2(-0.35, -0.85), vec2(0.85, -0.35),
			vec2(0.35, 0.85), vec2(-0.85, 0.35)
		);
		float l_acc = 0.0;
		float w_acc = 0.0;
		for (int li = 0; li < 4; li++) {
			vec2 luv = clamp(albedo_uv + l_rgss[li] * l_foot * TEXTURE_PIXEL_SIZE, vec2(0.0), vec2(1.0));
			vec4 lt = textureLod(TEXTURE, luv, 0.0);
			if (lt.a > 0.20) {
				vec3 ls = linear_to_srgb(max(lt.rgb, vec3(0.0)));
				l_acc += dot(ls, vec3(0.299, 0.587, 0.114));
				w_acc += 1.0;
			}
		}
		luma_lod0 = (w_acc > 0.5) ? (l_acc / w_acc) : orig_luma;
	}
	float dark_luma = min(orig_luma, mix(orig_luma, luma_lod0, 0.85));

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
	if (is_head_part && head_layer_pass > 0) {
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

	// 3.8 Máscara SDF Analítica de Tinta (compartida entre recoloreo, cel y line art interno)
	float sdf_ink_line = 0.0;
	if (has_ink_sdf) {
		float eff_tex_per_px = clamp(screen_px_in_texels, 1.0, 1.65);
		float bias_px = clamp(ink_sdf_bias_px, -0.35, 0.15);
		float aa_px = clamp(0.45 * ink_sdf_softness, 0.15, 0.65);
		if (screen_px_in_texels <= 1.65) {
			float sdf_tex = (textureLod(ink_sdf_tex, sample_uv, 0.0).r - 0.5) * 16.0;
			float sdf_norm = sdf_tex / eff_tex_per_px;
			sdf_ink_line = 1.0 - smoothstep(-aa_px + bias_px, aa_px + bias_px, sdf_norm);
		} else {
			float s_foot = clamp(screen_px_in_texels * 0.36, 0.6, 2.2);
			vec2 s_rgss[4] = vec2[4](
				vec2(-0.35, -0.85), vec2(0.85, -0.35),
				vec2(0.35, 0.85), vec2(-0.85, 0.35)
			);
			float cov_sum = 0.0;
			for (int si = 0; si < 4; si++) {
				vec2 suv = clamp(sample_uv + s_rgss[si] * s_foot * TEXTURE_PIXEL_SIZE, vec2(0.0), vec2(1.0));
				float stex = (textureLod(ink_sdf_tex, suv, 0.0).r - 0.5) * 16.0;
				float snorm = stex / eff_tex_per_px;
				cov_sum += 1.0 - smoothstep(-aa_px + bias_px, aa_px + bias_px, snorm);
			}
			sdf_ink_line = cov_sum * 0.25;
		}
	}
	float face_lid_ink = 0.0;
	float face_eye_spec = 0.0;
	float face_eye_emit = 0.0;
	float face_eye_open_mask = 0.0;
	if (is_head_part && enable_face_live) {
		float close_eff = clamp(max(face_blink, face_squint * 0.70), 0.0, 1.0);
		vec2 above_uv = sample_uv;
		vec4 above_flm = face_flm;
		if (max(face_flm.g, face_flm.r) > 0.10 && close_eff > 0.005) {
			above_uv = clamp(sample_uv - vec2(0.0, close_eff * 15.0) * TEXTURE_PIXEL_SIZE, vec2(0.001), vec2(0.999));
			above_flm = textureLod(face_live_mask_tex, above_uv, 0.0);
		}
		if (has_eye_live2d_assets) {
			float eye_far_w = smoothstep(1.35, 3.80, screen_px_in_texels) * face_eye_far_clarity;
			vec2 eye_shift_uv = face_eye_look_px * TEXTURE_PIXEL_SIZE;
			float eff_iris_scale = face_iris_scale * mix(1.0, 1.05, eye_far_w);
			vec2 iris_uv_span = max(eye_iris_size_uv * eff_iris_scale, vec2(0.0001));
			vec2 iris_local_uv = (sample_uv - (eye_center_uv + eye_shift_uv)) / iris_uv_span + vec2(0.5);
			bool in_iris_bounds = (iris_local_uv.x >= 0.0 && iris_local_uv.x <= 1.0 && iris_local_uv.y >= 0.0 && iris_local_uv.y <= 1.0);
			vec4 eye_iris_s = textureLod(eye_iris_tex, clamp(iris_local_uv, vec2(0.0), vec2(1.0)), 0.0);
			if (in_iris_bounds && eye_far_w > 0.01) {
				vec2 iddx = clamp(uv_dx / iris_uv_span, vec2(-0.09), vec2(0.09));
				vec2 iddy = clamp(uv_dy / iris_uv_span, vec2(-0.09), vec2(0.09));
				vec4 t0 = textureLod(eye_iris_tex, clamp(iris_local_uv + iddx * 0.26 + iddy * 0.10, vec2(0.0), vec2(1.0)), 0.0);
				vec4 t1 = textureLod(eye_iris_tex, clamp(iris_local_uv - iddx * 0.26 - iddy * 0.10, vec2(0.0), vec2(1.0)), 0.0);
				vec4 t2 = textureLod(eye_iris_tex, clamp(iris_local_uv - iddx * 0.10 + iddy * 0.26, vec2(0.0), vec2(1.0)), 0.0);
				vec4 t3 = textureLod(eye_iris_tex, clamp(iris_local_uv + iddx * 0.10 - iddy * 0.26, vec2(0.0), vec2(1.0)), 0.0);
				vec4 rgss_avg = (eye_iris_s + t0 + t1 + t2 + t3) * 0.2;
				vec4 dark_pick = eye_iris_s;
				float min_v = mix(1.0, max(eye_iris_s.r, max(eye_iris_s.g, eye_iris_s.b)), step(0.35, eye_iris_s.a));
				float v0 = mix(1.0, max(t0.r, max(t0.g, t0.b)), step(0.35, t0.a));
				if (v0 < min_v) { min_v = v0; dark_pick = t0; }
				float v1 = mix(1.0, max(t1.r, max(t1.g, t1.b)), step(0.35, t1.a));
				if (v1 < min_v) { min_v = v1; dark_pick = t1; }
				float v2 = mix(1.0, max(t2.r, max(t2.g, t2.b)), step(0.35, t2.a));
				if (v2 < min_v) { min_v = v2; dark_pick = t2; }
				float v3 = mix(1.0, max(t3.r, max(t3.g, t3.b)), step(0.35, t3.a));
				if (v3 < min_v) { min_v = v3; dark_pick = t3; }
				float pupil_core_zone = (1.0 - smoothstep(0.09, 0.21, abs(iris_local_uv.x - 0.50))) * (1.0 - smoothstep(0.24, 0.36, abs(iris_local_uv.y - 0.50)));
				float dark_hit = (1.0 - smoothstep(0.015, 0.068, min_v)) * pupil_core_zone;
				vec4 rgss_preserved = mix(rgss_avg, dark_pick, dark_hit * 0.58);
				rgss_preserved.a = max(rgss_avg.a, dark_pick.a * dark_hit);
				eye_iris_s = mix(eye_iris_s, rgss_preserved, clamp(eye_far_w, 0.0, 1.0));
			}
			eye_iris_s.a *= (in_iris_bounds ? 1.0 : 0.0);

			vec3 above_lid_rgb = rgb;
			float above_lid_sdf = sdf_ink_line;
			if (max(face_flm.g, face_flm.r) > 0.10 && (close_eff > 0.005 || eye_far_w > 0.01)) {
				above_lid_rgb = textureLod(TEXTURE, above_uv, 0.0).rgb;
				if (has_ink_sdf) {
					float a_sdf_tex = (textureLod(ink_sdf_tex, above_uv, 0.0).r - 0.5) * 16.0;
					float a_eff_tpp = clamp(screen_px_in_texels, 1.0, 1.65);
					float a_bias = clamp(ink_sdf_bias_px, -0.35, 0.15);
					float a_aa = clamp(0.45 * ink_sdf_softness, 0.15, 0.65);
					above_lid_sdf = 1.0 - smoothstep(-a_aa + a_bias, a_aa + a_bias, a_sdf_tex / a_eff_tpp);
				}
				if (eye_far_w > 0.01) {
					float lash_step_tex = clamp(screen_px_in_texels * 0.30, 0.5, 1.4);
					vec2 lash_dy = vec2(0.0, lash_step_tex) * TEXTURE_PIXEL_SIZE;
					vec2 uv_u = clamp(above_uv - lash_dy, vec2(0.001), vec2(0.999));
					vec2 uv_d = clamp(above_uv + lash_dy, vec2(0.001), vec2(0.999));
					vec3 lu = textureLod(TEXTURE, uv_u, 0.0).rgb;
					vec3 ld = textureLod(TEXTURE, uv_d, 0.0).rgb;
					vec4 fu = textureLod(face_live_mask_tex, uv_u, 0.0);
					vec4 fd = textureLod(face_live_mask_tex, uv_d, 0.0);
					float w_ru = smoothstep(0.15, 0.50, fu.r) * (1.0 - smoothstep(0.15, 0.50, fu.g));
					float w_rd = smoothstep(0.15, 0.50, fd.r) * (1.0 - smoothstep(0.15, 0.50, fd.g));
					vec3 darkest_lash = above_lid_rgb;
					float min_lv = max(darkest_lash.r, max(darkest_lash.g, darkest_lash.b));
					if (w_ru > 0.35) {
						float v_u = max(lu.r, max(lu.g, lu.b));
						if (v_u < min_lv) { min_lv = v_u; darkest_lash = lu; }
					}
					if (w_rd > 0.35) {
						float v_d = max(ld.r, max(ld.g, ld.b));
						if (v_d < min_lv) { min_lv = v_d; darkest_lash = ld; }
					}
					float lash_dark_hit = (1.0 - smoothstep(0.015, 0.095, min_lv)) * smoothstep(0.08, 0.45, above_flm.r) * (1.0 - smoothstep(0.15, 0.50, above_flm.g));
					above_lid_rgb = mix(above_lid_rgb, darkest_lash, lash_dark_hit * eye_far_w * 0.72);
					above_lid_sdf = max(above_lid_sdf, lash_dark_hit * eye_far_w * 0.85);
				}
			}

			vec2 patch_local_uv = (sample_uv - eye_patch_rect_uv.xy) / max(eye_patch_rect_uv.zw, vec2(0.0001));
			bool in_patch_bounds = (patch_local_uv.x >= 0.0 && patch_local_uv.x <= 1.0 && patch_local_uv.y >= 0.0 && patch_local_uv.y <= 1.0);
			vec4 eye_closed_s = vec4(0.0);
			if (in_patch_bounds && close_eff > 0.55) {
				vec2 p_clamped = clamp(patch_local_uv, vec2(0.0), vec2(1.0));
				eye_closed_s = textureLod(eye_closed_tex, p_clamped, 0.0);
				vec2 pddx = clamp(uv_dx / max(eye_patch_rect_uv.zw, vec2(0.0001)), vec2(-0.045), vec2(0.045));
				vec2 pddy = clamp(uv_dy / max(eye_patch_rect_uv.zw, vec2(0.0001)), vec2(-0.045), vec2(0.045));
				vec4 c0 = textureLod(eye_closed_tex, clamp(p_clamped + pddx * 0.28 + pddy * 0.12, vec2(0.0), vec2(1.0)), 0.0);
				vec4 c1 = textureLod(eye_closed_tex, clamp(p_clamped - pddx * 0.28 - pddy * 0.12, vec2(0.0), vec2(1.0)), 0.0);
				vec4 c2 = textureLod(eye_closed_tex, clamp(p_clamped - pddx * 0.12 + pddy * 0.28, vec2(0.0), vec2(1.0)), 0.0);
				vec4 c3 = textureLod(eye_closed_tex, clamp(p_clamped + pddx * 0.12 - pddy * 0.28, vec2(0.0), vec2(1.0)), 0.0);
				vec4 c_avg = (eye_closed_s + c0 + c1 + c2 + c3) * 0.2;
				vec4 c_dark = eye_closed_s;
				float c_min = mix(1.0, max(eye_closed_s.r, max(eye_closed_s.g, eye_closed_s.b)), step(0.45, eye_closed_s.a));
				float cv0 = mix(1.0, max(c0.r, max(c0.g, c0.b)), step(0.45, c0.a));
				if (cv0 < c_min) { c_min = cv0; c_dark = c0; }
				float cv1 = mix(1.0, max(c1.r, max(c1.g, c1.b)), step(0.45, c1.a));
				if (cv1 < c_min) { c_min = cv1; c_dark = c1; }
				float cv2 = mix(1.0, max(c2.r, max(c2.g, c2.b)), step(0.45, c2.a));
				if (cv2 < c_min) { c_min = cv2; c_dark = c2; }
				float cv3 = mix(1.0, max(c3.r, max(c3.g, c3.b)), step(0.45, c3.a));
				if (cv3 < c_min) { c_min = cv3; c_dark = c3; }
				float c_lash_hit = 1.0 - smoothstep(0.015, 0.11, c_min);
				vec4 c_preserved = mix(c_avg, c_dark, c_lash_hit * mix(0.25, 0.82, clamp(eye_far_w, 0.0, 1.0)));
				c_preserved.a = max(c_avg.a, c_dark.a * c_lash_hit);
				eye_closed_s = c_preserved;
			}

			vec2 upper_lid_patch_uv = vec2(clamp(patch_local_uv.x, 0.0, 1.0), clamp(min(patch_local_uv.y, 0.44), 0.02, 0.98));
			vec4 lid_skin_patch_s = textureLod(eye_closed_tex, upper_lid_patch_uv, 1.0);
			lid_skin_patch_s.a *= (in_patch_bounds ? 1.0 : 0.0);

			float lid_sh_far_g = textureLod(face_live_mask_tex, clamp(above_uv - vec2(0.0, 3.8) * TEXTURE_PIXEL_SIZE, vec2(0.001), vec2(0.999)), 0.0).g;
			float lid_sh_near_g = textureLod(face_live_mask_tex, clamp(above_uv - vec2(0.0, 1.9) * TEXTURE_PIXEL_SIZE, vec2(0.001), vec2(0.999)), 0.0).g;

			rgb = apply_live_eyes_v2_and_mouth_color(
				rgb,
				face_flm,
				is_collar_blue,
				face_eye_look_px,
				l2d,
				iris_local_uv,
				eye_iris_s,
				eye_closed_s,
				lid_skin_patch_s,
				lid_sh_far_g,
				lid_sh_near_g,
				face_eye_lid_shadow_strength,
				eye_far_w,
				face_blink,
				face_squint,
				above_flm,
				above_lid_rgb,
				above_lid_sdf,
				face_mouth_open,
				face_mouth_core,
				sdf_ink_line,
				dark_luma,
				face_lid_ink,
				face_eye_spec,
				face_eye_emit
			);
			if (max(max(face_flm.g, face_flm.r), max(eye_closed_s.a * step(0.01, close_eff), face_mouth_core)) > 0.08) {
				orig_luma = dark_luma;
			}
			float live_lid_zone = smoothstep(0.10, 0.46, max(face_flm.g, face_flm.r));
			float live_lid_cover = (close_eff > 0.005) ? ((1.0 - smoothstep(0.10, 0.50, above_flm.g)) * live_lid_zone) : 0.0;
			float live_closed_mix = smoothstep(0.62, 0.94, close_eff);
			face_eye_open_mask = smoothstep(0.14, 0.56, face_flm.g) * (1.0 - is_collar_blue) * (1.0 - clamp(max(live_lid_cover, live_closed_mix), 0.0, 1.0));
		} else {
			vec3 iris_src_rgb = rgb;
			vec4 iris_src_flm = face_flm;
			float iris_src_sdf = 0.5;
			if (face_flm.g > 0.12 && dot(face_eye_look_px, face_eye_look_px) > 0.0004) {
				vec2 iris_uv = clamp(sample_uv - face_eye_look_px * TEXTURE_PIXEL_SIZE, vec2(0.001), vec2(0.999));
				iris_src_rgb = texture(TEXTURE, iris_uv).rgb;
				iris_src_flm = textureLod(face_live_mask_tex, iris_uv, 0.0);
				if (has_ink_sdf) {
					iris_src_sdf = textureLod(ink_sdf_tex, iris_uv, 0.0).r;
				}
			}
			vec3 lid_skin_raw_rgb = rgb;
			vec4 skin_src_flm = face_flm;
			if (max(face_flm.g, face_flm.r) > 0.12 && close_eff > 0.01) {
				vec2 skin_sample_uv = clamp(sample_uv + vec2(0.0, 10.5) * TEXTURE_PIXEL_SIZE, vec2(0.001), vec2(0.999));
				lid_skin_raw_rgb = texture(TEXTURE, skin_sample_uv).rgb;
				skin_src_flm = textureLod(face_live_mask_tex, skin_sample_uv, 0.0);
			}
			rgb = apply_live_eyes_and_mouth_color(
				rgb,
				face_flm,
				is_collar_blue,
				face_eye_look_px,
				iris_src_rgb,
				iris_src_flm,
				iris_src_sdf,
				has_ink_sdf,
				face_blink,
				face_squint,
				above_flm,
				lid_skin_raw_rgb,
				skin_src_flm,
				face_mouth_open,
				face_mouth_core,
				sdf_ink_line,
				dark_luma,
				face_lid_ink
			);
			if (max(max(face_flm.g, face_flm.r), face_mouth_core) > 0.08) {
				orig_luma = dark_luma;
			}
		}
	} else if (is_head_part && has_eye_live2d_assets) {
		float static_eye_g = textureLod(face_live_mask_tex, sample_uv, 0.0).g;
		float static_eye_w = smoothstep(0.14, 0.56, static_eye_g) * (1.0 - is_collar_blue);
		if (static_eye_w > 0.005) {
			float static_eye_val = max(srgb_base.r, max(srgb_base.g, srgb_base.b));
			dark_luma = mix(dark_luma, static_eye_val, static_eye_w);
			orig_luma = mix(orig_luma, static_eye_val, static_eye_w);
			float static_eye_ink = 1.0 - smoothstep(0.08, 0.22, static_eye_val);
			sdf_ink_line = mix(sdf_ink_line, static_eye_ink, static_eye_w);
			face_eye_open_mask = static_eye_w;
		}
	}
	float edge_alpha_guard = smoothstep(0.65, 0.95, base.a);
	float combined_ink_guard = min(has_ink_sdf ? (1.0 - sdf_ink_line) : 1.0, smoothstep(0.055, 0.165, dark_luma));

	// 4. Recoloreo de Traje, Armadura, Acentos y Medias (Usando `recolor_method` + Luminancia Estabilizada)
	bool need_hair_recolor = is_head_part && mask.a > 0.01 && (enable_shader_recolor || enable_hair_recolor || hair_style_mode > 0);
	float stab_luma = dark_luma;
	if ((enable_shader_recolor || need_hair_recolor) && debug_view_mode == 0) {
		float l_sum = dark_luma * 1.4;
		float w_sum = 1.4;
		vec2 offs[4] = vec2[4](vec2(0.85, 0.0), vec2(-0.85, 0.0), vec2(0.0, 0.85), vec2(0.0, -0.85));
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
				float tone_w = exp(-abs(tl - dark_luma) * 14.0);
				float w = id_sim * not_ink * tone_w;
				l_sum += tl * w;
				w_sum += w;
			}
		}
		float edge_guard = smoothstep(0.06, 0.18, dark_luma) * smoothstep(0.55, 0.90, base.a);
		stab_luma = mix(dark_luma, l_sum / w_sum, 0.35 * edge_guard);
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

		float recolor_ink_keep = combined_ink_guard;
		rgb = mix(rgb, target_suit, mask.b * recolor_ink_keep);
		rgb = mix(rgb, target_panel, mask.g * recolor_ink_keep);
		rgb = mix(rgb, target_acc, mask.r * recolor_ink_keep);

		if (!is_head_part && is_leg_part && mask.a > 0.01) {
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

		float hair_ink_keep = combined_ink_guard;
		rgb = mix(rgb, clamp(base_hair_col, vec3(0.0), vec3(1.0)), mask.a * 0.96 * hair_ink_keep);
	}

	// 6. Pipeline Unificado de Estilizado Definitivo (ArcSys Cel 2.5D + Materiales ID/ILM + Rim + Emisivo HDR + Colored Line Art)
	vec3 abyssal_ink = srgb_to_linear(vec3(0.015, 0.015, 0.025));
	vec4 ilm_sample = has_ilm_mask ? textureLod(ilm_mask_tex, sample_uv, 0.0) : vec4(0.15, 0.5, 1.0, 0.0);
	float ink_protect = combined_ink_guard * edge_alpha_guard;
	float hdr_cap = max(crt_hdr_boost, 1.0);

	if (stylize_enabled && debug_view_mode == 0) {
		float w_hair = is_head_part ? mask.a : 0.0;
		float w_nylon = (!is_head_part) ? mask.a : 0.0;
		float w_armor = mask.g;
		float w_suit = mask.b;
		float w_accent = mask.r;
		float w_skin_clean = clamp(1.0 - (w_accent + w_armor + w_suit + w_hair + w_nylon), 0.0, 1.0);

		float z_rec = (valid_nd ? nd_sample.a : 0.5) * receiver_height_scale;
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
		float face_prot = (is_head_part && has_ilm_mask)
			? smoothstep(0.68, 0.90, ilm_sample.g) * w_skin_clean * face_shadow_protect
			: 0.0;

		float ilm_bias = has_ilm_mask ? (ilm_sample.g - 0.5) * 2.0 * ilm_shadow_bias_strength : 0.0;
		float depth_lift = valid_nd ? (nd_sample.a - 0.5) * 0.22 : 0.0;
		float l_base = valid_nd ? ndl : 0.35;
		float chin_sh = (is_head_part && enable_face_live && is_collar_blue > 0.1)
			? is_collar_blue * (1.0 - face_flm.a) * face_chin_shadow_strength * 0.42
			: 0.0;
		float l_term = l_base + ilm_bias * 0.42 + depth_lift - cast_shadow * 0.48 - back_leg_factor * 0.24 - chin_sh;
		l_term = mix(l_term, max(l_term, cel_threshold + 0.14), open_bridge * 0.65);
		l_term = mix(l_term, max(l_term, cel_threshold + 0.18), face_prot);

		// 6.1 Corte Cel ArcSys de 2 Bandas + Hue-Shift Perceptual sRGB
		float soft = max(cel_softness, 0.005);
		float lit_mask = smoothstep(cel_threshold - soft, cel_threshold + soft, l_term);
		float mid_mask = smoothstep((cel_threshold - 0.36) - soft * 1.4, (cel_threshold - 0.36) + soft * 1.4, l_term);
		float shadow_w = (1.0 - lit_mask) * mix(1.0, mix(1.0, 0.58, mid_mask), cel_mid_band_strength);

		vec3 col_srgb = linear_to_srgb(max(rgb, vec3(0.0)));
		vec3 sh_tint_srgb = linear_to_srgb(shadow_tint.rgb);
		vec3 hair_sh_tint_srgb = mix(sh_tint_srgb, vec3(0.56, 0.58, 0.78), 0.58);
		vec3 eff_cool_tint_srgb = mix(sh_tint_srgb, hair_sh_tint_srgb, w_hair);
		vec3 sh_cool_srgb = compute_arcsys_shadow_srgb(col_srgb, eff_cool_tint_srgb, albedo_de_shade, orig_luma, false);
		vec3 sh_skin_srgb = compute_arcsys_shadow_srgb(col_srgb, linear_to_srgb(skin_shadow_tint.rgb), albedo_de_shade * 0.65, orig_luma, true);
		vec3 sh_target_srgb = mix(sh_cool_srgb, sh_skin_srgb, w_skin_clean);
		vec3 eye_ambient_sh_srgb = col_srgb * vec3(0.84, 0.85, 0.96);
		sh_target_srgb = mix(sh_target_srgb, eye_ambient_sh_srgb, face_eye_open_mask);
		float hair_sh_scale = mix(1.0, 0.76, w_hair);
		float eye_sh_scale = mix(1.0, 0.35, face_eye_open_mask);
		vec3 shaded_srgb = mix(col_srgb, sh_target_srgb, shadow_w * cel_strength * hair_sh_scale * eye_sh_scale * ink_protect);
		rgb = srgb_to_linear(shaded_srgb);

		// Luz clave en zona iluminada (moderada en piel para proteger el rostro; neutro-frío en pelo plata)
		float lit_boost_w = lit_mask * cel_strength * ink_protect * mix(1.0, 0.25, w_skin_clean);
		vec3 eff_key_tint = mix(key_light_tint.rgb, vec3(1.01, 1.02, 1.05), w_hair * 0.65);
		eff_key_tint = mix(eff_key_tint, vec3(1.01, 1.01, 1.03), face_eye_open_mask * 0.75);
		vec3 lit_rgb = rgb * eff_key_tint * key_light_boost;
		rgb = mix(rgb, lit_rgb, lit_boost_w);

		// Oclusión AO permanente en pliegues (ILM.G < 0.30) en sRGB perceptual para preservar croma abisal
		if (has_ilm_mask && ilm_ao_strength > 0.005) {
			float ao_cov = smoothstep(0.30, 0.08, ilm_sample.g) * ilm_ao_strength * ink_protect * (1.0 - face_eye_open_mask * 0.88);
			vec3 cur_srgb = linear_to_srgb(max(rgb, vec3(0.0)));
			vec3 ao_srgb = linear_to_srgb(ao_tint.rgb);
			vec3 ao_cool_srgb = compute_arcsys_shadow_srgb(cur_srgb, ao_srgb, 0.0, orig_luma, false);
			vec3 ao_skin_srgb = compute_arcsys_shadow_srgb(cur_srgb, mix(linear_to_srgb(skin_shadow_tint.rgb) * 0.78, ao_srgb, 0.20), 0.0, orig_luma, true);
			rgb = mix(rgb, srgb_to_linear(mix(ao_cool_srgb, ao_skin_srgb, w_skin_clean)), ao_cov * mix(0.75, 0.55, w_skin_clean));
		}

		// SSS coral sutil y estrecho en el terminador de piel (nunca quema ni naranja la piel)
		if (sss_strength > 0.005 && w_skin_clean > 0.01) {
			float sss_dist = (l_term - cel_threshold) / max(soft * 1.45, 0.032);
			float sss_band = exp(-sss_dist * sss_dist) * w_skin_clean * (1.0 - face_eye_open_mask) * (1.0 - cast_shadow * 0.65) * (1.0 - face_prot * 0.65) * sss_strength * cel_strength * ink_protect;
			rgb += sss_skin_color.rgb * sss_band * 0.075;
		}

		// 6.2 Firma Diferenciada por Material (ID + ILM + Normal)
		vec3 half_vec = normalize(l3 + vec3(0.0, 0.0, 1.0));
		float ndh = max(dot(n25, half_vec), 0.0);

		if (armor_spec_strength > 0.005 && w_armor > 0.01) {
			float spec_ilm = has_ilm_mask ? smoothstep(0.25, 0.85, ilm_sample.r) : 0.75;
			float spec_curve = pow(ndh, 8.0) * spec_ilm * mix(0.20, 1.0, lit_mask);
			float armor_edge = smoothstep(0.16, 0.54, length(n25.xy)) * (0.35 + 0.65 * lit_mask);
			float thr_p = clamp(armor_spec_threshold, 0.15, 0.95);
			float spec_hi = smoothstep(thr_p - 0.04, thr_p + 0.04, spec_curve);
			float spec_sub = smoothstep(thr_p * 0.45 - 0.06, thr_p * 0.45 + 0.06, spec_curve);
			vec3 steel_col = mix(rgb * 2.2 + vec3(0.055, 0.070, 0.110), key_light_tint.rgb * 0.55, 0.35);
			rgb += steel_col * (spec_hi * 0.24 + spec_sub * 0.08 + armor_edge * 0.10) * armor_spec_strength * w_armor * ink_protect;
		}

		if (suit_satin_strength > 0.005 && w_suit > 0.01) {
			float satin_band = pow(ndh, 5.0) * mix(0.20, 1.0, lit_mask);
			rgb += (rgb * 1.2 + vec3(0.035, 0.040, 0.065)) * satin_band * suit_satin_strength * 0.24 * w_suit * ink_protect;
		}

		if (w_nylon > 0.01 && nylon_sheen_strength > 0.005) {
			float mu = clamp(n_cyl_local.z, 0.0, 1.0);
			float sheer = pow(mu, 1.85) * (1.0 - stocking_denier);
			vec3 warm_under = mix(rgb, rgb * vec3(1.22, 0.96, 0.90) + vec3(0.08, 0.04, 0.035), 0.50);
			rgb = mix(rgb, warm_under, sheer * 0.28 * nylon_sheen_strength * w_nylon * ink_protect);
			float aniso_spec = smoothstep(0.16, 0.04, abs(n_cyl_local.x - l2d.x * 0.35)) * step(0.72, mu) * smoothstep(0.20, 0.65, lit_mask);
			rgb += key_light_tint.rgb * (aniso_spec * 0.14 * nylon_sheen_strength * w_nylon * ink_protect);
		}

		if (hair_angel_ring_strength > 0.005 && w_hair > 0.01) {
			float ilm_ring = has_ilm_mask ? smoothstep(0.30, 0.72, ilm_sample.r) : 0.0;
			float crown_band = exp(-pow((n25.y + 0.24) / 0.16, 2.0)) * smoothstep(0.76, 0.92, ndh);
			float ring_sig = max(ilm_ring, crown_band);
			float ring_mask = smoothstep(0.38, 0.56, ring_sig) * mix(0.25, 1.0, lit_mask);
			vec3 ring_col = mix(rgb * 1.35, vec3(0.95, 0.97, 1.0), 0.50);
			rgb += ring_col * ring_mask * hair_angel_ring_strength * 0.28 * w_hair * ink_protect;
		}

		// Cuña cóncava Scythe-Wedge Mignola en pliegues articulares (solo si hay flexión activa)
		if (!is_head_part && !is_leg_part && joint_flexion > 0.05) {
			float u_fold = (fold_inner_side >= 0.0) ? (1.0 - sample_uv.x) : sample_uv.x;
			float dv_joint = abs(sample_uv.y - joint_v_coord);
			float wedge_reach = 0.16 * joint_flexion * pow(max(0.0, 1.0 - dv_joint / 0.16), 1.8) + max(0.0, -ndl) * 0.05 * joint_flexion;
			float sigma_u = max(fwidth(u_fold) * s_comp * 0.75, 0.008);
			float mignola_wedge = smoothstep(wedge_reach + sigma_u, wedge_reach - sigma_u, u_fold) * (1.0 - open_bridge) * 0.35;
			rgb = mix(rgb, deep_mignola_ink.rgb, mignola_wedge * ink_protect);
		}

		// 6.3 Color Grading Cinematográfico LDR (suavizado en piel para no sobre-saturarla)
		if (abs(color_contrast - 1.0) > 0.005 || abs(color_saturation - 1.0) > 0.005) {
			float eff_c = mix(color_contrast, 1.0 + (color_contrast - 1.0) * 0.35, w_skin_clean);
			float eff_s = mix(color_saturation, 1.0 + (color_saturation - 1.0) * 0.25, w_skin_clean);
			vec3 graded_srgb = apply_cinematic_grade_srgb(linear_to_srgb(max(rgb, vec3(0.0))), eff_c, eff_s);
			rgb = mix(rgb, srgb_to_linear(graded_srgb), ink_protect);
		}

		// 6.4 Rim-Light 2.5D en Pasada 1 (sin(theta) real con length(n25.xy) x ILM.B)
		if (valid_nd && (normal_rim_strength > 0.005 || counter_rim_strength > 0.005)) {
			float rim_w = has_ilm_mask ? ilm_sample.b : 1.0;
			float grazing = smoothstep(0.14, 0.56, length(n25.xy));
			float rim_env = grazing * rim_w * (1.0 - face_prot * 0.88) * (1.0 - open_bridge) * (1.0 - back_leg_factor * 0.55) * mix(0.65, 1.18, nd_sample.a) * ink_protect;
			float key_align = smoothstep(-0.05, 0.68, dot(n25.xy, l2d));
			float ctr_align = smoothstep(0.08, 0.78, dot(n25.xy, -l2d));
			vec3 ctr_col = counter_rim_use_skin_accent ? accent_color.rgb : counter_rim_override_color.rgb;
			rgb += rim_key_color.rgb * smoothstep(0.20, 0.52, key_align * rim_env) * normal_rim_strength * 0.28;
			rgb += ctr_col * smoothstep(0.22, 0.55, ctr_align * rim_env) * counter_rim_strength * 0.24;
		}

		// 6.5 Emisivos HDR (ILM.A = monóculo óptico con profundidad + destello; mask.r = realce sutil de acentos)
		if (emissive_glow_strength > 0.005) {
			float ilm_em = has_ilm_mask ? smoothstep(0.25, 0.85, ilm_sample.a) * smoothstep(0.05, 0.25, w_accent) : 0.0;
			float pulse = 1.0 + 0.10 * sin(q_time * pulse_speed);
			if (ilm_em > 0.01) {
				float lens_depth = smoothstep(0.06, 0.28, orig_luma);
				float lens_glint = smoothstep(0.86, 0.95, ndh) * 0.45;
				vec3 em_core = mix(accent_color.rgb, rgb * 1.55 + accent_color.rgb * 0.55, 0.40);
				rgb += (em_core * lens_depth + vec3(1.0, 0.94, 0.96) * lens_glint) * ilm_em * emissive_glow_strength * pulse * 0.36 * ink_protect;
			}
			if (w_accent > 0.01) {
				float trim_em = w_accent * (0.28 + 0.72 * lit_mask) * ink_protect;
				vec3 trim_col = mix(rgb * 1.45, accent_color.rgb, 0.45);
				rgb += trim_col * trim_em * emissive_glow_strength * pulse * 0.11;
			}
		}
		if (is_head_part && enable_face_live) {
			rgb = apply_live_monocle_hud(
				rgb,
				sample_uv,
				w_accent,
				accent_color.rgb,
				q_time,
				face_eye_look_px,
				face_monocle_hud_strength,
				face_monocle_activity,
				ink_protect
			);
			if (face_eye_emit > 0.005 && face_eye_combat_glow > 0.005) {
				vec3 eye_glow_col = mix(srgb_to_linear(vec3(0.76, 0.50, 1.0)), accent_color.rgb, 0.12);
				rgb += eye_glow_col * face_eye_emit * face_eye_combat_glow * 0.38;
			}
			if (face_eye_spec > 0.005 && face_eye_highlight_strength > 0.005) {
				vec3 catchlight_col = srgb_to_linear(vec3(0.98, 0.99, 1.0));
				rgb += catchlight_col * face_eye_spec * face_eye_highlight_strength * 0.95;
			}
		}
		rgb = clamp(rgb, vec3(0.0), vec3(hdr_cap));

		// 6.6 Colored Line Art Interno (Pasada 1)
		if (ink_strength > 0.005 || face_lid_ink > 0.005) {
			float native_ink = (1.0 - smoothstep(0.06, 0.17, dark_luma)) * edge_alpha_guard;
			float eff_ink_str = max(ink_strength, face_lid_ink * 0.92);
			float ink_line = max(max(sdf_ink_line, face_lid_ink) * edge_alpha_guard, native_ink);
			vec3 local_dark = min(rgb, vec3(1.0)) * 0.24;
			vec3 cool_ink = mix(ink_cool_tint.rgb, local_dark, 0.35);
			vec3 acc_ink = mix(ink_cool_tint.rgb, accent_color.rgb * 0.20, 0.55);
			vec3 target_ink = mix(cool_ink, ink_skin_tint.rgb, w_skin_clean);
			target_ink = mix(target_ink, acc_ink, w_accent);
			float eye_ink_protect = clamp(max(face_eye_open_mask, face_lid_ink), 0.0, 1.0);
			target_ink = mix(target_ink, srgb_to_linear(vec3(0.06, 0.035, 0.10)), eye_ink_protect);
			vec3 neutral_ink = vec3(0.006, 0.006, 0.012);
			vec3 final_ink = mix(neutral_ink, target_ink, ink_color_tint_mix);
			vec3 safe_ink = min(rgb, final_ink);
			rgb = mix(rgb, safe_ink, clamp(ink_line * eff_ink_str, 0.0, 0.94));
		}
	} else {
		rgb = clamp(rgb, vec3(0.0), vec3(hdr_cap));
	}

	// Transición Estilizada 1: Barrido de sombra cel direccional + Rim Fresnel siguiendo las Normales 3D
	if (valid_nd && transition_fx_mode == 1 && transition_fx_strength > 0.005) {
		vec3 turn_l = normalize(vec3(light_dir_2d.x + transition_turn_dir * transition_fx_strength * 1.45, light_dir_2d.y, 0.48));
		float turn_ndl = dot(n25, turn_l);
		float cel_sweep_shadow = 1.0 - smoothstep(-0.22, 0.28, turn_ndl);
		rgb = mix(rgb, rgb * srgb_to_linear(vec3(0.52, 0.58, 0.78)), cel_sweep_shadow * transition_fx_strength * 0.62 * ink_protect);
		float turn_fresnel = pow(clamp(1.0 - max(n25.z, 0.0), 0.0, 1.0), 1.35) * smoothstep(-0.08, 0.55, abs(n25.x));
		vec3 turn_rim_col = mix(accent_color.rgb, srgb_to_linear(vec3(0.18, 0.96, 1.0)), 0.38);
		rgb += turn_rim_col * turn_fresnel * transition_fx_strength * ink_protect * 0.95;
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
		rgb = clamp(mix(rgb, beam_col, holo_beam * 0.92), vec3(0.0), vec3(max(hdr_cap, 1.25)));
	}

	// Emparejar tono de piel del stud superior de la pierna con la piel del torso (sin oscurecimiento AO)
	if (is_leg_part && debug_view_mode == 0 && sample_uv.y < 0.13 && orig_luma > 0.35 && orig_luma < 0.72) {
		float stud_y_w = 1.0 - smoothstep(0.06, 0.13, sample_uv.y);
		float stud_luma_w = smoothstep(0.72, 0.56, orig_luma);
		rgb *= mix(1.0, 1.15, stud_y_w * stud_luma_w);
	}

	rgb = clamp(rgb, vec3(0.0), vec3(hdr_cap));

	// 10.5 Máscaras de Costura entre Piezas
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
	bool is_body_bottom_seam = (!is_head_part && !is_leg_part && weld_bottom_seam && sample_uv.y > 0.78 && base.a < 0.95);
	float outline_seam_keep = clamp(neck_seam_mask + (is_leg_top_seam || is_arm_top_seam || is_body_bottom_seam ? 1.0 : 0.0), 0.0, 1.0);
	float seam_feather_keep = clamp(outline_seam_keep + (is_stocking_overlay ? 1.0 : 0.0), 0.0, 1.0);
	bool suppress_head_collar_ink = is_head_part && (is_collar_blue > 0.25 && is_hair < 0.5);

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
		// Anclada en espacio UV de pose en reposo para mantenerse 100% estática ante animaciones y escorzos 2.5D
		vec2 rest_rig_pos = (part_rig_rect.xy + UV * part_rig_rect.zw) * 490.0;
		vec2 leg_in_body_px = rest_rig_pos - (hip_cast_body_rect.xy * 490.0);
		vec2 sample_px = leg_in_body_px - hip_cast_shadow_offset_px;
		vec2 bc_uv = sample_px / body_size_px;
		if (bc_uv.x >= 0.0 && bc_uv.x <= 1.0 && bc_uv.y >= 0.48 && bc_uv.y <= 1.0) {
			float bc_a = textureLod(hip_cast_body_tex, bc_uv, 0.0).a;
			float cel_shadow_mask = smoothstep(0.45, 0.55, bc_a) * smoothstep(0.10, 0.20, orig_luma);
			rgb = mix(rgb, rgb * srgb_to_linear(hip_cast_shadow_color.rgb), cel_shadow_mask);
		}
	}

	// 10.5 Outline Fino (Per-Piece Erosión + Outline Externo, Legacy Inward Outline, o Sharp Piece-Edge Cover)
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
	// Nota: sharp_piece_edge octogonal en LOD 0 fue desactivado para evitar dientes de sierra antes del contorno caligráfico de Pasada 2.

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
		float ink_line = has_ink_sdf ? sdf_ink_line : (1.0 - smoothstep(0.11, 0.16, orig_luma));
		rgb = mix(dbg, abyssal_ink, ink_line);
	} else if (debug_view_mode == 2) {
		// Mapa de Luminancia Original
		rgb = vec3(orig_luma);
	} else if (debug_view_mode == 3) {
		// Solo Líneas de Tinta y Silueta sobre Blanco Puro (SDF analítico si existe, fallback luminancia)
		float ink_line = has_ink_sdf ? sdf_ink_line : clamp((1.0 - smoothstep(0.10, 0.22, orig_luma)) * (1.0 + ink_strength), 0.0, 1.0);
		rgb = mix(vec3(1.0), abyssal_ink, ink_line);
	} else if (debug_view_mode == 4) {
		// Mapa de Normales 2.5D (Sapiens-Lite + Portador Cilíndrico RNM)
		rgb = valid_nd ? clamp(n25 * 0.5 + 0.5, vec3(0.0), vec3(1.0)) : nd_sample.rgb;
	} else if (debug_view_mode == 5) {
		// Mapa de Profundidad 2.5D (Depth-Anything-V2)
		rgb = vec3(nd_sample.a);
	} else if (debug_view_mode == 6) {
		// Mapa ILM (R=Spec, G=ShadowBias/AO, B=RimWeight, A=Emissive en Magenta)
		rgb = has_ilm_mask ? mix(ilm_sample.rgb, vec3(1.0, 0.0, 1.0), ilm_sample.a) : vec3(0.18, 0.18, 0.22);
	} else if (debug_view_mode == 7 || debug_view_mode == 8) {
		vec4 dbg_flm = textureLod(face_live_mask_tex, sample_uv, 0.0);
		vec3 dbg_hair = textureLod(secondary_jiggle_mask_tex, sample_uv, 0.0).rgb;
		rgb = srgb_to_linear(compute_face_live_debug_rgb(debug_view_mode, dbg_flm, dbg_hair, is_collar_blue, linear_to_srgb(rgb)));
	}

	if (hit_flash > 0.0) {
		rgb = mix(rgb, srgb_to_linear(vec3(1.0, 0.25, 0.25)), hit_flash);
	}

	float zoom_out_bias = is_head_part ? 0.0 : smoothstep(2.0, 5.5, screen_px_in_texels);
	float alpha_mid = mix(0.50, 0.46, zoom_out_bias);
	float fw_base_a = max(fwidth(base.a) * 0.95, 0.02);
	float crisp_edge_a = smoothstep(max(alpha_mid - fw_base_a, 0.02), min(alpha_mid + fw_base_a, 0.98), base.a);
	float out_a = mix(crisp_edge_a, base.a, 0.75);
	float crisp_base_a = mix(out_a, base.a, seam_feather_keep);
	float final_alpha = use_part_edge_outline ? part_edge_final_alpha : max(crisp_base_a, centered_outer_alpha);
	COLOR = vec4(rgb, final_alpha * v_modulate_alpha * layer_alpha);
}
