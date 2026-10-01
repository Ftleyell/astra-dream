shader_type canvas_item;

// Shader cinemático de fractura de energía, blanqueamiento dinámico y jitter de vértices
// Usado en las fases 1 a 3 de la muerte estilo Mega Man / Supernova en jefes.

uniform float u_whiteness : hint_range(0.0, 1.0) = 0.0;
uniform float u_fracture_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_jitter_amount : hint_range(0.0, 25.0) = 0.0;
uniform vec4 energy_color : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform float energy_intensity : hint_range(1.0, 6.0) = 3.2;
uniform sampler2D noise_tex : repeat_enable;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	if (u_jitter_amount > 0.001) {
		float h1 = hash12(VERTEX + vec2(TIME * 30.0, 0.0));
		float h2 = hash12(VERTEX + vec2(0.0, TIME * 30.0));
		vec2 jitter = vec2(h1 - 0.5, h2 - 0.5) * 2.0 * u_jitter_amount;
		VERTEX += jitter;
	}
}

void fragment() {
	vec4 base_col = texture(TEXTURE, UV);
	if (base_col.a < 0.02) {
		discard;
	}

	// Muestreo del mapa de ruido para generar grietas dinámicas
	float n = texture(noise_tex, UV * 2.0).r;
	
	// Grietas de energía que se expanden con u_fracture_progress
	float crack_dist = abs(n - (1.0 - u_fracture_progress * 0.85));
	float crack_mask = 1.0 - smoothstep(0.0, 0.10, crack_dist);
	crack_mask *= step(0.02, u_fracture_progress);

	// Tinte hacia blanco puro
	vec3 mixed_color = mix(base_col.rgb, vec3(1.0), u_whiteness);

	// Resplandor de energía HDR en las grietas
	vec3 crack_emission = energy_color.rgb * (energy_intensity * crack_mask);

	// Composición final con soporte para WorldEnvironment Glow
	vec3 final_rgb = mixed_color + crack_emission;
	COLOR = vec4(final_rgb, base_col.a * COLOR.a);
}
