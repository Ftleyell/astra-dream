shader_type canvas_item;
render_mode blend_mix;

#include "res://scenes/pilots/shaders/rig_stylized_lighting.gdshaderinc"

// --- Packed 3+1 Enemy Maps ---
uniform sampler2D normal_height_tex : hint_normal, filter_linear;
uniform sampler2D ilm_sdf_tex : hint_default_white, filter_linear; // 2x resolution, NO mipmaps
uniform sampler2D fx_motion_tex : hint_default_black, filter_linear;
uniform bool has_fx_motion = true;
uniform vec2 tex_size_px = vec2(512.0, 512.0);

// --- 2.5D Perspective Tilt, Relief, Shell Extrusion & Living Motion ---
uniform float sprite_rotation_rad = 0.0; // global rotation of this MeshInstance2D in Godot radians
uniform vec2 tilt_25d = vec2(0.0, 0.0); // x = roll [-1..1], y = pitch [-1..1] in local art space
uniform float relief_depth_px : hint_range(0.0, 60.0) = 26.0;
uniform float parallax_strength : hint_range(0.0, 0.08) = 0.032;

uniform bool extrusion_shell_mode = false;
uniform float extrusion_layer_t : hint_range(0.0, 1.0) = 0.0;
uniform float shell_thickness_px : hint_range(0.0, 28.0) = 13.0;

uniform float core_light_intensity : hint_range(0.0, 3.5) = 0.0;
uniform vec4 core_light_color : source_color = vec4(0.22, 1.0, 0.56, 1.0);
uniform vec2 core_light_art_pos = vec2(0.0, 12.0);
uniform vec2 piece_art_pos = vec2(0.0, 0.0);
uniform float piece_art_rot = 0.0;
uniform bool is_elytron_part = false;
uniform bool ely_hinge_active = false;
uniform vec3 ely_open_3d = vec3(0.0, 0.0, 0.0); // x = roll_rad, y = pitch_rad, z = lift_z_px
uniform vec2 ely_hinge_local_px = vec2(0.0, 0.0);
uniform vec2 ely_hinge_art_pos = vec2(0.0, 0.0);
uniform float ely_yaw_rad = 0.0;
uniform float ely_scale = 1.0;
uniform float ely_dome_height_px : hint_range(0.0, 50.0) = 30.0;
uniform int ely_face_mode = 0; // 0 = standard/shadow, 1 = outer convex dome, 2 = inner concave bowl
uniform float ely_rim_thickness_px : hint_range(0.0, 14.0) = 4.5;

uniform float motion_time = 0.0;
uniform float breath_amp : hint_range(0.0, 12.0) = 3.5;
uniform float leg_paddle_amp : hint_range(0.0, 14.0) = 6.0;
uniform float leg_paddle_freq : hint_range(0.0, 30.0) = 8.5;
uniform float leg_tuck : hint_range(0.0, 1.0) = 0.0;
uniform float tail_whip : hint_range(-1.0, 1.0) = 0.0;
uniform float wing_flap_phase = 0.0;
uniform float wing_flex_amp : hint_range(0.0, 16.0) = 4.5;
uniform bool is_wing_part = false;
uniform bool is_body_part = false;
uniform vec2 wing_hinge_uv = vec2(0.3438, 0.3516);
uniform float wing_blur_arc_rad : hint_range(0.0, 0.75) = 0.0;
uniform float wing_shutter_intensity : hint_range(0.0, 1.5) = 0.0;
uniform float wing_strobe_phase = 0.0;

// --- Workbench & Shadow Caster Modes ---
uniform bool flat_baseline_mode = false;
uniform bool shadow_caster_mode = false;
uniform vec4 shadow_caster_color : source_color = vec4(0.02, 0.015, 0.06, 0.62);

// --- Cosmos / Studio Key Lighting ---
uniform vec2 light_dir_2d = vec2(-0.55, -0.78);
uniform float light_z : hint_range(0.1, 2.0) = 0.58;
uniform vec4 key_light_tint : source_color = vec4(1.05, 1.02, 0.96, 1.0);
uniform float key_light_boost : hint_range(0.5, 2.0) = 1.08;
uniform float studio_exposure : hint_range(0.5, 2.8) = 1.50;
uniform float ambient_fill_strength : hint_range(0.0, 1.2) = 0.45;
uniform float green_bounce_strength : hint_range(0.0, 2.5) = 0.95;
uniform vec4 shadow_tint : source_color = vec4(0.145, 0.145, 0.335, 1.0);
uniform vec4 ao_tint : source_color = vec4(0.078, 0.064, 0.175, 1.0);
uniform vec4 rim_key_color : source_color = vec4(0.87, 0.95, 1.0, 1.0);
uniform float eclipse_factor : hint_range(0.0, 1.0) = 0.0;
uniform float emissive_boost : hint_range(0.5, 3.0) = 1.0;

// --- ArcSys x Biomech Style Controls ---
uniform float cel_strength : hint_range(0.0, 1.0) = 0.90;
uniform float cel_threshold : hint_range(-0.6, 0.6) = 0.12;
uniform float cel_softness : hint_range(0.005, 0.25) = 0.022;
uniform float cel_mid_band_strength : hint_range(0.0, 1.0) = 0.48;
uniform float albedo_de_shade : hint_range(0.0, 1.0) = 0.28;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.85;
uniform float specular_strength : hint_range(0.0, 2.5) = 1.45;
uniform float specular_threshold : hint_range(0.20, 0.95) = 0.38;
uniform vec4 sss_color : source_color = vec4(0.22, 0.98, 0.55, 1.0);
uniform float sss_strength : hint_range(0.0, 2.0) = 0.72;
uniform float iridescence_strength : hint_range(0.0, 2.0) = 0.90;
uniform vec4 iridescence_color_a : source_color = vec4(0.56, 0.28, 1.0, 1.0);
uniform vec4 iridescence_color_b : source_color = vec4(0.18, 0.96, 0.78, 1.0);
uniform float normal_rim_strength : hint_range(0.0, 2.5) = 1.15;
uniform float counter_rim_strength : hint_range(0.0, 1.5) = 0.42;
uniform vec4 counter_rim_color : source_color = vec4(0.68, 0.24, 0.96, 1.0);
uniform float color_contrast : hint_range(0.7, 1.6) = 1.08;
uniform float color_saturation : hint_range(0.5, 1.8) = 1.08;

// --- Ink SDF 2x & Outer Calligraphic Outline ---
uniform float ink_strength : hint_range(0.0, 1.0) = 0.92;
uniform vec4 ink_color : source_color = vec4(0.045, 0.040, 0.095, 1.0);
uniform float ink_sdf_bias_px : hint_range(-1.0, 1.0) = -0.10;
uniform float ink_sdf_softness : hint_range(0.15, 2.0) = 0.48;

