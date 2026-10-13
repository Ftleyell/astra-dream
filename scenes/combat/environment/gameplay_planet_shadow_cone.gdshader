shader_type canvas_item;
render_mode blend_mul, unshaded;

/**
 * gameplay_planet_shadow_cone.gdshader
 *
 * Cono de sombra 2D analítico para planetas interactuables de GameplayWorld.
 * Diseñado para operar de forma autónoma en el árbol de gameplay (hijo de GameplayPlanetShadowCaster2D).
 * Utiliza blend_mul multiplicativo idéntico al modo de mezcla de Cosmos Engine (CosmicShadowsGroup),
 * garantizando coherencia fotométrica y contraste uniforme sobre luz estelar, nebulosas y polvo interestelar.
 */

uniform float base_radius = 120.0;
uniform float expansion_factor : hint_range(1.0, 3.5) = 1.85;
uniform float penumbra_ratio : hint_range(0.05, 0.9) = 0.45;
uniform float planet_sun_dist = 2000.0;
uniform float heliopause_radius = 4500.0;
uniform float heliosphere_edge_feather : hint_range(0.02, 0.5) = 0.22;
uniform float cone_length = 2600.0;
uniform float quad_height = 900.0;
uniform vec4 shadow_tint : source_color = vec4(0.18, 0.18, 0.24, 1.0);
uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.75;

void fragment() {
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

	// 2. Fade-out concéntrico perimétrico idéntico al del campo de luz estelar
	float norm_r = r_sun / max(heliopause_radius, 1.0);
	float edge_fade = smoothstep(1.0, 1.0 - heliosphere_edge_feather, norm_r);

	// 3. Radio cónico analítico con ensanchamiento óptico
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

	// 5. Suave enganche pegado a la superficie del planeta
	float attach_fade = smoothstep(0.0, max(base_radius * 0.15, 4.0), x_dist);

	float total_mask = shadow_factor * attach_fade * edge_fade;

	float effective_shadow = total_mask * shadow_opacity;
	if (effective_shadow <= 0.001) {
		discard;
	}

	// Oscurecimiento multiplicativo fotométricamente idéntico a Cosmos Engine
	vec3 mult_color = mix(vec3(1.0), shadow_tint.rgb, effective_shadow);
	COLOR = vec4(mult_color, 1.0);
}
