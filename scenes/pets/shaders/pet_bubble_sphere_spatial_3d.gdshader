shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform sampler2D bubble_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool is_front_shell = true;
uniform bool low_quality_mode = false;

uniform vec4 theme_color : source_color = vec4(1.0, 0.72, 0.25, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.90, 0.55, 1.0);
uniform vec4 inner_glow_color : source_color = vec4(1.0, 0.58, 0.18, 1.0);

uniform vec4 skin_tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float skin_tint_strength : hint_range(0.0, 1.0) = 0.0;
uniform float skin_star_boost : hint_range(0.0, 1.5) = 0.0;

uniform float shell_opacity : hint_range(0.0, 1.0) = 0.34;
uniform float edge_texture_opacity : hint_range(0.0, 1.0) = 0.78;
uniform float texture_strength : hint_range(0.0, 2.0) = 0.88;
uniform float glass_refraction : hint_range(0.0, 1.0) = 0.36;
uniform float bubble_bump_strength : hint_range(0.0, 1.0) = 0.30;
uniform float caustic_strength : hint_range(0.0, 2.0) = 0.95;
uniform float rim_bevel_darkness : hint_range(0.0, 1.0) = 0.72;
uniform float fresnel_power : hint_range(0.5, 6.0) = 2.6;
uniform float fresnel_strength : hint_range(0.0, 2.0) = 1.05;
uniform float iridescence_strength : hint_range(0.0, 1.0) = 0.28;
uniform float specular_strength : hint_range(0.0, 2.0) = 1.15;

uniform vec3 sun_dir_3d = vec3(-0.48, 0.68, 0.55);
uniform vec4 cosmic_key_tint : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform vec4 cosmic_shadow_tint : source_color = vec4(0.32, 0.36, 0.58, 1.0);
uniform vec4 cosmic_rim_color : source_color = vec4(0.75, 0.92, 1.0, 1.0);
uniform float demat_progress : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_local_normal;

void vertex() {
	v_local_normal = normalize(NORMAL);
}

vec3 sample_triplanar_bubble(vec3 n_rot, float scale) {
	vec3 blend = pow(abs(n_rot), vec3(4.0));
	blend /= max(blend.x + blend.y + blend.z, 0.0001);

	vec2 uv_xy = n_rot.xy * 0.5 * scale + 0.5;
	vec2 uv_yz = n_rot.yz * 0.5 * scale + 0.5;
	vec2 uv_xz = n_rot.xz * 0.5 * scale + 0.5;

	vec3 c_xy = texture(bubble_tex, uv_xy).rgb;
	vec3 c_yz = texture(bubble_tex, uv_yz).rgb;
	vec3 c_xz = texture(bubble_tex, uv_xz).rgb;
	return c_xy * blend.z + c_yz * blend.x + c_xz * blend.y;
}

vec3 apply_skin_recolor(vec3 tex_rgb) {
	if (skin_tint_strength <= 0.001) {
		return tex_rgb;
	}
	float luma = dot(tex_rgb, vec3(0.299, 0.587, 0.114));
	vec3 recolored = mix(theme_color.rgb * 0.25, skin_tint_color.rgb * (0.65 + 0.75 * luma), smoothstep(0.05, 0.88, luma));
	return mix(tex_rgb, recolored, skin_tint_strength);
}

vec3 thin_film_iridescence(float fresnel_val, vec3 n_rot) {
	float phase = fresnel_val * 5.2 + n_rot.y * 1.4 + n_rot.x * 0.9;
	return 0.5 + 0.5 * cos(phase + vec3(0.0, 2.094, 4.188));
}

