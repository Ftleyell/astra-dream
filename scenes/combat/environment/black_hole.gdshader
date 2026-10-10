shader_type canvas_item;
render_mode blend_mix;

/**
 * black_hole.gdshader
 *
 * Agujero Negro Supermasivo con Micro-Lente de Einstein y Perspectiva Aérea Profunda:
 * 1. Micro-Lente Tangencial de Einstein:
 *    Corona delgada y calibrada alrededor del horizonte (1.1x - 2.2x radio) que estira
 *    las estrellas lejanas en arcos tangenciales sutiles y tangibles al navegar.
 * 2. Penumbra Gravitacional y Corrimiento al Rojo (Gravitational Redshift):
 *    Borde del horizonte con caída suave y ligero tinte rojo/ámbar oscuro antes de la absorción.
 * 3. Extinción Interestelar y Velo Ambiental:
 *    Baño de polvo cósmico del bioma activo para desaturar y asentar el disco hondo en el vacío.
 * 4. Respiración Térmica Majestuosa (Ciclo cósmico lento).
 */

uniform float event_horizon_radius : hint_range(0.04, 0.35) = 0.115;
uniform float horizon_edge_softness : hint_range(0.002, 0.06) = 0.016;

// Micro-Lente gravitacional focalizada (Einstein Ring)
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float screen_lensing_strength : hint_range(0.0, 3.0) = 1.6;
uniform float screen_lensing_radius : hint_range(0.12, 0.5) = 0.35; // Corona focalizada delgada

// Corrimiento al rojo gravitacional justo antes del horizonte
uniform vec4 redshift_color : source_color = vec4(0.42, 0.08, 0.02, 1.0);

// Velo e integración con el bioma cósmico activo
uniform vec4 biome_tint_color : source_color = vec4(0.18, 0.05, 0.32, 1.0);
uniform float biome_tint_intensity : hint_range(0.0, 1.0) = 0.45;
uniform float ambient_haze_depth : hint_range(0.0, 1.0) = 0.32;

// Curva suave de luminancia y eliminación de fondo negro Rec. 709
uniform float black_cutoff : hint_range(0.01, 0.25) = 0.035;
uniform float black_feather : hint_range(0.01, 0.4) = 0.24;
uniform float radial_fade_start : hint_range(0.25, 0.55) = 0.34;
uniform float radial_fade_end : hint_range(0.40, 0.65) = 0.495;

// Respiración térmica lenta y majestuosa (~12 segundos por ciclo)
uniform float thermal_breath_speed : hint_range(0.1, 2.0) = 0.5;

// Luminancia estándar Rec. 709
float get_luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 delta = UV - center;
	float r = length(delta);

	// 1. DESVANECIMIENTO RADIAL SUAVE EN EL BORDE EXTERIOR
	float outer_falloff = smoothstep(radial_fade_end, radial_fade_start, r);
	float outer_fade = pow(outer_falloff, 1.3);

	// 2. MICRO-LENTE GRAVITACIONAL DE EINSTEIN (Focalizada y Tangencial)
	vec2 screen_offset = vec2(0.0);
	if (r > event_horizon_radius && r < screen_lensing_radius) {
		float lens_norm = (r - event_horizon_radius) / max(screen_lensing_radius - event_horizon_radius, 0.001);
		// Deflexión radial + ligera torsión tangencial (simula arco de Einstein)
		vec2 dir_radial = normalize(delta);
		vec2 dir_tangent = vec2(-dir_radial.y, dir_radial.x);
		
		float pull = pow(1.0 - lens_norm, 1.8) * (screen_lensing_strength * 0.06);
		float twist = pow(1.0 - lens_norm, 2.2) * (screen_lensing_strength * 0.015);
		screen_offset = dir_radial * pull + dir_tangent * twist;
	}
	vec4 lensed_screen = texture(screen_texture, SCREEN_UV + screen_offset);

	// 3. RESPIRACIÓN TÉRMICA MAJESTUOSA DEL DISCO
	float thermal_breath = 1.0 + sin(TIME * thermal_breath_speed) * 0.08;

	// Muestra del asset original
	vec4 src_tex = texture(TEXTURE, UV);
	float lum = get_luminance(src_tex.rgb);
	float luma_alpha = smoothstep(black_cutoff, black_cutoff + black_feather, lum);

	// 4. EXTINCIÓN INTERESTELAR Y PERSPECTIVA AÉREA PROFUNDA
	// El bioma cósmico baña suavemente los tonos medios y oscuros
	vec3 haze_tint = mix(src_tex.rgb, biome_tint_color.rgb * max(lum, 0.12) * 1.4, biome_tint_intensity);
	vec3 natural_disk = mix(src_tex.rgb, haze_tint, 0.50) * thermal_breath;
	natural_disk = mix(natural_disk, biome_tint_color.rgb, ambient_haze_depth * (1.0 - lum));

	// 5. PENUMBRA GRAVITACIONAL Y CORRIMIENTO AL ROJO (Redshift)
	// Borde aterciopelado justo antes de la oscuridad total
	float horizon_edge = smoothstep(event_horizon_radius, event_horizon_radius + horizon_edge_softness, r);
	float redshift_zone = (1.0 - horizon_edge) * smoothstep(event_horizon_radius * 0.7, event_horizon_radius, r);
	
	// La luz de fondo sufriendo redshift en la frontera
	vec3 space_background = mix(redshift_color.rgb * 0.35, lensed_screen.rgb, horizon_edge);
	vec3 space_base = mix(vec3(0.0), space_background, smoothstep(event_horizon_radius * 0.85, event_horizon_radius, r));

	// 6. COMPOSICIÓN DE CAPAS VIVAS:
	// El disco y su fuego reposan sobre la base negra sin tapar el anillo
	vec3 final_rgb = mix(space_base, natural_disk, luma_alpha);

	// Velo sutil frontal de polvo ambiental (8% de nebulosa por delante)
	final_rgb = mix(final_rgb, biome_tint_color.rgb, 0.08 * (1.0 - horizon_edge));

	// 7. ALFA CONTINUO:
	float center_eclipse_alpha = (1.0 - horizon_edge) * outer_fade;
	float disk_alpha = luma_alpha * outer_fade;
	float screen_lens_mask = smoothstep(screen_lensing_radius, event_horizon_radius, r) * outer_fade;

	float final_alpha = max(disk_alpha, max(center_eclipse_alpha, screen_lens_mask));

	COLOR = vec4(final_rgb, clamp(final_alpha, 0.0, 1.0));
}
