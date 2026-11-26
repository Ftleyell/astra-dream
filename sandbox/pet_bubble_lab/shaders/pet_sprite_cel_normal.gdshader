shader_type canvas_item;

uniform sampler2D normal_map : filter_linear, repeat_disable;
uniform vec3 sun_dir_3d = vec3(-0.48, 0.68, 0.55);
uniform vec4 sun_color : source_color = vec4(1.0, 0.97, 0.92, 1.0);

uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform vec4 shadow_tint : source_color = vec4(0.56, 0.58, 0.78, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float rim_strength : hint_range(0.0, 1.5) = 0.55;

uniform float flip_x_sign = 1.0;
uniform float wobble_time = 0.0;
uniform float wobble_strength : hint_range(0.0, 0.06) = 0.014;

uniform float orbit_depth : hint_range(-1.0, 1.0) = 1.0;
uniform float depth_back_dim : hint_range(0.0, 0.7) = 0.26;
uniform float flip_flash : hint_range(0.0, 1.5) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform int debug_mode = 0; // 0=Final, 1=Flat, 2=Normal, 3=Lighting

void fragment() {
	// Subtle alive breathing & gentle zero-G sway inside the 56px padding margin
	vec2 uv = UV;
	float breath = sin(wobble_time * 3.1) * wobble_strength * 0.55;
	float sway = sin(wobble_time * 2.2 + uv.y * 3.6) * wobble_strength * (0.65 - uv.y);
	uv.x = clamp(uv.x + sway, 0.002, 0.998);
	uv.y = clamp(uv.y + (uv.y - 0.5) * breath, 0.002, 0.998);

	vec4 albedo = texture(TEXTURE, uv);
	if (albedo.a <= 0.01) {
		discard;
	}

	vec3 n_tex = texture(normal_map, uv).rgb * 2.0 - 1.0;
	n_tex.x *= flip_x_sign * normal_strength;
	n_tex.y *= normal_strength;
	vec3 n = normalize(n_tex);

	if (debug_mode == 1) {
		COLOR = albedo;
	} else if (debug_mode == 2) {
		COLOR = vec4(n * 0.5 + 0.5, albedo.a);
	} else {
		vec3 l_dir = normalize(sun_dir_3d);
		float ndotl = dot(n, l_dir);

		// Two-band anime cel ramp with soft anti-aliased transitions
		float shadow_band = smoothstep(-0.22, 0.16, ndotl);
		float hi_band = smoothstep(0.58, 0.80, ndotl);

		vec3 lit_factor = mix(shadow_tint.rgb, sun_color.rgb, shadow_band);
		lit_factor += sun_color.rgb * hi_band * 0.14;

		// Soft Fresnel rim from inside the colored glass sphere
		float rim = pow(clamp(1.0 - max(n.z, 0.0), 0.0, 1.0), 2.3) * rim_strength;
		float depth_t = clamp((1.0 - orbit_depth) * 0.5, 0.0, 1.0);
		float dim_mult = mix(1.0, 1.0 - depth_back_dim, depth_t);

		if (debug_mode == 3) {
			vec3 dbg = lit_factor * 0.75 + rim_color.rgb * rim;
			COLOR = vec4(dbg * dim_mult, albedo.a);
		} else {
			vec3 final_rgb = albedo.rgb * lit_factor + rim_color.rgb * rim;
			vec3 glint_rgb = mix(rim_color.rgb, flash_color.rgb, 0.65) * 1.45;
			final_rgb = mix(final_rgb, glint_rgb, clamp(flip_flash * 0.88, 0.0, 0.92));
			COLOR = vec4(final_rgb * dim_mult, albedo.a);
		}
	}
}
