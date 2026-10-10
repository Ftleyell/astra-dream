shader_type canvas_item;
render_mode blend_mix;

/**
 * pulsar.gdshader
 *
 * Púlsar Cósmico / Estrella de Neutrones Relativista:
 * 1. Puntas Verticales Suaves (Fade Gradual en Extremos de los Ejes):
 *    - Desvanecimiento cúbico en los extremos verticales (|y|) para eliminar cortes duros.
 * 2. Emisión Viva y Orgánica (Sin sensación de luciérnaga):
 *    - Fusión de múltiples armónicos térmicos continuos que generan un plasma fluido y vivo.
 * 3. Integración Atmosférica Armónica con el Entorno Cósmico:
 *    - La luz y el plasma del haz se tiñen y modulan con el gas del bioma ambiental,
 *      manteniendo la misma jerarquía lumínica que el resto del entorno profundo.
 */

uniform vec2 pulsar_center = vec2(0.5, 0.5);

// Lente gravitacional de pantalla (deforma el cosmos de fondo)
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float screen_lensing_strength : hint_range(0.0, 3.0) = 1.2;
uniform float screen_lensing_radius : hint_range(0.1, 0.5) = 0.32;

// Núcleo central negro (estrella de neutrones opaca)
uniform float core_shadow_radius : hint_range(0.02, 0.20) = 0.075;
uniform float core_shadow_softness : hint_range(0.001, 0.03) = 0.010;

// Parámetros de los conos polares de energía
uniform float cone_tip_width : hint_range(0.001, 0.02) = 0.002;
uniform float cone_spread_angle : hint_range(0.05, 0.6) = 0.28;
uniform float cone_length : hint_range(0.25, 0.55) = 0.44;
uniform float cone_tip_feather : hint_range(0.02, 0.20) = 0.12; // Suavizado gradual en las puntas verticales
uniform float jet_flow_speed : hint_range(0.5, 35.0) = 14.0;

// Rotación rápida del haz del púlsar (giro y precesión hiperactiva)
uniform float beam_spin_speed : hint_range(0.0, 15.0) = 5.2;
uniform float beam_precession_angle : hint_range(0.0, 0.5) = 0.16;

// Capa de destello estroboscópico violento (de transparente a flash deslumbrante)
uniform float strobe_speed : hint_range(1.0, 30.0) = 16.0;
uniform float strobe_intensity : hint_range(0.0, 3.0) = 1.85;

// Latido secundario de plasma térmico
uniform float pulse_speed : hint_range(0.2, 10.0) = 4.5;
uniform float pulse_intensity : hint_range(0.0, 1.5) = 0.35;

// Paleta de radiación del cono
uniform vec4 jet_core_color : source_color = vec4(0.55, 0.96, 1.0, 1.0);
uniform vec4 jet_outer_color : source_color = vec4(0.72, 0.26, 0.98, 1.0);
uniform vec4 jet_focal_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Integración y oclusión con el polvo espacial profundo
uniform vec4 biome_tint_color : source_color = vec4(0.18, 0.05, 0.32, 1.0);
uniform float biome_tint_intensity : hint_range(0.0, 1.0) = 0.60;
uniform float ambient_haze_depth : hint_range(0.0, 1.0) = 0.45;
uniform float dust_occlusion_strength : hint_range(0.0, 1.0) = 0.72; // Cuánto tapa el polvo la emisión lejana
uniform float emission_master_power : hint_range(0.2, 2.5) = 1.45; // Brillo limpio del haz

uniform float black_cutoff : hint_range(0.01, 0.25) = 0.035;
uniform float black_feather : hint_range(0.01, 0.3) = 0.16;
uniform float radial_fade_start : hint_range(0.30, 0.55) = 0.36;
uniform float radial_fade_end : hint_range(0.42, 0.65) = 0.49;

