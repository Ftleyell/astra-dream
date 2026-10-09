shader_type canvas_item;

/**
 * sun_corona.gdshader
 *
 * Shader de estrella cósmica / sol incandescente para zócalos estelares en Astra Dream.
 * Implementa:
 * 1. Muestreo de textura estelar de alta resolución con rotación axial convectiva lenta.
 * 2. Núcleo incandescente hiperbrillante con pulsación térmica orgánica y flare.
 * 3. Corona solar difusa exterior con desvanecimiento exponencial (sin bordes duros).
 * 4. Tinte espectral tipificado (enana amarilla, gigante roja, supergigante azul).
 * 5. Dispersión atmosférica Rayleigh integrada contra la nebulosa activa de fondo.
 */

uniform vec2 sun_center = vec2(0.5, 0.5);
uniform float core_radius : hint_range(0.1, 0.5) = 0.36;
uniform float core_feather : hint_range(0.01, 0.2) = 0.08;
uniform float emission_boost : hint_range(1.0, 5.0) = 2.4;

// Corona exterior
uniform float corona_thickness : hint_range(0.01, 0.3) = 0.12;
uniform float corona_intensity : hint_range(0.0, 4.0) = 1.8;
uniform vec4 corona_color : source_color = vec4(1.0, 0.72, 0.28, 1.0);

// Dinámica térmica y convección
uniform float axial_spin_speed : hint_range(-0.1, 0.1) = 0.004;
uniform float pulse_speed : hint_range(0.1, 4.0) = 1.2;
uniform float pulse_depth : hint_range(0.0, 0.3) = 0.08;

// Espectro y tinte de estrella
uniform vec4 spectral_tint : source_color = vec4(1.0, 0.95, 0.85, 1.0);

// Integración Rayleigh con el bioma
uniform vec4 biome_tint_color : source_color = vec4(0.12, 0.04, 0.22, 1.0);
uniform float biome_tint_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float rayleigh_depth : hint_range(0.0, 1.0) = 0.20;

// Recorte radial seguro contra bordes de textura
uniform float radial_fade_start : hint_range(0.3, 0.5) = 0.44;
uniform float radial_fade_end : hint_range(0.4, 0.5) = 0.495;

void fragment() {
	vec2 delta = UV - sun_center;
	float dist = length(delta);

	// Rotación lenta convectiva
	vec2 uv = UV;
	if (abs(axial_spin_speed) > 0.00001) {
		float angle = TIME * axial_spin_speed;
		float c = cos(angle);
		float s = sin(angle);
		uv = sun_center + vec2(delta.x * c - delta.y * s, delta.x * s + delta.y * c);
	}

	vec4 tex = texture(TEXTURE, uv);

	// Pulsación térmica del núcleo
	float pulse = 1.0 + sin(TIME * pulse_speed + dist * 12.0) * pulse_depth;

	// Núcleo brillante
	float core_mask = 1.0 - smoothstep(core_radius - core_feather, core_radius, dist);
	float core_emission = pow(core_mask, 1.5) * emission_boost * pulse;

	// Corona difusa exterior
	float corona_dist = max(0.0, dist - (core_radius - core_feather));
	float corona_falloff = exp(-corona_dist / max(corona_thickness, 0.001) * 3.2);
	float corona_alpha = corona_falloff * corona_intensity;

	// Desvanecimiento radial perimetral para eliminar esquinas negras del JPG
	float edge_feather = 1.0 - smoothstep(radial_fade_start, radial_fade_end, dist);

	// Composición de color estelar
	vec3 base_color = tex.rgb * spectral_tint.rgb;
	vec3 core_highlight = mix(base_color, vec3(1.0, 0.98, 0.92) * 1.5, core_emission * 0.6);
	vec3 corona_rgb = corona_color.rgb * corona_alpha;

	vec3 final_rgb = core_highlight + corona_rgb;

	// Dispersión Rayleigh: la luz del sol penetra la nebulosa, pero el borde se fusiona
	vec3 rayleigh_blend = mix(final_rgb, final_rgb * (vec3(1.0) - biome_tint_color.rgb * 0.5) + biome_tint_color.rgb * 0.2, rayleigh_depth * 0.4);
	final_rgb = mix(final_rgb, rayleigh_blend, biome_tint_intensity);

	// Alfa total: núcleo opaco + corona semi-transparente recortada
	float final_alpha = clamp(core_mask * 1.5 + corona_alpha * 0.85, 0.0, 1.0) * edge_feather;

	COLOR = vec4(final_rgb, final_alpha);
}
