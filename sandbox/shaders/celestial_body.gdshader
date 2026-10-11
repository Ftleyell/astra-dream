shader_type canvas_item;

/**
 * celestial_body.gdshader
 *
 * Shader universal de cuerpos celestes (planetas y lunas) para Cosmos Engine.
 * Diseñado específicamente para texturas JPG cuadradas sobre fondo negro.
 *
 * Características:
 * 1. Recorte esférico circular analítico con antialiasing perimétrico (elimina esquinas JPG).
 * 2. Terminador día/noche orientado dinámicamente hacia la estrella central (light_direction).
 * 3. Rotación axial de textura desacoplada de la dirección de iluminación.
 * 4. Cara nocturna con penumbra ambiental tenue (5-10%) y oclusión total del cosmos de fondo (eclipse).
 * 5. Fresnel interior y corona atmosférica exterior ajustable por arquetipo.
 * 6. Emisión incandescente opcional para cuerpos de magma (Moon_1).
 */

// Geometría y Recorte
uniform vec2 planet_center = vec2(0.5, 0.5);
uniform float planet_radius : hint_range(0.2, 0.5) = 0.485;
uniform float rim_edge_feather : hint_range(0.001, 0.05) = 0.007;
uniform float edge_crop_margin : hint_range(0.0, 0.05) = 0.012;

// Iluminación Dinámica y Terminador Día/Noche
uniform vec2 light_direction = vec2(-1.0, 0.0);
uniform float light_depth : hint_range(0.0, 1.0) = 0.30;
uniform float terminator_offset : hint_range(-1.0, 1.0) = 0.0;
uniform float terminator_softness : hint_range(0.01, 1.0) = 0.28;
uniform float night_ambient : hint_range(0.0, 0.3) = 0.08;
uniform vec4 night_tint_color : source_color = vec4(0.02, 0.03, 0.08, 1.0);

// Atmósfera y Resplandor (Fresnel)
uniform vec4 atmosphere_color : source_color = vec4(0.35, 0.75, 1.0, 1.0);
uniform float atmosphere_intensity : hint_range(0.0, 5.0) = 1.2;
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.5;
uniform float outer_atmosphere_thickness : hint_range(0.0, 0.08) = 0.022;
uniform float outer_atmosphere_intensity : hint_range(0.0, 3.0) = 0.75;

// Dinámica y Efectos Especiales
uniform float axial_spin_speed : hint_range(-0.1, 0.1) = 0.006;
uniform float emission_glow : hint_range(0.0, 2.0) = 0.0;
uniform vec4 emission_color : source_color = vec4(1.0, 0.3, 0.1, 1.0);

// Integración con Bioma Cósmico y Luz de la Estrella Central
uniform vec4 biome_tint_color : source_color = vec4(0.15, 0.08, 0.25, 1.0);
uniform float biome_tint_intensity : hint_range(0.0, 1.0) = 0.15;
uniform vec4 star_light_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float star_light_tint_strength : hint_range(0.0, 1.0) = 0.35;
uniform float star_atmo_tint_strength : hint_range(0.0, 1.0) = 0.45;