// Luminancia estándar Rec. 709
float get_luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 delta = UV - pulsar_center;
	float r = length(delta);

	// Desvanecimiento suave en los bordes perimétricos del sprite
	float outer_falloff = smoothstep(radial_fade_end, radial_fade_start, r);
	float outer_fade = pow(outer_falloff, 1.3);

	// 1. LENTE GRAVITACIONAL SOBRE LA PANTALLA (Micro-curvatura tangencial)
	vec2 screen_offset = vec2(0.0);
	if (r > core_shadow_radius && r < screen_lensing_radius) {
		float lens_norm = (r - core_shadow_radius) / max(screen_lensing_radius - core_shadow_radius, 0.001);
		vec2 dir_radial = normalize(delta);
		vec2 dir_tangent = vec2(-dir_radial.y, dir_radial.x);
		
		float pull = pow(1.0 - lens_norm, 1.8) * (screen_lensing_strength * 0.045);
		float twist = pow(1.0 - lens_norm, 2.0) * (screen_lensing_strength * 0.012);
		screen_offset = dir_radial * pull + dir_tangent * twist;
	}
	vec4 lensed_screen = texture(screen_texture, SCREEN_UV + screen_offset);

	// Muestra del asset original y mapa de densidad de polvo cósmico
	vec4 src_tex = texture(TEXTURE, UV);
	float lum = get_luminance(src_tex.rgb);
	float luma_alpha = smoothstep(black_cutoff, black_cutoff + black_feather, lum);

	// Estructura de filamentos y nubes de polvo interestelar
	float dust_mask = clamp(lum * 1.5 + (1.0 - smoothstep(0.0, 0.25, r)) * 0.2, 0.0, 1.0);
	float dust_absorption = mix(0.25, 1.0, dust_mask);

	// 2. GEOMETRÍA CÓNICA CON ROTACIÓN DINÁMICA ULTRA-RÁPIDA Y PRECESIÓN
	float beam_angle = sin(TIME * beam_spin_speed) * beam_precession_angle;
	float cos_b = cos(beam_angle);
	float sin_b = sin(beam_angle);
	vec2 rot_delta = vec2(
		delta.x * cos_b - delta.y * sin_b,
		delta.x * sin_b + delta.y * cos_b
	);

	// Modulación 3D en perspectiva del haz giratorio
	float sweep_perspective = 0.70 + 0.30 * cos(TIME * beam_spin_speed * 2.0);

	float dist_x = abs(rot_delta.x);
	float dist_y = abs(rot_delta.y);

	float cone_shape_mask = 0.0;
	float flash_layer_energy = 0.0;
	float fast_plasma_energy = 0.0;
	vec3 cone_color = vec3(0.0);
	vec3 flash_color = vec3(0.0);

	if (dist_y >= core_shadow_radius * 0.95) {
		float y_from_edge = dist_y - (core_shadow_radius * 0.95);
		float current_cone_half_width = cone_tip_width + (y_from_edge * cone_spread_angle);

		// Perfil transversal gaussiano aterciopelado
		float cone_profile = exp(-pow(dist_x / max(current_cone_half_width, 0.001), 2.0) * 3.2);
		
		// Desvanecimiento longitudinal con fade suave en las puntas verticales
		float tip_fade = smoothstep(cone_length, cone_length - cone_tip_feather, dist_y);
		float core_takeoff = smoothstep(core_shadow_radius * 0.90, core_shadow_radius * 1.15, dist_y);
		float cone_longitudinal = tip_fade * core_takeoff;
		
		cone_shape_mask = cone_profile * cone_longitudinal;

		// -------------------------------------------------------------
		// CAPA A: DESTELLO / FLASH ESTROBOSCÓPICO (De transparente a fogonazo)
		// -------------------------------------------------------------
		// Pulso no-lineal ultra cortante: pasa la mayor parte del tiempo casi invisible y explota en un pico
		float raw_strobe = pow(max(sin(TIME * strobe_speed), 0.0), 7.0);
		// Onda armónica secundaria para que el destello no sea mecánico sino caótico y violento
		float strobe_burst = raw_strobe + pow(max(sin(TIME * (strobe_speed * 1.41) + 1.7), 0.0), 9.0) * 0.65;
		flash_layer_energy = cone_shape_mask * strobe_burst * strobe_intensity * sweep_perspective;
		flash_color = mix(jet_focal_color.rgb, vec3(1.0, 1.0, 1.0), 0.85);

		// -------------------------------------------------------------
		// CAPA B: PLASMA HIPERCINÉTICO ULTRA-RÁPIDO POR ENCIMA
		// -------------------------------------------------------------
		float pulse_base = 1.0 + (sin(TIME * pulse_speed) * 0.35 + sin(TIME * (pulse_speed * 1.73) + 1.2) * 0.20) * pulse_intensity;
		float turbulence = sin(dist_y * 52.0 - TIME * jet_flow_speed) * 0.5 + 0.5;
		float micro_plasma = sin(dist_x * 120.0 + TIME * 8.0) * 0.15;

		fast_plasma_energy = cone_shape_mask * (0.85 + 0.35 * turbulence + micro_plasma) * pulse_base * sweep_perspective;

		// Gradiente cromático integrado
		float lateral_norm = clamp(dist_x / max(current_cone_half_width, 0.001), 0.0, 1.0);
		cone_color = mix(jet_focal_color.rgb, jet_core_color.rgb, smoothstep(0.0, 0.45, lateral_norm));
		cone_color = mix(cone_color, jet_outer_color.rgb, smoothstep(0.45, 1.0, lateral_norm));
		
		// Fusión con el bioma ambiental
		cone_color = mix(cone_color, biome_tint_color.rgb * 1.15, biome_tint_intensity * 0.70);
	}

	// Mascarilla envolvente para hacer transparente la textura de fondo en toda la trayectoria del haz
	float sweep_envelope_width = cone_tip_width + (max(abs(delta.y) - core_shadow_radius * 0.95, 0.0) * (cone_spread_angle + beam_precession_angle * 1.1));
	float sweep_x_falloff = exp(-pow(abs(delta.x) / max(sweep_envelope_width, 0.001), 2.0) * 2.2);
	float sweep_y_fade = smoothstep(cone_length, cone_length - cone_tip_feather, abs(delta.y)) * smoothstep(core_shadow_radius * 0.85, core_shadow_radius * 1.10, abs(delta.y));
	float beam_clearance_mask = clamp(max(cone_shape_mask, sweep_x_falloff * sweep_y_fade * 0.85), 0.0, 1.0);

	// 4. EXTINCIÓN INTERESTELAR
	float dust_extinction = mix(1.0, (1.0 - dust_absorption * 0.65), dust_occlusion_strength);
	float light_scatter = dust_absorption * dust_occlusion_strength * 0.35;
	
	// Fusión de Capa A (Destello de alta luminancia) + Capa B (Plasma animado ultra-rápido)
	vec3 total_cone_emission = (cone_color * fast_plasma_energy + flash_color * flash_layer_energy) * emission_master_power * dust_extinction;
	
	// El gas se retroilumina levemente por el paso del haz sin sobrebrillar
	vec3 scattered_light = biome_tint_color.rgb * (fast_plasma_energy + flash_layer_energy * 0.5) * light_scatter * 0.60;

	// 5. INTEGRACIÓN ATMOSFÉRICA PROFUNDA
	vec3 haze_tint = mix(src_tex.rgb, biome_tint_color.rgb * max(lum, 0.15) * 1.35, biome_tint_intensity);
	vec3 natural_asset = mix(src_tex.rgb, haze_tint, 0.60);
	natural_asset = mix(natural_asset, biome_tint_color.rgb, ambient_haze_depth * (1.0 - lum));

	// 6. COMPOSICIÓN DE CAPAS VIVAS:
	float cleared_luma_alpha = luma_alpha * (1.0 - beam_clearance_mask);

	float core_edge = smoothstep(core_shadow_radius, core_shadow_radius + core_shadow_softness, r);
	vec3 space_base = mix(vec3(0.0), lensed_screen.rgb, core_edge);

	vec3 asset_layer = mix(space_base, natural_asset, cleared_luma_alpha);
	// Luz final del púlsar violento: Fondo limpio + Destellos estroboscópicos + Plasma rápido + Dispersión
	vec3 final_rgb = asset_layer + total_cone_emission + scattered_light;

	// Velo cósmico ambiental superior para asentar el objeto definitivamente en el fondo cósmico
	final_rgb = mix(final_rgb, biome_tint_color.rgb, ambient_haze_depth * 0.25 * (1.0 - core_edge));

	// 7. ALFA CONTINUO:
	float center_eclipse_alpha = (1.0 - core_edge) * outer_fade;
	float asset_alpha = cleared_luma_alpha * outer_fade;
	float cone_combined_energy = fast_plasma_energy + flash_layer_energy;
	float cone_alpha = clamp(cone_combined_energy * 0.95 * dust_extinction, 0.0, 1.0) * outer_fade;
	float screen_lens_mask = smoothstep(screen_lensing_radius, core_shadow_radius, r) * outer_fade;

	float final_alpha = max(max(asset_alpha, cone_alpha), max(center_eclipse_alpha, screen_lens_mask));

	COLOR = vec4(final_rgb, clamp(final_alpha, 0.0, 1.0));
}