uniform float outer_outline_width_px : hint_range(0.0, 6.0) = 1.35;
uniform float outer_outline_strength : hint_range(0.0, 1.0) = 0.88;
uniform vec4 outer_outline_color : source_color = vec4(0.045, 0.040, 0.095, 1.0);
uniform float outer_alert_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outer_alert_color : source_color = vec4(1.0, 0.22, 0.36, 1.0);
uniform float zoom_scale : hint_range(0.35, 4.5) = 1.0;
uniform float hdr_cap : hint_range(1.0, 4.0) = 2.6;

// --- Gameplay Emissives, Variants, Hit & Dissolve ---
uniform float primary_emissive_strength : hint_range(0.0, 4.0) = 1.35;
uniform float secondary_emissive_strength : hint_range(0.0, 5.0) = 0.50;
uniform float plasma_flow_speed : hint_range(0.0, 12.0) = 4.8;
uniform vec4 primary_emissive_tint : source_color = vec4(0.28, 1.0, 0.56, 1.0);
uniform vec4 secondary_emissive_tint : source_color = vec4(0.35, 1.0, 0.72, 1.0);
uniform bool enable_variant_recolor = false;
uniform vec4 variant_recolor_tint : source_color = vec4(0.92, 0.38, 1.0, 1.0);
uniform vec4 variant_armor_tint : source_color = vec4(0.32, 0.16, 0.48, 1.0);
uniform vec4 variant_energy_tint : source_color = vec4(0.88, 0.28, 1.0, 1.0);

uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_edge_color : source_color = vec4(0.35, 1.0, 0.62, 1.0);
uniform int debug_view_mode : hint_range(0, 7) = 0;

varying vec2 v_tex_px;
varying vec2 v_art_pos;
varying float v_face_sign;
varying float v_dome_frac;
varying vec3 v_dome_n_art;
varying vec4 v_modulate;

vec3 _srgb_to_linear(vec3 srgb) {
	vec3 c = clamp(srgb, vec3(0.0), vec3(1.0));
	vec3 lo = c / 12.92;
	vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}

vec3 _linear_to_srgb(vec3 lin) {
	vec3 c = clamp(lin, vec3(0.0), vec3(1.0));
	vec3 lo = c * 12.92;
	vec3 hi = 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055;
	return mix(lo, hi, step(vec3(0.0031308), c));
}

vec3 _project_ely_3d(vec2 uv_p, vec2 vtx_px, float z_ex, out vec2 scr_art_out, out float dome_frac_out) {
	vec2 d_h = (vtx_px - ely_hinge_local_px) * ely_scale;
	float out_sdf_v = textureLod(ilm_sdf_tex, clamp(uv_p, vec2(0.002), vec2(0.998)), 0.0).a;
	float dist_in_px = max(-(out_sdf_v - 0.5) * 48.0, 0.0);
	float dome_prof = pow(clamp(dist_in_px / 20.0, 0.0, 1.0), 0.62);
	dome_frac_out = dome_prof;
	float vh_s = textureLod(normal_height_tex, clamp(uv_p, vec2(0.002), vec2(0.998)), 0.0).b;
	float z_surf = shadow_caster_mode ? 0.0 : ((vh_s - 0.25) * relief_depth_px * 0.45 + dome_prof * ely_dome_height_px);
	vec3 p0 = vec3(d_h.x, d_h.y, z_surf + z_ex);

	float cr_e = cos(ely_open_3d.x);
	float sr_e = sin(ely_open_3d.x);
	vec3 p1 = vec3(p0.x * cr_e + p0.z * sr_e, p0.y, -p0.x * sr_e + p0.z * cr_e);

	float cp_e = cos(ely_open_3d.y);
	float sp_e = sin(ely_open_3d.y);
	vec3 p2 = vec3(p1.x, p1.y * cp_e - p1.z * sp_e, p1.y * sp_e + p1.z * cp_e);
	p2.z = shadow_caster_mode ? 0.0 : (p2.z + ely_open_3d.z);

	float cy_e = cos(ely_yaw_rad);
	float sy_e = sin(ely_yaw_rad);
	vec2 p_art_xy = vec2(p2.x * cy_e - p2.y * sy_e, p2.x * sy_e + p2.y * cy_e) + ely_hinge_art_pos;
	vec3 p_art = vec3(p_art_xy, p2.z);

	float roll_rad = clamp(tilt_25d.x, -1.0, 1.0) * 0.58;
	float pitch_rad = clamp(tilt_25d.y, -1.0, 1.0) * 0.52;
	float cr = cos(roll_rad);
	float sr = sin(roll_rad);
	vec3 p_r = vec3(p_art.x * cr + p_art.z * sr, p_art.y, -p_art.x * sr + p_art.z * cr);
	float cp = cos(pitch_rad);
	float sp = sin(pitch_rad);
	vec3 p_c = vec3(p_r.x, p_r.y * cp - p_r.z * sp, p_r.y * sp + p_r.z * cp);

	float persp = 1.0 / (1.0 - clamp(p_c.z / 760.0, -0.45, 0.50));
	scr_art_out = p_c.xy * persp;
	return p_c;
}

