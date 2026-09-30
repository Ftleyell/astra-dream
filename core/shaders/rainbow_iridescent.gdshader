shader_type canvas_item;

uniform float cycle_speed : hint_range(0.1, 10.0) = 1.6;
uniform float frequency : hint_range(0.1, 10.0) = 2.2;
uniform float saturation : hint_range(0.0, 1.0) = 0.95;
uniform float brightness : hint_range(0.5, 3.0) = 1.25;
uniform float blend_intensity : hint_range(0.0, 1.0) = 0.38;

// Outline violeta neón para silueta del enemigo arcoíris
uniform vec4 outline_color : source_color = vec4(0.75, 0.15, 1.0, 1.0);
uniform float outline_thickness : hint_range(0.0, 60.0) = 30.0;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.05;

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	// Si el pixel pertenece a la nave, aplicar el efecto irisado arcoíris
	if (tex.a > alpha_threshold) {
		// Gradiente dinámico de arcoíris en diagonal
		float hue = fract(TIME * cycle_speed + (UV.x + UV.y) * frequency);
		vec3 rainbow = hsv2rgb(vec3(hue, saturation, 1.0));

		// Luminancia de la textura para preservar volumen y sombras mecánicas
		float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

		// Shimmer / pulso brillante
		float pulse = sin(TIME * 6.0) * 0.12 + 1.0;
		vec3 rainbow_sheen = rainbow * (0.6 + lum * 0.6) * brightness * pulse;

		// Mezcla translúcida para que la textura original y gráficos de la nave se distingan claramente
		vec3 final_rgb = mix(tex.rgb, rainbow_sheen, blend_intensity);

		COLOR = vec4(final_rgb, tex.a) * COLOR;
	} else {
		// Si el pixel es transparente, muestrear silueta para el contorno violeta grueso
	float max_alpha = 0.0;
	vec2 pixel_size = TEXTURE_PIXEL_SIZE;
	const int ANGLES = 16;
	for (int i = 0; i < ANGLES; i++) {
		float angle = float(i) * (6.28318530718 / float(ANGLES));
		vec2 dir = vec2(cos(angle), sin(angle));
		float a1 = texture(TEXTURE, UV + dir * pixel_size * outline_thickness).a;
		float a2 = texture(TEXTURE, UV + dir * pixel_size * (outline_thickness * 0.65)).a;
		float a3 = texture(TEXTURE, UV + dir * pixel_size * (outline_thickness * 0.35)).a;
		max_alpha = max(max_alpha, max(a1, max(a2, a3)));
		if (max_alpha >= 0.9) {
			break;
		}
	}

	if (max_alpha > alpha_threshold) {
		COLOR = vec4(outline_color.rgb * COLOR.rgb, outline_color.a * COLOR.a * smoothstep(alpha_threshold, 0.35, max_alpha));
	} else {
		COLOR = vec4(0.0);
	}
	}
}
