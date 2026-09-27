shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform int star_level : hint_range(1, 3) = 1;
uniform vec4 glow_color : source_color = vec4(0.0, 0.94, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.0, 0.5, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_speed : hint_range(0.1, 10.0) = 2.5;

void vertex() {
	// Spherical camera-facing billboard keeping node scaling
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(INV_VIEW_MATRIX[0].xyz) * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[1].xyz) * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[2].xyz) * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 tex_color = texture(texture_albedo, UV);
	if (tex_color.a < 0.05) {
		discard;
	}

	if (star_level <= 1) {
		ALBEDO = tex_color.rgb;
		ALPHA = tex_color.a;
	} else if (star_level == 2) {
		float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
		vec3 final_rgb = tex_color.rgb + glow_color.rgb * (pulse * 0.45 * glow_intensity);
		ALBEDO = final_rgb;
		ALPHA = tex_color.a;
	} else {
		float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
		float shimmer = 0.5 + 0.5 * sin((UV.x + UV.y) * 8.0 + TIME * 4.0);
		vec3 aura_mix = mix(glow_color.rgb, accent_color.rgb, shimmer);
		vec3 final_rgb = tex_color.rgb + aura_mix * (0.55 * pulse * glow_intensity);
		ALBEDO = final_rgb;
		ALPHA = tex_color.a;
	}
}
