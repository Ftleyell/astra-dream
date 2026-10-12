shader_type canvas_item;
render_mode blend_add, unshaded;

/**
 * planetary_shadow_cone.gdshader
 *
 * Cono de sombra 2D analítico para planetas en Cosmos Engine.
 * Diseñado para operar como hijo de un CanvasGroup (CosmicShadowsGroup).
 * Dibuja una máscara aditiva en escala de grises que representa la oclusión de luz.
 *
 * Características analíticas:
 * 1. Distancia radial euclidiana exacta al centro de la estrella: r_sun = sqrt((D + x)^2 + y^2).
 * 2. Curvatura concéntrica perfecta en la punta que coincide con la circunferencia de la heliopausa.
 * 3. Fade-out perimétrico idéntico al del campo de luz estelar (heliosphere_edge_feather).
 * 4. Núcleo nítido (umbra) cerca de la base y penumbra difusa suave en los bordes y la distancia.
 */

uniform float base_radius = 120.0;
uniform float expansion_factor : hint_range(1.0, 3.5) = 1.85;
uniform float penumbra_ratio : hint_range(0.05, 0.9) = 0.45;
uniform float planet_sun_dist = 2000.0;
uniform float heliopause_radius = 4500.0;
uniform float heliosphere_edge_feather : hint_range(0.02, 0.5) = 0.22;
uniform float cone_length = 2600.0;
uniform float quad_height = 900.0;

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

	// 3. Radio cónico analítico con ensanchamiento óptico realista
	float progress = clamp(x_dist / max(cone_length, 1.0), 0.0, 1.0);
	float r_cone = base_radius * mix(1.0, expansion_factor, progress);
	float r_umbra = r_cone * (1.0 - penumbra_ratio);

	// 4. Perfil transversal de oclusión (umbra total + penumbra difusa suave)
	float shadow_factor = 0.0;
	if (abs_y <= r_umbra) {
		shadow_factor = 1.0;
	} else if (abs_y < r_cone) {
		shadow_factor = 1.0 - smoothstep(r_umbra, r_cone, abs_y);
	} else {
		discard;
	}

	// 5. Suave enganche (attach fade) pegado a la superficie del planeta
	float attach_fade = smoothstep(0.0, max(base_radius * 0.15, 4.0), x_dist);

	float total_mask = shadow_factor * attach_fade * edge_fade;

	if (total_mask <= 0.001) {
		discard;
	}

	// Salida como máscara aditiva en canal rojo/blanco para el CanvasGroup
	COLOR = vec4(total_mask, total_mask, total_mask, 1.0);
}
