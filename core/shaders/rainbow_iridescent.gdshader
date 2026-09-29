shader_type canvas_item;

uniform float cycle_speed : hint_range(0.1, 10.0) = 1.6;
uniform float frequency : hint_range(0.1, 10.0) = 2.2;
uniform float saturation : hint_range(0.0, 1.0) = 0.95;
uniform float brightness : hint_range(0.5, 3.0) = 1.25;
uniform float blend_intensity : hint_range(0.0, 1.0) = 0.38;

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.02) {
		discard;
	}

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

	COLOR = vec4(final_rgb, tex.a);
}