void vertex() {
	v_modulate = COLOR;
	v_face_sign = 1.0;
	v_dome_frac = 0.0;
	v_dome_n_art = vec3(0.0, 0.0, 1.0);
	vec2 uv_c = UV - vec2(0.5);
	vec4 nh_v = textureLod(normal_height_tex, UV, 0.0);
	vec4 fx_v = has_fx_motion ? textureLod(fx_motion_tex, UV, 0.0) : vec4(0.0);
	float vh = nh_v.b;
	float vm = fx_v.r;

	if (!flat_baseline_mode) {
		if (is_wing_part && wing_flex_amp > 0.001) {
			vec2 w_rel = UV - wing_hinge_uv;
			float tip_w = smoothstep(0.06, 0.36, length(w_rel));
			float flex_fade = 1.0 - clamp(wing_shutter_intensity, 0.0, 1.0) * 0.72;
			vec2 perp = normalize(vec2(-w_rel.y, w_rel.x) + vec2(0.0001));
			VERTEX += perp * cos(wing_flap_phase) * wing_flex_amp * vm * tip_w * flex_fade;
		} else if (is_body_part) {
			// 1. Subtle Flank/Rib Breathing (STRICTLY masks out rigid dorsal crystal core)
			float not_crystal = 1.0 - smoothstep(0.05, 0.25, max(nh_v.a, fx_v.b));
			float flank_only = smoothstep(0.045, 0.11, abs(uv_c.x));
			vec2 breath_d = UV - vec2(0.5, 0.56);
			float breath_w = exp(-dot(breath_d, breath_d) * 9.0) * not_crystal * flank_only;
			float breath_s = sin(motion_time * 3.1) * breath_amp * breath_w;
			VERTEX += normalize(breath_d + vec2(0.0001)) * breath_s * 1.4;

			// 2. Alternating Insectoid Leg Rowing + Aerodynamic Leg Tuck during boost/lunge
			float upper_palps = smoothstep(0.25, 0.42, abs(uv_c.x)) * smoothstep(0.26, 0.34, UV.y) * (1.0 - smoothstep(0.42, 0.50, UV.y));
			float leg_w = clamp(max(vm * smoothstep(0.32, 0.45, UV.y), upper_palps), 0.0, 1.0);
			if (leg_w > 0.01) {
				float side_s = sign(uv_c.x);
				if (leg_paddle_amp > 0.001) {
					float phase = motion_time * leg_paddle_freq + side_s * 1.6 + UV.y * 9.5;
					VERTEX.y += sin(phase) * leg_paddle_amp * (1.0 - leg_tuck * 0.55) * leg_w;
					VERTEX.x += cos(phase) * leg_paddle_amp * 0.55 * side_s * leg_w;
				}
				if (leg_tuck > 0.001) {
					VERTEX.y += leg_tuck * 18.0 * leg_w;
					VERTEX.x -= side_s * leg_tuck * 10.0 * leg_w;
				}
			}

			// 3. Tail Abdomen Inertia Sway (UV.y > 0.68)
			float tail_w = smoothstep(0.66, 0.96, UV.y);
			if (tail_w > 0.001) {
				VERTEX.x += (tail_whip * 18.0 + sin(motion_time * 3.4) * 3.0) * tail_w;
			}
		}
	}

	if (!flat_baseline_mode && is_elytron_part && ely_hinge_active) {
		// True 3D Thin Concave Shell Projection + Screen Winding Sign + Analytic Dome Normal
		float z_ex = (extrusion_shell_mode && !shadow_caster_mode) ? (-extrusion_layer_t * ely_rim_thickness_px) : ((ely_face_mode == 2 && !shadow_caster_mode) ? (-ely_rim_thickness_px) : 0.0);
		vec2 scr_c = vec2(0.0);
		float d_frac = 0.0;
		vec3 p_c = _project_ely_3d(UV, VERTEX, z_ex, scr_c, d_frac);

		float du = 1.0 / 64.0;
		float dv = 1.0 / 64.0;
		vec2 scr_u = vec2(0.0);
		vec2 scr_v = vec2(0.0);
		float df_unused = 0.0;
		vec3 p_u = _project_ely_3d(UV + vec2(du, 0.0), VERTEX + vec2(tex_size_px.x * du, 0.0), z_ex, scr_u, df_unused);
		vec3 p_v = _project_ely_3d(UV + vec2(0.0, dv), VERTEX + vec2(0.0, tex_size_px.y * dv), z_ex, scr_v, df_unused);

		vec2 s_u = scr_u - scr_c;
		vec2 s_v = scr_v - scr_c;
		float s_area = s_u.x * s_v.y - s_u.y * s_v.x;
		v_face_sign = s_area / max(length(s_u) * length(s_v), 0.0001);
		v_dome_frac = d_frac;
		v_dome_n_art = normalize(cross(p_u - p_c, p_v - p_c));
		v_art_pos = scr_c;

		float cy_e = cos(ely_yaw_rad);
		float sy_e = sin(ely_yaw_rad);
		vec2 back = scr_c - ely_hinge_art_pos;
		vec2 unrot = vec2(back.x * cy_e + back.y * sy_e, -back.x * sy_e + back.y * cy_e);
		VERTEX = (unrot / max(ely_scale, 0.001)) + ely_hinge_local_px;
	} else {
		if (!flat_baseline_mode) {
			// True 3D Perspective Roll & Pitch Projection over Heightmap + 2.5D Shell Extrusion Z
			float roll_rad = clamp(tilt_25d.x, -1.0, 1.0) * 0.58;
			float pitch_rad = clamp(tilt_25d.y, -1.0, 1.0) * 0.52;
			float z_extrude = extrusion_shell_mode ? (-extrusion_layer_t * shell_thickness_px) : 0.0;
			vec3 p3 = vec3(VERTEX.x, VERTEX.y, (vh - 0.32) * relief_depth_px + z_extrude);

			float cr = cos(roll_rad);
			float sr = sin(roll_rad);
			float x1 = p3.x * cr + p3.z * sr;
			float z1 = -p3.x * sr + p3.z * cr;
			float y1 = p3.y;

			float cp = cos(pitch_rad);
			float sp = sin(pitch_rad);
			float y2 = y1 * cp - z1 * sp;
			float z2 = y1 * sp + z1 * cp;

			float persp = 1.0 / (1.0 - clamp(z2 / 860.0, -0.34, 0.34));
			VERTEX = vec2(x1, y2) * persp;
		}
		float pa_c = cos(piece_art_rot);
		float pa_s = sin(piece_art_rot);
		v_art_pos = piece_art_pos + vec2(VERTEX.x * pa_c - VERTEX.y * pa_s, VERTEX.x * pa_s + VERTEX.y * pa_c);
	}
	v_tex_px = UV * max(tex_size_px, vec2(1.0));
}