void fragment() {
	vec2 delta = UV - planet_center;
	float dist = length(delta);

	// Radio efectivo podado para erradicar las esquinas del JPG
	float effective_radius = max(planet_radius - edge_crop_margin, 0.001);
	float crop_norm_dist = dist / effective_radius;
	bool is_inside_sphere = crop_norm_dist <= 1.0;

	// Rotación axial de la textura de superficie (la iluminación se mantiene fija al vector solar)
	vec2 surface_uv = UV;
	if (abs(axial_spin_speed) > 0.00001) {
		float angle = TIME * axial_spin_speed;
		float c = cos(angle);
		float s = sin(angle);
		vec2 rot_delta = vec2(delta.x * c - delta.y * s, delta.x * s + delta.y * c);
		surface_uv = planet_center + rot_delta;
	}

	// Normal 3D de la semiesfera frontal visible
	float z = is_inside_sphere ? sqrt(max(0.0, 1.0 - crop_norm_dist * crop_norm_dist)) : 0.0;
	vec3 normal = is_inside_sphere ? vec3(delta / effective_radius, z) : vec3(0.0, 0.0, 1.0);

	// Vector 3D de luz estelar
	vec2 l_dir_2d = length(light_direction) > 0.0001 ? normalize(light_direction) : vec2(-1.0, 0.0);
	vec3 light_dir_3d = normalize(vec3(l_dir_2d.x, l_dir_2d.y, light_depth));

	// Incidencia de la luz (Terminador día / noche)
	float n_dot_l = dot(normal, light_dir_3d);
	float lit_factor = smoothstep(terminator_offset - terminator_softness, terminator_offset + terminator_softness, n_dot_l);

	// Fresnel esférico (0 en el centro, 1 en el limbo perimetral)
	float fresnel = is_inside_sphere ? pow(1.0 - z, fresnel_power) : 0.0;

	// Máscara perimétrica suave para el recorte esférico
	float edge_mask = 1.0 - smoothstep(effective_radius - rim_edge_feather, effective_radius, dist);

	// Corona exterior atmosférica en el vacío espacial
	float outer_atmosphere = 0.0;
	if (atmosphere_intensity > 0.01 && outer_atmosphere_thickness > 0.001 && dist > effective_radius && dist < effective_radius + outer_atmosphere_thickness) {
		float outer_dist = (dist - effective_radius) / outer_atmosphere_thickness;
		float outer_falloff = exp(-outer_dist * 3.5) * (1.0 - outer_dist);

		vec2 dir_2d = normalize(delta);
		float dir_alignment = max(0.0, dot(dir_2d, l_dir_2d));
		float lit_outer = mix(0.15, 1.0, pow(dir_alignment, 1.4));

		outer_atmosphere = outer_falloff * lit_outer * outer_atmosphere_intensity * atmosphere_intensity;
	}

	// Renderizado de píxel final
	if (edge_mask > 0.001) {
		vec4 tex_color = texture(TEXTURE, surface_uv);
		vec3 surface = tex_color.rgb;

		// Emisión térmica basal (ej. ríos de lava en lunas de magma)
		if (emission_glow > 0.01) {
			float luminance = dot(surface, vec3(0.299, 0.587, 0.114));
			vec3 emissive_boost = emission_color.rgb * emission_glow * (luminance * 0.8 + 0.2);
			surface += emissive_boost * (1.0 - lit_factor * 0.5);
		}

		// Iluminación día / noche con penumbra ambiental en el lado oscuro
		float light_multiplier = mix(night_ambient, 1.0, lit_factor);
		vec3 lit_surface = surface * light_multiplier;

		// Tinte de la luz de la estrella central en la cara diurna iluminada
		if (star_light_tint_strength > 0.001) {
			vec3 star_tinted = mix(lit_surface, lit_surface * star_light_color.rgb * 1.4, star_light_tint_strength);
			lit_surface = mix(lit_surface, star_tinted, lit_factor);
		}

		// Tinte sutil de la noche para dar profundidad y coherencia
		vec3 night_color = mix(lit_surface, surface * night_tint_color.rgb * 1.5, (1.0 - lit_factor) * 0.6);
		surface = mix(night_color, lit_surface, lit_factor);

		// Velo de bioma cósmico
		if (biome_tint_intensity > 0.001) {
			vec3 ambient_biome = mix(surface, surface * biome_tint_color.rgb * 1.6, 0.5);
			surface = mix(surface, ambient_biome, biome_tint_intensity);
		}

		// Resplandor atmosférico interior (fresnel concentrado en el arco iluminado por el sol)
		if (atmosphere_intensity > 0.01) {
			vec3 effective_atmo_color = atmosphere_color.rgb;
			if (star_atmo_tint_strength > 0.001) {
				effective_atmo_color = mix(effective_atmo_color, effective_atmo_color * star_light_color.rgb * 1.3, star_atmo_tint_strength * lit_factor);
			}
			float inner_atmosphere = fresnel * lit_factor * atmosphere_intensity;
			surface += effective_atmo_color * inner_atmosphere;
		}

		// Oclusión absoluta del fondo cósmico dentro de la esfera
		COLOR = vec4(surface, edge_mask) * COLOR;
	} else if (outer_atmosphere > 0.001) {
		vec3 effective_outer_color = atmosphere_color.rgb;
		if (star_atmo_tint_strength > 0.001) {
			effective_outer_color = mix(effective_outer_color, effective_outer_color * star_light_color.rgb * 1.3, star_atmo_tint_strength * 0.7);
		}
		vec3 outer_color = mix(effective_outer_color, biome_tint_color.rgb, biome_tint_intensity * 0.4);
		COLOR = vec4(outer_color, outer_atmosphere * atmosphere_color.a) * COLOR;
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
}