void fragment() {
	if (is_front_shell && !FRONT_FACING) {
		discard;
	}
	if (!is_front_shell && FRONT_FACING) {
		discard;
	}

	vec3 n_view = normalize(NORMAL);
	if (is_front_shell && dot(n_view, VIEW) < 0.0) {
		n_view = -n_view;
	} else if (!is_front_shell && dot(n_view, VIEW) > 0.0) {
		n_view = -n_view;
	}

	float z_view = clamp(abs(dot(n_view, VIEW)), 0.0, 1.0);
	float r_rim = sqrt(max(0.0, 1.0 - z_view * z_view));
	float edge_wall = pow(clamp(1.0 - z_view, 0.0, 1.0), 1.35);
	float fresnel = pow(clamp(1.0 - z_view, 0.0, 1.0), fresnel_power);

	vec3 n_local = normalize(v_local_normal);
	vec3 up_l = abs(n_local.y) < 0.92 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 t_local = normalize(cross(up_l, n_local));
	vec3 b_local = normalize(cross(n_local, t_local));

	vec3 up_v = abs(n_view.y) < 0.92 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 t_view = normalize(cross(up_v, n_view));
	vec3 b_view = normalize(cross(n_view, t_view));

	vec3 l_dir = normalize((VIEW_MATRIX * vec4(sun_dir_3d, 0.0)).xyz);
	float star_irid_boost = 1.0 + skin_star_boost * 0.65;
	float star_fresnel_boost = 1.0 + skin_star_boost * 0.25;
	float demat_alpha = clamp(1.0 - demat_progress, 0.0, 1.0);

	if (is_front_shell) {
		vec3 n_tex = normalize(n_local + (t_local * 0.15 + b_local * 0.15) * edge_wall * glass_refraction);
		vec3 tex_col = apply_skin_recolor(sample_triplanar_bubble(n_tex, 1.08));
		float luma_c = dot(tex_col, vec3(0.299, 0.587, 0.114));

		vec3 n_bump = n_view;
		if (!low_quality_mode && bubble_bump_strength > 0.005) {
			float eps = 0.025;
			float luma_t = dot(sample_triplanar_bubble(normalize(n_tex + t_local * eps), 1.08), vec3(0.299, 0.587, 0.114));
			float luma_b = dot(sample_triplanar_bubble(normalize(n_tex + b_local * eps), 1.08), vec3(0.299, 0.587, 0.114));
			n_bump = normalize(n_view - (t_view * (luma_t - luma_c) + b_view * (luma_b - luma_c)) * bubble_bump_strength * 14.0);
		}

		float ndotl = dot(n_bump, l_dir);
		float lit_hemi = smoothstep(-0.28, 0.65, ndotl);
		float shadow_hemi = 1.0 - lit_hemi;

		float swirl_mask = smoothstep(0.10, 0.66, luma_c);
		vec3 irid = thin_film_iridescence(fresnel, n_local) * iridescence_strength * star_irid_boost * fresnel * (0.45 + 0.55 * lit_hemi);

		vec3 refl_dir = reflect(-VIEW, n_bump);
		float rdotl = max(dot(refl_dir, l_dir), 0.0);
		float spec_crisp = smoothstep(0.92, 0.975, rdotl) * specular_strength;
		float spec_broad = pow(rdotl, 14.0) * 0.30 * specular_strength;

		vec3 opp_l = normalize(vec3(-l_dir.x, -l_dir.y, 0.35));
		float crescent_band = smoothstep(0.35, 0.90, r_rim) * (1.0 - smoothstep(0.90, 0.99, r_rim));
		float caustic = crescent_band * pow(max(dot(n_bump, opp_l), 0.0), 2.4) * caustic_strength * (1.0 + skin_star_boost * 0.22);

		float outer_bevel = smoothstep(0.89, 0.965, r_rim) * (1.0 - smoothstep(0.985, 1.002, r_rim));
		float inner_rim_glow = fresnel * (0.40 + 0.65 * lit_hemi) * fresnel_strength * star_fresnel_boost;

		vec3 tex_lit = tex_col * texture_strength * (0.42 + 0.72 * lit_hemi) * cosmic_key_tint.rgb;
		vec3 shadow_tint = mix(theme_color.rgb, cosmic_shadow_tint.rgb, 0.25) * 0.16 * shadow_hemi * edge_wall;
		vec3 col = tex_lit + shadow_tint;
		col += mix(rim_color.rgb, cosmic_rim_color.rgb, 0.18) * inner_rim_glow;
		col += mix(inner_glow_color.rgb, rim_color.rgb, 0.55) * caustic;
		col += irid;
		col += cosmic_key_tint.rgb * (spec_crisp + spec_broad);
		col = mix(col, theme_color.rgb * 0.08, outer_bevel * rim_bevel_darkness);

		float center_tex_alpha = shell_opacity * 0.16;
		float edge_tex_alpha = edge_texture_opacity * (0.48 + 0.52 * swirl_mask);
		float tex_alpha = mix(center_tex_alpha, edge_tex_alpha, edge_wall);

		float alpha = tex_alpha;
		alpha += shadow_hemi * edge_wall * 0.22;
		alpha += inner_rim_glow * 0.44;
		alpha += caustic * 0.42;
		alpha += spec_crisp * 0.90 + spec_broad * 0.45;
		alpha += outer_bevel * (0.58 * rim_bevel_darkness + 0.18);

		ALBEDO = col;
		ALPHA = clamp(alpha, 0.0, 0.97) * demat_alpha;
	} else {
		vec3 n_tex = normalize(vec3(-n_local.x, n_local.y, n_local.z));
		vec3 tex_col = apply_skin_recolor(sample_triplanar_bubble(n_tex, 1.15));
		float luma_c = dot(tex_col, vec3(0.299, 0.587, 0.114));

		vec3 n_bump = n_view;
		if (!low_quality_mode && bubble_bump_strength > 0.005) {
			float eps = 0.025;
			float luma_t = dot(sample_triplanar_bubble(normalize(n_tex + t_local * eps), 1.15), vec3(0.299, 0.587, 0.114));
			float luma_b = dot(sample_triplanar_bubble(normalize(n_tex + b_local * eps), 1.15), vec3(0.299, 0.587, 0.114));
			n_bump = normalize(n_view - (t_view * (luma_t - luma_c) + b_view * (luma_b - luma_c)) * bubble_bump_strength * 10.0);
		}

		float back_lit = smoothstep(-0.35, 0.65, dot(n_bump, -l_dir));
		float radial_cavity = smoothstep(0.0, 0.98, z_view);
		vec3 base_cavity = mix(theme_color.rgb * 0.10, inner_glow_color.rgb * 0.36, 1.0 - radial_cavity);
		base_cavity *= (0.48 + 0.62 * back_lit);

		vec3 opp_l = normalize(vec3(-l_dir.x, -l_dir.y, -0.35));
		float back_caustic = pow(max(dot(n_bump, opp_l), 0.0), 2.8) * (1.0 - radial_cavity * 0.6) * caustic_strength * 0.45;

		vec3 col = base_cavity + tex_col * texture_strength * (0.55 + 0.55 * back_lit) * (0.65 + 0.45 * luma_c) * cosmic_key_tint.rgb;
		col += mix(inner_glow_color.rgb, rim_color.rgb, 0.4) * back_caustic;
		col += rim_color.rgb * fresnel * 0.42 * (0.5 + 0.5 * back_lit) * star_fresnel_boost;

		float back_edge_alpha = max(shell_opacity, edge_texture_opacity * 0.85);
		float alpha = mix(shell_opacity * 0.52, back_edge_alpha, edge_wall) + luma_c * 0.24 * texture_strength;

		ALBEDO = col;
		ALPHA = clamp(alpha, 0.0, 0.95) * demat_alpha;
	}
}