void fragment() {
	vec2 px_size = min(TEXTURE_PIXEL_SIZE, vec2(1.0) / max(tex_size_px, vec2(1.0)));
	vec2 base_uv = UV;
	float screen_px_in_texels = clamp(min(length(dFdx(v_tex_px)), length(dFdy(v_tex_px))), 0.35, 24.0);

	if (shadow_caster_mode) {
		float sh_a = texture(TEXTURE, base_uv).a;
		if (sh_a < 0.05) {
			discard;
		}
		COLOR = vec4(shadow_caster_color.rgb * v_modulate.rgb, shadow_caster_color.a * sh_a * v_modulate.a);
	} else if (extrusion_shell_mode) {
		if (flat_baseline_mode) {
			discard;
		}
		vec4 sh_base = texture(TEXTURE, base_uv);
		if (sh_base.a < 0.15) {
			discard;
		}
		vec4 sh_nh = texture(normal_height_tex, base_uv);
		if (dissolve_amount > 0.001 && sh_nh.b < (dissolve_amount * 1.15 - 0.05)) {
			discard;
		}
		vec2 n_gl = sh_nh.rg * 2.0 - vec2(1.0);
		float sh_nz = sqrt(max(1.0 - dot(n_gl, n_gl), 0.05));
		vec3 n_sh = vec3(n_gl.x, -n_gl.y, sh_nz);
		if (is_elytron_part && ely_hinge_active) {
			float cr_e = cos(ely_open_3d.x);
			float sr_e = sin(ely_open_3d.x);
			n_sh = vec3(n_sh.x * cr_e + n_sh.z * sr_e, n_sh.y, -n_sh.x * sr_e + n_sh.z * cr_e);
			float cp_e = cos(ely_open_3d.y);
			float sp_e = sin(ely_open_3d.y);
			n_sh = normalize(vec3(n_sh.x, n_sh.y * cp_e - n_sh.z * sp_e, n_sh.y * sp_e + n_sh.z * cp_e));
		}
		float cs = cos(sprite_rotation_rad);
		float sn = sin(sprite_rotation_rad);
		vec2 n_w = vec2(n_sh.x * cs - n_sh.y * sn, n_sh.x * sn + n_sh.y * cs);
		float side_lit = smoothstep(-0.25, 0.65, dot(normalize(n_w + vec2(0.0001)), light_dir_2d));
		vec3 wall_dark = mix(ao_tint.rgb * 0.72, shadow_tint.rgb * 1.38, side_lit * (1.0 - extrusion_layer_t * 0.48));
		wall_dark += rim_key_color.rgb * pow(side_lit, 2.0) * 0.24 * (1.0 - extrusion_layer_t * 0.55);
		if (is_elytron_part && core_light_intensity > 0.01) {
			float core_e = core_light_intensity / (1.0 + core_light_intensity * 0.48);
			vec2 to_c = core_light_art_pos - v_art_pos;
			float d_c = length(to_c);
			float att_c = exp(-(d_c * d_c) / (135.0 * 135.0));
			float inner_w = mix(0.28, 1.0, extrusion_layer_t);
			wall_dark += core_light_color.rgb * att_c * core_e * inner_w * green_bounce_strength * 0.22;
		}
		wall_dark = mix(wall_dark, vec3(1.6, 1.7, 1.9), hit_flash * 0.65);
		COLOR = vec4(wall_dark * v_modulate.rgb, sh_base.a * v_modulate.a);
	} else if (flat_baseline_mode) {
		vec4 raw_base = texture(TEXTURE, base_uv);
		if (raw_base.a < 0.02) {
			discard;
		}
		COLOR = raw_base * v_modulate;
	} else {
		if (is_elytron_part && ely_hinge_active && debug_view_mode == 0) {
			if (ely_face_mode == 1 && v_face_sign < -0.015) {
				discard;
			}
			if (ely_face_mode == 2 && v_face_sign > 0.04) {
				discard;
			}
		}

		vec4 ilm_outer = textureLod(ilm_sdf_tex, base_uv, 0.0);
		float dist_native = (ilm_outer.a - 0.5) * 48.0;
		float dist_scr = dist_native / max(screen_px_in_texels, 0.35);

		// 5-Step Steep Parallax Relief Mapping inside interior (silhouette stays crisp)
		vec2 sample_uv = base_uv;
		if (parallax_strength > 0.0005 && !is_wing_part) {
			float edge_fade = smoothstep(0.0, -5.0, dist_native);
			if (edge_fade > 0.01) {
				vec2 p_dir = vec2(-tilt_25d.x, -tilt_25d.y) * parallax_strength * edge_fade;
				float layer_step = 0.2;
				float cur_layer = 1.0;
				vec2 cur_uv = clamp(base_uv + p_dir * 0.5, vec2(0.002), vec2(0.998));
				vec2 d_uv = p_dir * layer_step;
				for (int i = 0; i < 5; i++) {
					float h_map = 1.0 - textureLod(normal_height_tex, cur_uv, 0.0).b;
					if (cur_layer > h_map) {
						vec2 next_uv = clamp(cur_uv - d_uv, vec2(0.002), vec2(0.998));
						if (textureLod(TEXTURE, next_uv, 0.0).a > 0.25) {
							cur_uv = next_uv;
						}
						cur_layer -= layer_step;
					} else {
						break;
					}
				}
				if (textureLod(TEXTURE, cur_uv, 0.0).a > 0.25) {
					sample_uv = cur_uv;
				}
			}
		}

		vec4 base = texture(TEXTURE, sample_uv, -0.55);
		base.a = texture(TEXTURE, sample_uv).a;
		vec4 nh = texture(normal_height_tex, sample_uv);
		vec4 ilm_s = textureLod(ilm_sdf_tex, sample_uv, 0.0);
		vec4 fx_s = has_fx_motion ? texture(fx_motion_tex, sample_uv) : vec4(0.0);

		float wing_blur_w = 0.0;
		float wing_tip_w = 0.0;
		if (is_wing_part && wing_blur_arc_rad > 0.004 && debug_view_mode == 0) {
			vec2 w_rel = sample_uv - wing_hinge_uv;
			wing_blur_w = clamp(wing_shutter_intensity, 0.0, 1.0);
			wing_tip_w = smoothstep(0.04, 0.24, length(w_rel));
			vec3 acc_rgb = vec3(0.0);
			float acc_a = 0.0;
			vec4 acc_nh = vec4(0.0);
			vec4 acc_ilm = vec4(0.0);
			vec4 acc_fx = vec4(0.0);
			float w_sum = 0.0;
			for (int k = -3; k <= 3; k++) {
				float u = float(k) / 3.0;
				float ang = u * wing_blur_arc_rad;
				float ca = cos(ang);
				float sa = sin(ang);
				vec2 r_uv = wing_hinge_uv + vec2(w_rel.x * ca - w_rel.y * sa, w_rel.x * sa + w_rel.y * ca);
				float dw = mix(0.84, 1.32, u * u);
				w_sum += dw;
				if (r_uv.x > 0.002 && r_uv.x < 0.998 && r_uv.y > 0.002 && r_uv.y < 0.998) {
					vec4 tc = textureLod(TEXTURE, r_uv, 0.0);
					if (tc.a > 0.01) {
						float cw = tc.a * dw;
						acc_rgb += tc.rgb * cw;
						acc_a += cw;
						acc_nh += textureLod(normal_height_tex, r_uv, 0.0) * cw;
						acc_ilm += textureLod(ilm_sdf_tex, r_uv, 0.0) * cw;
						if (has_fx_motion) {
							acc_fx += textureLod(fx_motion_tex, r_uv, 0.0) * cw;
						}
					}
				}
			}
			float blur_a = clamp(acc_a / max(w_sum, 0.0001), 0.0, 1.0);
			float ang_h = atan(w_rel.y, w_rel.x);
			float silk_streak = 0.86 + 0.18 * sin(ang_h * 38.0 + wing_strobe_phase * 2.4);
			float fan_opacity = mix(1.0, 0.56 * silk_streak, wing_blur_w * wing_tip_w);
			if (acc_a > 0.0001) {
				base.rgb = acc_rgb / acc_a;
				nh = acc_nh / acc_a;
				ilm_s = acc_ilm / acc_a;
				fx_s = acc_fx / acc_a;
			}
			base.a = clamp(blur_a * fan_opacity, 0.0, 1.0);
		} else if (!is_wing_part && base.a > 0.82 && debug_view_mode == 0 && !(is_elytron_part && ely_face_mode == 2)) {
			// Lightweight 4-tap Contrast-Adaptive Sharpening (Valentina v2 parity)
			vec3 s_c = _linear_to_srgb(max(base.rgb, vec3(0.0)));
			vec3 s_n = _linear_to_srgb(max(textureLod(TEXTURE, clamp(sample_uv + vec2(0.0, -px_size.y), vec2(0.001), vec2(0.999)), 0.0).rgb, vec3(0.0)));
			vec3 s_s = _linear_to_srgb(max(textureLod(TEXTURE, clamp(sample_uv + vec2(0.0,  px_size.y), vec2(0.001), vec2(0.999)), 0.0).rgb, vec3(0.0)));
			vec3 s_w = _linear_to_srgb(max(textureLod(TEXTURE, clamp(sample_uv + vec2(-px_size.x, 0.0), vec2(0.001), vec2(0.999)), 0.0).rgb, vec3(0.0)));
			vec3 s_e = _linear_to_srgb(max(textureLod(TEXTURE, clamp(sample_uv + vec2( px_size.x, 0.0), vec2(0.001), vec2(0.999)), 0.0).rgb, vec3(0.0)));
			vec3 nb_min = min(s_c, min(min(s_n, s_s), min(s_w, s_e)));
			vec3 nb_max = max(s_c, max(max(s_n, s_s), max(s_w, s_e)));
			vec3 avg_nb = (s_n + s_s + s_w + s_e) * 0.25;
			base.rgb = _srgb_to_linear(clamp(s_c + (s_c - avg_nb) * 0.34, nb_min, nb_max));
		}

		float height_val = nh.b;
		if (dissolve_amount > 0.001) {
			float threshold = dissolve_amount * 1.15 - 0.05;
			if (height_val < threshold && base.a > 0.02) {
				discard;
			}
		}

		// Outer Silhouette SDF
		float zc = clamp(zoom_scale, 0.35, 4.5);
		float target_w = outer_outline_width_px * pow(zc, 0.55) * (1.0 + outer_alert_mix * 0.45);
		float out_cov = 0.0;
		if (outer_outline_strength > 0.01 && target_w > 0.05 && dist_scr > -0.4) {
			float outer_band = 1.0 - smoothstep(max(target_w - 0.55, 0.0), target_w + 0.55, dist_scr);
			float outside_mask = smoothstep(-0.45, 0.35, dist_scr);
			out_cov = outer_band * outside_mask * outer_outline_strength * (1.0 - wing_blur_w * wing_tip_w * 0.92);
		}

		float final_alpha = max(base.a, out_cov);
		if (final_alpha < 0.015) {
			discard;
		}

		// 3D-Tilted Normal + True 3D Hinge Rotation + World Rotation
		vec2 n_gl = nh.rg * 2.0 - vec2(1.0);
		float nz = sqrt(max(1.0 - dot(n_gl, n_gl), 0.05));
		vec3 n_loc = vec3(n_gl.x, -n_gl.y, nz);

		float roll_rad = clamp(tilt_25d.x, -1.0, 1.0) * 0.58;
		float pitch_rad = clamp(tilt_25d.y, -1.0, 1.0) * 0.52;
		float cr = cos(roll_rad);
		float sr = sin(roll_rad);
		float cp = cos(pitch_rad);
		float sp = sin(pitch_rad);

		vec3 n_tilt = vec3(0.0, 0.0, 1.0);
		vec3 n_world = vec3(0.0, 0.0, 1.0);
		vec3 n_art = vec3(0.0, 0.0, 1.0);
		if (is_elytron_part && ely_hinge_active) {
			float cr_e = cos(ely_open_3d.x);
			float sr_e = sin(ely_open_3d.x);
			vec3 ne1 = vec3(n_loc.x * cr_e + n_loc.z * sr_e, n_loc.y, -n_loc.x * sr_e + n_loc.z * cr_e);
			float cp_e = cos(ely_open_3d.y);
			float sp_e = sin(ely_open_3d.y);
			vec3 ne2 = vec3(ne1.x, ne1.y * cp_e - ne1.z * sp_e, ne1.y * sp_e + ne1.z * cp_e);
			float cy_e = cos(ely_yaw_rad);
			float sy_e = sin(ely_yaw_rad);
			vec3 ne_art = vec3(ne2.x * cy_e - ne2.y * sy_e, ne2.x * sy_e + ne2.y * cy_e, ne2.z);
			vec3 ne_r = vec3(ne_art.x * cr + ne_art.z * sr, ne_art.y, -ne_art.x * sr + ne_art.z * cr);
			n_art = normalize(vec3(ne_r.x, ne_r.y * cp - ne_r.z * sp, ne_r.y * sp + ne_r.z * cp));
			n_tilt = n_art;
			float art_world_rot = sprite_rotation_rad - ely_yaw_rad;
			float caw = cos(art_world_rot);
			float saw = sin(art_world_rot);
			vec2 nw_xy = vec2(n_art.x * caw - n_art.y * saw, n_art.x * saw + n_art.y * caw);
			n_world = normalize(vec3(nw_xy, n_art.z));
			if (ely_face_mode == 1) {
				n_art = normalize(mix(n_art, v_dome_n_art, 0.32));
				vec2 nwd_xy = vec2(n_art.x * caw - n_art.y * saw, n_art.x * saw + n_art.y * caw);
				n_world = normalize(vec3(nwd_xy, n_art.z));
			}
		} else {
			vec3 n_r = vec3(n_loc.x * cr + n_loc.z * sr, n_loc.y, -n_loc.x * sr + n_loc.z * cr);
			n_tilt = normalize(vec3(n_r.x, n_r.y * cp - n_r.z * sp, n_r.y * sp + n_r.z * cp));
			float pa_c = cos(piece_art_rot);
			float pa_s = sin(piece_art_rot);
			n_art = normalize(vec3(n_tilt.x * pa_c - n_tilt.y * pa_s, n_tilt.x * pa_s + n_tilt.y * pa_c, n_tilt.z));
			float cs = cos(sprite_rotation_rad);
			float sn = sin(sprite_rotation_rad);
			vec2 n_world_xy = vec2(n_tilt.x * cs - n_tilt.y * sn, n_tilt.x * sn + n_tilt.y * cs);
			n_world = normalize(vec3(n_world_xy, n_tilt.z));
		}
		vec3 l_world = normalize(vec3(light_dir_2d, light_z));
		float ndl = dot(n_world, l_world);

		// 2x Ink SDF sampling
		float sdf_ink_line = 0.0;
		if (ink_strength > 0.01) {
			float eff_tpp = clamp(screen_px_in_texels, 0.85, 1.65);
			float aa_px = clamp(0.45 * ink_sdf_softness, 0.15, 0.65);
			if (screen_px_in_texels <= 1.65) {
				float sdf_tex = (ilm_s.b - 0.5) * 16.0;
				sdf_ink_line = 1.0 - smoothstep(-aa_px + ink_sdf_bias_px, aa_px + ink_sdf_bias_px, sdf_tex / eff_tpp);
			} else {
				float s_foot = clamp(screen_px_in_texels * 0.36, 0.6, 2.2);
				vec2 s_rgss[4] = vec2[4](
					vec2(-0.35, -0.85), vec2(0.85, -0.35),
					vec2(0.35, 0.85), vec2(-0.85, 0.35)
				);
				float cov_sum = 0.0;
				for (int i = 0; i < 4; i++) {
					vec2 suv = clamp(sample_uv + s_rgss[i] * s_foot * px_size, vec2(0.0), vec2(1.0));
					float stex = (textureLod(ilm_sdf_tex, suv, 0.0).b - 0.5) * 16.0;
					cov_sum += 1.0 - smoothstep(-aa_px + ink_sdf_bias_px, aa_px + ink_sdf_bias_px, stex / eff_tpp);
				}
				sdf_ink_line = cov_sum * 0.25;
			}
		}

		if (debug_view_mode > 0) {
			vec3 dbg = base.rgb;
			if (debug_view_mode == 1) {
				dbg = base.rgb;
			} else if (debug_view_mode == 2) {
				dbg = _srgb_to_linear(vec3(n_world.x * 0.5 + 0.5, -n_world.y * 0.5 + 0.5, n_world.z * 0.5 + 0.5));
			} else if (debug_view_mode == 3) {
				dbg = _srgb_to_linear(vec3(height_val));
			} else if (debug_view_mode == 4) {
				dbg = _srgb_to_linear(vec3(ilm_s.r, ilm_s.g, 0.15));
			} else if (debug_view_mode == 5) {
				dbg = _srgb_to_linear(vec3(1.0 - sdf_ink_line));
			} else if (debug_view_mode == 6) {
				dbg = _srgb_to_linear(vec3(ilm_outer.a, out_cov, 0.35));
			} else if (debug_view_mode == 7) {
				dbg = _srgb_to_linear(fx_s.rgb);
			}
			COLOR = vec4(dbg * v_modulate.rgb, final_alpha * v_modulate.a);
		} else if (is_elytron_part && ely_face_mode == 2 && ely_hinge_active) {
			// Flat darkened concave carapace bowl + inverted 3D cavity normal + soft emerald green bounce
			vec3 n_in_art = normalize(-v_dome_n_art);
			float art_w_rot = sprite_rotation_rad - ely_yaw_rad;
			float caw_i = cos(art_w_rot);
			float saw_i = sin(art_w_rot);
			vec3 n_in_world = normalize(vec3(n_in_art.x * caw_i - n_in_art.y * saw_i, n_in_art.x * saw_i + n_in_art.y * caw_i, n_in_art.z));
			float ndl_in = dot(n_in_world, l_world);

			vec3 inner_base = vec3(0.024, 0.027, 0.058);
			if (enable_variant_recolor) {
				inner_base = mix(inner_base, variant_armor_tint.rgb * 0.14, 0.72);
			}
			float bowl_ao = mix(0.66, 1.0, 1.0 - v_dome_frac * 0.68);
			float bowl_lit = mix(0.78, 1.45, smoothstep(-0.28, 0.55, ndl_in)) * mix(1.0, studio_exposure * 0.85, 0.60) * (1.0 + clamp(ambient_fill_strength, 0.0, 1.0) * 0.28);
			vec3 inner_rgb = inner_base * bowl_ao * bowl_lit;
			inner_rgb = mix(ao_tint.rgb * 0.75, inner_rgb, clamp(bowl_ao, 0.52, 1.0));

			// Surgical, restrained emerald bounce inside concave bowl (no neon flood)
			float core_e = core_light_intensity / (1.0 + core_light_intensity * 0.48);
			vec2 to_c = core_light_art_pos - v_art_pos;
			float d_c = length(to_c);
			vec3 l_core = normalize(vec3(to_c, 28.0));
			float core_align = max(dot(n_in_art, l_core), 0.0);
			float att_core = exp(-(d_c * d_c) / (92.0 * 92.0));
			inner_rgb += core_light_color.rgb * (0.20 + 0.80 * core_align) * att_core * core_e * green_bounce_strength * 0.13;
			inner_rgb += core_light_color.rgb * nh.a * green_bounce_strength * 0.09;

			// Crisp inner fold rim catchlight
			float fold_rim = smoothstep(-0.35, 0.02, v_face_sign) * smoothstep(0.05, 0.55, max(ndl_in + 0.4, 0.0));
			inner_rgb += mix(shadow_tint.rgb, rim_key_color.rgb, 0.45) * fold_rim * 0.14;

			if (dissolve_amount > 0.001) {
				float threshold = dissolve_amount * 1.15 - 0.05;
				float burn = 1.0 - smoothstep(threshold, threshold + 0.14, height_val);
				inner_rgb += dissolve_edge_color.rgb * burn * 2.2;
			}

			vec3 out_col = mix(outer_outline_color.rgb, outer_alert_color.rgb, outer_alert_mix);
			float body_blend = clamp(base.a / max(final_alpha, 0.0001), 0.0, 1.0);
			vec3 composited = mix(out_col, inner_rgb, body_blend);
			if (hit_flash > 0.005) {
				composited = mix(composited, vec3(2.2, 2.35, 2.5), hit_flash);
			}
			composited = clamp(composited, vec3(0.0), vec3(hdr_cap));
			COLOR = vec4(composited * v_modulate.rgb, final_alpha * v_modulate.a);
		} else {
			vec3 rgb = base.rgb;
			vec3 srgb_base = _linear_to_srgb(max(rgb, vec3(0.0)));
			float orig_luma = dot(srgb_base, vec3(0.299, 0.587, 0.114));
			float orig_val = max(srgb_base.r, max(srgb_base.g, srgb_base.b));

			float edge_alpha_guard = smoothstep(0.65, 0.95, base.a);
			float true_black_ink = (1.0 - smoothstep(0.022, 0.062, orig_val)) * edge_alpha_guard;
			float not_black = smoothstep(0.022, 0.072, orig_val);
			float ink_protect = clamp(min(1.0 - sdf_ink_line * 0.90, not_black), 0.0, 1.0) * edge_alpha_guard;
			float em_prim = nh.a;
			float em_sec = fx_s.b;
			float em_protect = clamp(1.0 - max(em_prim, em_sec * 0.85), 0.0, 1.0);

			// Full-palette multi-zone variant recolor (wings, chitin armor, accents, and energy/blades)
			if (enable_variant_recolor) {
				vec3 v_arm_srgb = _linear_to_srgb(max(variant_armor_tint.rgb, vec3(0.0)));
				vec3 v_acc_srgb = _linear_to_srgb(max(variant_recolor_tint.rgb, vec3(0.0)));
				vec3 v_eng_srgb = _linear_to_srgb(max(variant_energy_tint.rgb, vec3(0.0)));
				float green_chroma = smoothstep(0.05, 0.18, srgb_base.g - max(srgb_base.r, srgb_base.b));
				float energy_zone = clamp(max(max(em_prim, em_sec), green_chroma), 0.0, 1.0);
				if (is_wing_part) {
					vec3 wing_recol = clamp(v_eng_srgb * clamp(orig_luma * 1.45, 0.20, 1.25) + vec3(0.06) * orig_luma, vec3(0.0), vec3(1.0));
					srgb_base = mix(srgb_base, wing_recol, 0.88 * not_black);
				} else {
					float trim_w = smoothstep(0.05, 0.35, fx_s.g);
					float chitin_w = (1.0 - energy_zone) * (1.0 - trim_w) * not_black;
					vec3 arm_col = clamp(v_arm_srgb * clamp(orig_val / 0.36, 0.22, 1.55), vec3(0.0), vec3(1.0));
					srgb_base = mix(srgb_base, arm_col, chitin_w * 0.80);
					if (fx_s.g > 0.05) {
						vec3 acc_col = clamp(v_acc_srgb * clamp(orig_val * 2.1, 0.45, 1.25), vec3(0.0), vec3(1.0));
						srgb_base = mix(srgb_base, acc_col, fx_s.g * 0.92 * not_black);
					}
					if (energy_zone > 0.04) {
						vec3 eng_col = mix(clamp(v_eng_srgb * clamp(orig_luma * 1.45, 0.35, 1.20), vec3(0.0), vec3(1.0)), vec3(0.96, 0.98, 1.0), smoothstep(0.68, 0.95, orig_luma) * 0.55);
						srgb_base = mix(srgb_base, eng_col, energy_zone * 0.92);
					}
				}
				rgb = _srgb_to_linear(clamp(srgb_base, vec3(0.0), vec3(1.0)));
				orig_luma = dot(srgb_base, vec3(0.299, 0.587, 0.114));
				orig_val = max(srgb_base.r, max(srgb_base.g, srgb_base.b));
			}

			// Bright-Anchored, Chroma-Preserving ArcSys 2-3 Band Cel Shading for Dark Chitin
			float ao_bias = (ilm_s.r - 0.5) * 1.15;
			float l_term = ndl + ao_bias * 0.24 + (height_val - 0.5) * 0.20 - eclipse_factor * 0.22;
			float soft = max(cel_softness, 0.005);
			float lit_mask = smoothstep(cel_threshold - soft, cel_threshold + soft, l_term);
			float mid_mask = smoothstep((cel_threshold - 0.36) - soft * 1.4, (cel_threshold - 0.36) + soft * 1.4, l_term);
			float shadow_w = (1.0 - lit_mask) * mix(1.0, mix(1.0, 0.58, mid_mask), cel_mid_band_strength);

			vec3 col_srgb = _linear_to_srgb(max(rgb, vec3(0.0)));
			float exp_t = clamp((studio_exposure - 1.0) * 0.65, -0.35, 1.15);
			vec3 lifted_srgb = (exp_t >= 0.0)
				? mix(col_srgb, pow(max(col_srgb, vec3(0.001)), vec3(0.84)) * mix(1.0, 1.16, clamp(exp_t, 0.0, 1.0)), clamp(exp_t, 0.0, 1.0) * not_black)
				: col_srgb * (1.0 + exp_t * 0.55);
			vec3 base_srgb = clamp(lifted_srgb, vec3(0.0), vec3(1.0));

			vec3 lit_srgb = clamp(base_srgb * mix(1.04, 1.16, clamp(exp_t, 0.0, 1.0)) + vec3(0.008, 0.010, 0.018) * not_black, vec3(0.0), vec3(1.0));

			vec3 sh_tint_srgb = _linear_to_srgb(max(shadow_tint.rgb, vec3(0.001)));
			float sh_max = max(max(sh_tint_srgb.r, sh_tint_srgb.g), max(sh_tint_srgb.b, 0.001));
			vec3 sh_hue = sh_tint_srgb / sh_max;
			// Preserve red/violet chroma: floor each shadow hue channel at 0.52 so teal Cosmos never erases purple trim
			vec3 safe_sh_mul = mix(vec3(0.56, 0.58, 0.72), max(sh_hue, vec3(0.52)) * 0.68, 0.48);
			vec3 de_shaded = mix(base_srgb, pow(max(base_srgb, vec3(0.001)), vec3(0.84)), albedo_de_shade * not_black);
			vec3 sh_target_srgb = clamp(de_shaded * safe_sh_mul + sh_tint_srgb * 0.045 * not_black, vec3(0.0), vec3(1.0));
			vec3 fill_srgb = mix(sh_target_srgb, base_srgb * vec3(0.82, 0.84, 0.94), clamp(ambient_fill_strength, 0.0, 1.0) * 0.45);
			vec3 shaded_srgb = mix(lit_srgb, fill_srgb, shadow_w * cel_strength * ink_protect * em_protect);
			rgb = _srgb_to_linear(shaded_srgb);

			float lit_w = lit_mask * cel_strength * ink_protect * em_protect * (1.0 - eclipse_factor * 0.35);
			vec3 gentle_key = mix(vec3(1.0), key_light_tint.rgb, 0.60) * key_light_boost;
			rgb = mix(rgb, rgb * gentle_key, lit_w);

			if (ao_strength > 0.01) {
				float ao_cov = smoothstep(0.28, 0.06, ilm_s.r) * ao_strength * ink_protect * em_protect * (1.0 - clamp(ambient_fill_strength, 0.0, 1.0) * 0.25);
				vec3 ao_mul = mix(vec3(1.0), vec3(0.58, 0.60, 0.74), clamp(ao_cov * 0.62, 0.0, 0.48));
				rgb *= ao_mul;
			}

			// Surgical Emerald Bounce: localized suture bleed on elytra, directional crystal gleam on thorax
			if (green_bounce_strength > 0.01 && !is_wing_part) {
				float core_e = core_light_intensity / (1.0 + core_light_intensity * 0.48);
				vec2 b_offs[4] = vec2[4](vec2(6.0, 6.0), vec2(-6.0, 6.0), vec2(6.0, -6.0), vec2(-6.0, -6.0));
				float em_bleed = 0.0;
				for (int bi = 0; bi < 4; bi++) {
					vec2 buv = clamp(sample_uv + b_offs[bi] * px_size, vec2(0.002), vec2(0.998));
					float bp = textureLod(normal_height_tex, buv, 0.0).a;
					float bs = has_fx_motion ? textureLod(fx_motion_tex, buv, 0.0).b : 0.0;
					em_bleed += max(bp, bs);
				}
				em_bleed *= 0.25;
				float bleed_mask = em_bleed * (1.0 - max(em_prim, em_sec)) * green_bounce_strength * ink_protect;
				if (is_elytron_part) {
					rgb += core_light_color.rgb * bleed_mask * 0.060;
				} else {
					rgb += core_light_color.rgb * bleed_mask * 0.080;
					vec2 foci[3] = vec2[3](vec2(0.0, -86.0), core_light_art_pos, vec2(0.0, 168.0));
					float f_weights[3] = float[3](0.045, 0.095 * (0.40 + core_e), 0.045);
					for (int fi = 0; fi < 3; fi++) {
						vec2 to_f = foci[fi] - v_art_pos;
						float d_f = length(to_f);
						float att_f = exp(-(d_f * d_f) / (68.0 * 68.0));
						vec3 l_f = normalize(vec3(to_f, 30.0));
						float f_ndl = max(dot(n_art, l_f), 0.0);
						rgb += core_light_color.rgb * f_ndl * att_f * f_weights[fi] * green_bounce_strength * ink_protect;
					}
				}
			}

			// Biomech SSS / Translucent Bio-Wing Glow
			float sss_mask = has_fx_motion ? fx_s.a : 0.25;
			if (sss_strength > 0.01 && sss_mask > 0.02) {
				float sss_dist = (l_term - cel_threshold) / max(soft * 2.2, 0.06);
				float term_band = exp(-sss_dist * sss_dist);
				float wing_trans = is_wing_part ? (0.48 + 0.52 * lit_mask) : term_band;
				rgb += sss_color.rgb * wing_trans * sss_mask * sss_strength * 0.20 * ink_protect;
			}

			// Crisp Stepped Armor Specular + Razor-Edge-Only Beetle Iridescence (Valentina v2 parity)
			vec3 half_v = normalize(l_world + vec3(0.0, 0.0, 1.0));
			float ndh = max(dot(n_world, half_v), 0.0);
			if (specular_strength > 0.01) {
				float spec_curve = pow(ndh, 8.0) * ilm_s.g * mix(0.20, 1.0, lit_mask);
				float spec_hi = smoothstep(specular_threshold - 0.04, specular_threshold + 0.04, spec_curve);
				float spec_sub = smoothstep(specular_threshold * 0.45 - 0.05, specular_threshold * 0.45 + 0.05, spec_curve);
				vec3 steel_col = mix(rgb * 2.1 + vec3(0.055, 0.070, 0.115), key_light_tint.rgb * 0.55, 0.35);
				rgb += steel_col * (spec_hi * 0.26 + spec_sub * 0.09) * specular_strength * ink_protect;
			}

			if (iridescence_strength > 0.01 && !is_wing_part) {
				float fres = smoothstep(0.42, 0.68, 1.0 - clamp(n_tilt.z, 0.0, 1.0));
				float chitin_mask = smoothstep(0.60, 0.92, ilm_s.g);
				vec3 irid_col = mix(iridescence_color_a.rgb, iridescence_color_b.rgb, lit_mask);
				rgb += irid_col * fres * chitin_mask * iridescence_strength * 0.20 * ink_protect;
			}

			// Dual Rim Light (Solar Key + Counter Rim)
			float grazing = smoothstep(0.14, 0.58, length(n_world.xy));
			float rim_env = grazing * mix(0.60, 1.20, height_val) * ink_protect;
			float key_align = smoothstep(-0.04, 0.66, dot(n_world.xy, light_dir_2d));
			float ctr_align = smoothstep(0.08, 0.76, dot(n_world.xy, -light_dir_2d));
			rgb += rim_key_color.rgb * smoothstep(0.18, 0.52, key_align * rim_env) * normal_rim_strength * 0.30;
			rgb += counter_rim_color.rgb * smoothstep(0.20, 0.54, ctr_align * rim_env) * counter_rim_strength * 0.24;

			if (abs(color_contrast - 1.0) > 0.005 || abs(color_saturation - 1.0) > 0.005) {
				vec3 gs = _linear_to_srgb(max(rgb, vec3(0.0)));
				gs = clamp((gs - vec3(0.26)) * color_contrast + vec3(0.26), vec3(0.0), vec3(1.0));
				float gl = dot(gs, vec3(0.2126, 0.7152, 0.0722));
				gs = clamp(mix(vec3(gl), gs, color_saturation), vec3(0.0), vec3(1.0));
				rgb = mix(rgb, _srgb_to_linear(gs), ink_protect * em_protect);
			}

			// Flowing HDR Bioluminescent Emissives
			float eclipse_em = mix(1.0, 1.65, eclipse_factor) * emissive_boost;
			float plasma_wave = 0.80 + 0.24 * sin(motion_time * plasma_flow_speed - base_uv.y * 14.0);
			if (em_prim > 0.02 && primary_emissive_strength > 0.01) {
				vec3 p_col = mix(rgb * 1.4, primary_emissive_tint.rgb, 0.64);
				rgb += p_col * em_prim * primary_emissive_strength * eclipse_em * plasma_wave * 0.78;
			}
			if (em_sec > 0.02 && secondary_emissive_strength > 0.01) {
				vec3 s_col = mix(primary_emissive_tint.rgb, secondary_emissive_tint.rgb, 0.75);
				rgb += s_col * em_sec * secondary_emissive_strength * eclipse_em * (0.9 + 0.2 * plasma_wave) * 0.92;
			}

			if (is_wing_part && wing_blur_w > 0.01) {
				float fan_sheen = wing_blur_w * wing_tip_w * smoothstep(0.05, 0.50, base.a);
				rgb += mix(sss_color.rgb, vec3(0.75, 1.15, 0.98), 0.45) * fan_sheen * 0.24;
			}

			// Colored Line Art Interno 2x (applied LAST matching Valentina 6.6)
			if (ink_strength > 0.01) {
				float ink_fade = 1.0 - wing_blur_w * wing_tip_w * 0.86;
				float em_ink_cut = 1.0 - max(em_prim, em_sec) * 0.82;
				float ink_line = max(sdf_ink_line * edge_alpha_guard, true_black_ink) * ink_fade * em_ink_cut;
				vec3 local_dark = min(rgb, vec3(1.0)) * 0.28;
				vec3 cool_ink = mix(ink_color.rgb, local_dark, 0.30);
				vec3 neutral_ink = vec3(0.006, 0.006, 0.014);
				vec3 final_ink = mix(neutral_ink, cool_ink, 0.82);
				vec3 safe_ink = min(rgb, final_ink);
				rgb = mix(rgb, safe_ink, clamp(ink_line * ink_strength, 0.0, 0.92));
			}

			if (dissolve_amount > 0.001) {
				float threshold = dissolve_amount * 1.15 - 0.05;
				float burn = 1.0 - smoothstep(threshold, threshold + 0.14, height_val);
				rgb += dissolve_edge_color.rgb * burn * 2.2;
			}

			vec3 out_col = mix(outer_outline_color.rgb, outer_alert_color.rgb, outer_alert_mix);
			if (outer_alert_mix > 0.05) {
				out_col += outer_alert_color.rgb * outer_alert_mix * 0.85;
			}
			float body_blend = clamp(base.a / max(final_alpha, 0.0001), 0.0, 1.0);
			vec3 composited = mix(out_col, rgb, body_blend);

			if (hit_flash > 0.005) {
				composited = mix(composited, vec3(2.2, 2.35, 2.5), hit_flash);
			}

			composited = clamp(composited, vec3(0.0), vec3(hdr_cap));
			COLOR = vec4(composited * v_modulate.rgb, final_alpha * v_modulate.a);
		}
	}
}
