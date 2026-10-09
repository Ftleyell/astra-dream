shader_type canvas_item;

/**
 * planet_atmosphere.gdshader
 *
 * Shader de atmósfera planetaria física para cuerpos celestes en Astra Dream.
 * Implementa:
 * 1. Resplandor Fresnel / Rim Light en el limbo interior del planeta.
 * 2. Arco iluminado sincronizado con la luz clave cósmica (superior-izquierda).
 * 3. Haze / corona atmosférica exterior que funde con el espacio interestelar.
 * 4. Oclusión total del lado oscuro / penumbra para eclipsar estrellas y nebulosas de fondo.
 */

// Propiedades de la Atmósfera y Color
uniform vec4 atmosphere_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float atmosphere_intensity : hint_range(0.0, 5.0) = 1.6;
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.5;

// Geometría del cuerpo esférico (en coordenadas normalizadas UV 0..1 del sprite)
uniform vec2 planet_center = vec2(0.5, 0.5);
uniform float planet_radius : hint_range(0.1, 0.5) = 0.40;

// Recorte perimétrico en Godot (elimina rebordes negros y suaviza el corte esférico exacto)
uniform float rim_edge_feather : hint_range(0.0005, 0.05) = 0.006;
uniform float edge_crop_margin : hint_range(0.0, 0.08) = 0.015; // Porción del borde a podar hacia adentro

// Velo e integración con el bioma cósmico activo
uniform vec4 biome_tint_color : source_color = vec4(0.18, 0.05, 0.32, 1.0);
uniform float biome_tint_intensity : hint_range(0.0, 1.0) = 0.28;
uniform float biome_tint_mode : hint_range(0.0, 1.0) = 0.0; // 0: tint suave de sombras y tonos medios


// Iluminación cósmica (Luz clave superior-izquierda por defecto)
uniform vec2 light_direction = vec2(-0.707106, -0.707106);
uniform float light_depth : hint_range(0.0, 1.0) = 0.35;
uniform float terminator_offset : hint_range(-1.0, 1.0) = 0.05;
uniform float terminator_softness : hint_range(0.01, 1.0) = 0.35;

// Corona / Haze atmosférico exterior
uniform float outer_atmosphere_thickness : hint_range(0.001, 0.1) = 0.028;
uniform float outer_atmosphere_intensity : hint_range(0.0, 3.0) = 0.9;

// Oclusión total del fondo cósmico en penumbra / sombras (Efecto Eclipse)
uniform float dark_side_occlusion : hint_range(0.0, 1.0) = 1.0;

// Rotación axial lenta del cuerpo planetario (rad/s)
uniform float axial_spin_speed : hint_range(-0.1, 0.1) = 0.006;


void fragment() {
	vec2 delta = UV - planet_center;

	// Rotación axial de la superficie geológica (la iluminación y el terminador se mantienen fijos)
	vec2 surface_uv = UV;
	if (abs(axial_spin_speed) > 0.00001) {
		float angle = TIME * axial_spin_speed;
		float c = cos(angle);
		float s = sin(angle);
		vec2 rot_delta = vec2(delta.x * c - delta.y * s, delta.x * s + delta.y * c);
		surface_uv = planet_center + rot_delta;
	}
	vec4 tex_color = texture(TEXTURE, surface_uv);
	float dist = length(delta);
	float norm_dist = dist / max(planet_radius, 0.0001);

	// Normalización del vector 3D de luz cósmica
	vec2 l_dir_2d = normalize(light_direction);
	vec3 light_dir_3d = normalize(vec3(l_dir_2d.x, l_dir_2d.y, light_depth));

	// Radio efectivo podado para erradicar cualquier artefacto o reborde del sprite original
	float effective_radius = max(planet_radius - edge_crop_margin, 0.001);
	float crop_norm_dist = dist / effective_radius;

	bool is_inside_sphere = crop_norm_dist <= 1.0;

	// Normal superficial de la semiesfera frontal visible
	float z = is_inside_sphere ? sqrt(max(0.0, 1.0 - crop_norm_dist * crop_norm_dist)) : 0.0;
	vec3 normal = is_inside_sphere ? vec3(delta / effective_radius, z) : vec3(0.0);

	// Fresnel esférico (0 en el centro del planeta, 1 en el limbo perimetral)
	float fresnel = is_inside_sphere ? pow(1.0 - z, fresnel_power) : 0.0;

	// Incidencia de la luz cósmica con la normal
	float n_dot_l = is_inside_sphere ? dot(normal, light_dir_3d) : 0.0;
	float lit_factor = smoothstep(terminator_offset - terminator_softness, terminator_offset + terminator_softness, n_dot_l);

	// Resplandor atmosférico en el limbo interior del planeta (Fresnel en arco iluminado)
	float inner_atmosphere = fresnel * lit_factor * atmosphere_intensity;

	// Transición suave de borde (feather) para que el corte esférico sea perfecto y orgánico
	float edge_mask = 1.0 - smoothstep(effective_radius - rim_edge_feather, effective_radius, dist);

	// Corona atmosférica exterior (haze difuso que funde con el vacío espacial)
	float outer_atmosphere = 0.0;
	if (dist > effective_radius && dist < effective_radius + outer_atmosphere_thickness) {
		float outer_dist = (dist - effective_radius) / outer_atmosphere_thickness;
		float outer_falloff = exp(-outer_dist * 3.5) * (1.0 - outer_dist);

		// Orientación respecto a la fuente de luz estelar
		vec2 dir_2d = normalize(delta);
		float dir_alignment = max(0.0, dot(dir_2d, l_dir_2d));
		float lit_outer = mix(0.12, 1.0, pow(dir_alignment, 1.4));

		outer_atmosphere = outer_falloff * lit_outer * outer_atmosphere_intensity;
	}

	// Composición del píxel final y Oclusión de Fondo
	if (edge_mask > 0.001) {
		vec3 surface = tex_color.rgb;

		// Capa de integración ambiental con el Bioma activo (tint cósmico)
		// Se mezcla proporcionalmente con las sombras y atmósfera para unificar la iluminación
		vec3 ambient_layer = mix(surface, surface * biome_tint_color.rgb * 1.8, 0.65);
		ambient_layer = mix(ambient_layer, biome_tint_color.rgb * 0.45, (1.0 - lit_factor) * 0.40);
		surface = mix(surface, ambient_layer, biome_tint_intensity);

		// Corona interna atmosférica
		vec3 combined_atmo_color = mix(atmosphere_color.rgb, biome_tint_color.rgb, biome_tint_intensity * 0.5);
		surface += combined_atmo_color * inner_atmosphere;

		// Oclusión del lado oscuro:
		// Cuando dark_side_occlusion es 1.0, el alfa interior es 1.0 absoluto dentro de la esfera
		float final_alpha = mix(tex_color.a, 1.0, dark_side_occlusion) * edge_mask;
		COLOR = vec4(surface, final_alpha);
	} else if (outer_atmosphere > 0.001) {
		vec3 outer_atmo_color = mix(atmosphere_color.rgb, biome_tint_color.rgb, biome_tint_intensity * 0.5);
		COLOR = vec4(outer_atmo_color, outer_atmosphere * atmosphere_color.a);
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
}

