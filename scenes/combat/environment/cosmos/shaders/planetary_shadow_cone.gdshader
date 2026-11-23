shader_type canvas_item;
render_mode blend_add, unshaded;

/**
 * planetary_shadow_cone.gdshader
 *
 * Cono de sombra 2D analítico para planetas en Cosmos Engine.
 * Diseñado para operar como hijo de un CanvasGroup (CosmicShadowsGroup).
 * Separa canales RGB en R=umbra física convergente, G=penumbra difusa con ruido de polvo
 * y B=banda crepuscular de refracción atmosférica.
 */

uniform float base_radius = 120.0;
uniform float expansion_factor : hint_range(1.0, 3.5) = 1.85;
uniform float penumbra_ratio : hint_range(0.05, 0.9) = 0.45;
uniform float planet_sun_dist = 2000.0;
uniform float heliopause_radius = 4500.0;
uniform float heliosphere_edge_feather : hint_range(0.02, 0.5) = 0.22;
uniform float cone_length = 2600.0;
uniform float quad_height = 900.0;

uniform float star_radius = 220.0;
uniform float umbra_convergence : hint_range(0.0, 1.0) = 0.42;
uniform float dust_noise_strength : hint_range(0.0, 1.0) = 0.24;
uniform float atmo_refraction_strength : hint_range(0.0, 1.0) = 0.55;
uniform float global_time = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 41.23);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	// Coordenadas locales en píxeles dentro del cono
	// UV.x va de 0.0 (en el planeta) a 1.0 (en el extremo exterior del quad)
	float x_dist = clamp(UV.x, 0.0, 1.0) * cone_length;
	float y_dist = (UV.y - 0.5) * quad_height;
	float abs_y = abs(y_dist);

	// 1. Distancia radial euclidiana analítica al centro de la estrella (0, 0)
	float x_from_sun = planet_sun_dist + x_dist;
	float r_sun = sqrt((x_from_sun * x_from_sun) + (y_dist * y_dist));

	// Si el fragmento excede el radio exterior de la heliopausa, queda fuera del dominio solar
	if (r_sun >= heliopause_radius) {
		discard;
	}

	// 2. Fade-out concéntrico perimétrico idéntico al de star_light_field.gdshader
	float norm_r = r_sun / max(heliopause_radius, 1.0);
	float edge_fade = smoothstep(1.0, 1.0 - heliosphere_edge_feather, norm_r);

	// 3. Umbra física convergente + penumbra progresiva en distancia
	float dist_ratio = clamp(x_dist / max(cone_length, 1.0), 0.0, 1.0);
	float star_ratio = clamp(star_radius / max(base_radius, 1.0), 0.35, 3.0);
	float umbra_scale = mix(1.0, max(0.08, 1.0 - umbra_convergence * clamp(star_ratio * 0.42, 0.25, 1.25)), dist_ratio);
	float r_penumbra = base_radius * mix(1.03, expansion_factor, pow(dist_ratio, 0.88));
	float r_umbra = min(base_radius * umbra_scale, r_penumbra * (1.0 - penumbra_ratio * 0.45));

	if (abs_y >= r_penumbra * 1.04) {
		discard;
	}

	// 4. Modulación orgánica de polvo cósmico (2 octavas ligeras)
	float n1 = value_noise(vec2(x_dist * 0.0028 - global_time * 0.035, y_dist * 0.0055));
	float n2 = value_noise(vec2(x_dist * 0.0062 + global_time * 0.015, y_dist * 0.011));
	float dust_n = n1 * 0.65 + n2 * 0.35;

	// 5. Enganche esférico continuo abrazando el terminador trasero sin sobresalir del disco
	float r_local = length(vec2(x_dist, y_dist));
	float sphere_attach = smoothstep(base_radius * 0.80, base_radius * 1.14, r_local);
	float dist_soften = mix(1.0, 0.56, pow(dist_ratio, 1.20));

	// 6. Separación RGB para el CanvasGroup: R=umbra, G=penumbra, B=banda crepuscular atmosférica
	float r_umbra_out = (1.0 - smoothstep(r_umbra * 0.72, max(r_umbra * 1.16, r_umbra + 8.0), abs_y))
		* sphere_attach * edge_fade * dist_soften;
	float g_pen_out = (1.0 - smoothstep(r_umbra * 0.58, r_penumbra, abs_y))
		* sphere_attach * edge_fade * mix(1.0, 0.84 + 0.24 * dust_n, dust_noise_strength) * mix(1.0, 0.68, dist_ratio);

	float shoulder_center = mix(r_umbra, r_penumbra, 0.32);
	float shoulder_width = max((r_penumbra - r_umbra) * 0.45, 8.0);
	float b_twi_out = exp(-pow((abs_y - shoulder_center) / shoulder_width, 2.0))
		* sphere_attach * edge_fade * atmo_refraction_strength * (1.0 - dist_ratio * 0.65);

	float max_out = max(r_umbra_out, max(g_pen_out, b_twi_out));
	if (max_out <= 0.001) {
		discard;
	}

	// Salida 3 canales (umbra / penumbra / refracción crepuscular) para el CanvasGroup
	COLOR = vec4(clamp(r_umbra_out, 0.0, 1.0), clamp(g_pen_out, 0.0, 1.0), clamp(b_twi_out, 0.0, 1.0), 1.0);
}
