shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_map : filter_linear, repeat_disable;

uniform vec3 sun_dir_3d = vec3(-0.48, 0.68, 0.55);
uniform vec4 cosmic_key_tint : source_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform vec4 cosmic_shadow_tint : source_color = vec4(0.56, 0.58, 0.78, 1.0);
uniform vec4 cosmic_rim_color : source_color = vec4(0.85, 0.94, 1.0, 1.0);

uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform vec4 shadow_tint : source_color = vec4(0.56, 0.58, 0.78, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float rim_strength : hint_range(0.0, 1.5) = 0.55;

uniform vec4 skin_grade_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float skin_grade_strength : hint_range(0.0, 1.0) = 0.0;
uniform float skin_star_boost : hint_range(0.0, 1.5) = 0.0;

uniform float planar_roll_rad = 0.0;
uniform vec2 squash_xy = vec2(1.0, 1.0);
uniform float flip_x_scale = 1.0;
uniform float flip_flash : hint_range(0.0, 1.5) = 0.0;

uniform float wobble_time = 0.0;
uniform float wobble_strength : hint_range(0.0, 0.06) = 0.014;
uniform float demat_progress : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	vec3 world_center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sx = length(MODEL_MATRIX[0].xyz) * squash_xy.x * flip_x_scale;
	float sy = length(MODEL_MATRIX[1].xyz) * squash_xy.y;

	float c = cos(planar_roll_rad);
	float s = sin(planar_roll_rad);
	vec2 rolled = vec2(VERTEX.x * c - VERTEX.y * s, VERTEX.x * s + VERTEX.y * c);

	vec3 view_center = (VIEW_MATRIX * vec4(world_center, 1.0)).xyz;
	vec3 view_pos = view_center + vec3(rolled.x * sx, rolled.y * sy, 0.0);
	POSITION = PROJECTION_MATRIX * vec4(view_pos, 1.0);
}

void fragment() {
	vec2 uv = UV;
	float breath = sin(wobble_time * 3.1) * wobble_strength * 0.55;
	float sway = sin(wobble_time * 2.2 + uv.y * 3.6) * wobble_strength * (0.65 - uv.y);
	uv.x = clamp(uv.x + sway, 0.002, 0.998);
	uv.y = clamp(uv.y + (uv.y - 0.5) * breath, 0.002, 0.998);

	vec4 albedo = texture(albedo_tex, uv);
	float eff_alpha = albedo.a * clamp(1.0 - demat_progress, 0.0, 1.0);
	if (eff_alpha <= 0.08) {
		discard;
	}

	float al_luma = dot(albedo.rgb, vec3(0.299, 0.587, 0.114));
	float ink_keep = smoothstep(0.08, 0.24, al_luma);
	albedo.rgb = mix(albedo.rgb, albedo.rgb * skin_grade_color.rgb * 1.18, skin_grade_strength * ink_keep);

	vec3 n_tex = texture(normal_map, uv).rgb * 2.0 - 1.0;
	float flip_sign = flip_x_scale >= 0.0 ? 1.0 : -1.0;
	n_tex.x *= flip_sign * normal_strength;
	n_tex.y *= normal_strength;
	vec3 n = normalize(n_tex);

	vec3 l_view = normalize((VIEW_MATRIX * vec4(sun_dir_3d, 0.0)).xyz);
	float ndotl = dot(n, l_view);
	float shadow_band = smoothstep(-0.22, 0.16, ndotl);
	float hi_band = smoothstep(0.58, 0.80, ndotl);

	vec3 eff_shadow = mix(shadow_tint.rgb, cosmic_shadow_tint.rgb, 0.22);
	vec3 lit_factor = mix(eff_shadow, cosmic_key_tint.rgb, shadow_band);
	lit_factor += cosmic_key_tint.rgb * hi_band * 0.14;

	float eff_rim = rim_strength * (1.0 + skin_star_boost * 0.55);
	float rim = pow(clamp(1.0 - max(n.z, 0.0), 0.0, 1.0), 2.3) * eff_rim;
	vec3 eff_rim_col = mix(rim_color.rgb, cosmic_rim_color.rgb, 0.18);

	vec3 final_rgb = albedo.rgb * lit_factor + eff_rim_col * rim;
	vec3 glint_rgb = mix(eff_rim_col, vec3(1.0, 0.96, 0.88), 0.65) * 1.45;
	final_rgb = mix(final_rgb, glint_rgb, clamp(flip_flash * 0.88, 0.0, 0.92));

	ALBEDO = final_rgb;
	ALPHA = eff_alpha;
}
