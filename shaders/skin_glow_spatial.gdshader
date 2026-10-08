shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform sampler2D skin_mask : hint_default_white, filter_linear_mipmap;
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

// Macro segura para muestrear alpha con bordes
#define SAMPLE_ALPHA(c) (((c).x < 0.0 || (c).x > 1.0 || (c).y < 0.0 || (c).y > 1.0) ? 0.0 : texture(texture_albedo, (c)).a)

// Ruido pseudo-aleatorio para micro-chispas en 3★
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 tex_color = texture(texture_albedo, UV);
	if (tex_color.a < 0.05) {
		discard;
	}

	if (star_level <= 1) {
		ALBEDO = tex_color.rgb;
		ALPHA = tex_color.a;
	} else {
		// Detección perimetral de bordes para rim-light sin lavar el rostro ni el traje
		vec2 tex_size = vec2(textureSize(texture_albedo, 0));
		vec2 texel = (tex_size.x > 0.0) ? (1.0 / tex_size) : vec2(0.001);
		float radius = 3.2;

		float accum = 0.0;
		accum += SAMPLE_ALPHA(UV + vec2( radius, 0.0) * texel);
		accum += SAMPLE_ALPHA(UV + vec2(-radius, 0.0) * texel);
		accum += SAMPLE_ALPHA(UV + vec2(0.0,  radius) * texel);
		accum += SAMPLE_ALPHA(UV + vec2(0.0, -radius) * texel);
		accum += SAMPLE_ALPHA(UV + vec2( radius * 0.707,  radius * 0.707) * texel);
		accum += SAMPLE_ALPHA(UV + vec2(-radius * 0.707,  radius * 0.707) * texel);
		accum += SAMPLE_ALPHA(UV + vec2( radius * 0.707, -radius * 0.707) * texel);
		accum += SAMPLE_ALPHA(UV + vec2(-radius * 0.707, -radius * 0.707) * texel);
		accum /= 8.0;

		float pulse = 0.78 + 0.22 * sin(TIME * pulse_speed);
		float inner_rim = accum * (1.0 - smoothstep(0.65, 0.98, accum));

		vec3 final_rgb = tex_color.rgb;
		float mask_val = texture(skin_mask, UV).r;

		if (star_level == 2) {
			// 2★: Rim-light sutil en contorno exterior sin tapar la textura central
			final_rgb += glow_color.rgb * (inner_rim * mask_val * 0.65 * pulse * glow_intensity);
		} else {
			// 3★: Rim-light cromático + micro-destellos puntuales
			float shimmer = 0.5 + 0.5 * sin((UV.x + UV.y) * 6.0 + TIME * 3.5);
			vec3 aura_color = mix(glow_color.rgb, accent_color.rgb, shimmer);
			final_rgb += aura_color * (inner_rim * mask_val * 0.85 * pulse * glow_intensity);

			// Micro-chispas (sparks) flotantes respetando la máscara de rostro
			vec2 grid_uv = UV * 40.0;
			vec2 grid_id = floor(grid_uv);
			vec2 grid_pos = fract(grid_uv) - vec2(0.5);
			float spark_seed = hash21(grid_id);
			float spark_time = TIME * 4.0 + spark_seed * 6.28;
			float spark_blink = pow(max(0.0, sin(spark_time)), 8.0);
			float spark_shape = smoothstep(0.25, 0.03, length(grid_pos));
			float spark_val = spark_shape * spark_blink * (spark_seed > 0.75 ? 1.0 : 0.0);
			vec3 spark_color = mix(vec3(1.0), accent_color.rgb, 0.4);
			final_rgb += spark_color * (spark_val * mask_val * 0.75);
		}

		ALBEDO = final_rgb;
		ALPHA = tex_color.a;
	}
}
