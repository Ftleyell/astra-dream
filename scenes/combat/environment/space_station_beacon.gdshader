shader_type canvas_item;

/**
 * space_station_beacon.gdshader
 *
 * Shader diegético de balizas de navegación estroboscópicas para megaestructuras espaciales.
 * Simula destellos rítmicos de señalización (rojo, blanco, ámbar o verde) en las antenas,
 * astilleros y mástiles perimétricos de las estaciones espaciales.
 */

// Baliza 1 (por defecto: Mástil Superior)
uniform vec2 beacon_1_pos = vec2(0.5, 0.2);
uniform vec4 beacon_1_color : source_color = vec4(1.0, 0.15, 0.15, 1.0);
uniform float beacon_1_period : hint_range(0.2, 5.0) = 1.2;
uniform float beacon_1_phase_offset : hint_range(0.0, 5.0) = 0.0;
uniform float beacon_1_radius : hint_range(0.002, 0.05) = 0.018;

// Baliza 2 (por defecto: Extremo Izquierdo / Babor)
uniform vec2 beacon_2_pos = vec2(0.06, 0.5);
uniform vec4 beacon_2_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float beacon_2_period : hint_range(0.2, 5.0) = 0.85;
uniform float beacon_2_phase_offset : hint_range(0.0, 5.0) = 0.3;
uniform float beacon_2_radius : hint_range(0.002, 0.05) = 0.016;

// Baliza 3 (por defecto: Extremo Derecho / Estribor)
uniform vec2 beacon_3_pos = vec2(0.95, 0.5);
uniform vec4 beacon_3_color : source_color = vec4(0.2, 1.0, 0.4, 1.0);
uniform float beacon_3_period : hint_range(0.2, 5.0) = 1.4;
uniform float beacon_3_phase_offset : hint_range(0.0, 5.0) = 0.6;
uniform float beacon_3_radius : hint_range(0.002, 0.05) = 0.016;

// Baliza 4 (por defecto: Mástil Inferior / Bahía)
uniform vec2 beacon_4_pos = vec2(0.5, 0.8);
uniform vec4 beacon_4_color : source_color = vec4(1.0, 0.15, 0.15, 1.0);
uniform float beacon_4_period : hint_range(0.2, 5.0) = 1.2;
uniform float beacon_4_phase_offset : hint_range(0.0, 5.0) = 0.6;
uniform float beacon_4_radius : hint_range(0.002, 0.05) = 0.018;

// Intensidad global de destello
uniform float beacon_intensity : hint_range(0.0, 5.0) = 2.2;

// Perspectiva Aérea Cósmica e Iluminación Solar Direccional Unificada
uniform vec4 ambient_haze_color : source_color = vec4(0.06, 0.09, 0.18, 1.0);
uniform float ambient_haze_intensity : hint_range(0.0, 1.0) = 0.20;
uniform float distance_desaturation : hint_range(0.0, 1.0) = 0.08;
uniform vec2 light_direction = vec2(0.85, -0.52);
uniform vec4 star_light_color : source_color = vec4(1.0, 0.90, 0.72, 1.0);
uniform vec4 biome_tint_color : source_color = vec4(0.18, 0.28, 0.55, 1.0);
uniform float eclipse_shadow : hint_range(0.0, 1.0) = 0.0;

varying vec2 v_world_dir;

void vertex() {
	v_world_dir = (MODEL_MATRIX * vec4(VERTEX, 0.0, 0.0)).xy;
}


float calculate_strobe_pulse(float time, float period, float phase_offset) {
	if (period <= 0.001) {
		return 0.0;
	}
	float t = mod(time + phase_offset, period);
	// Pulso estroboscópico de aviación con doble flash rápido (0.0s y 0.18s)
	float p1 = smoothstep(0.08, 0.0, t);
	float p2 = smoothstep(0.08, 0.0, abs(t - 0.16));
	return max(p1, p2 * 0.75);
}

vec3 evaluate_beacon(vec2 uv, vec2 pos, vec4 color, float pulse, float radius) {
	if (color.a <= 0.001 || pulse <= 0.001) {
		return vec3(0.0);
	}
	float d = length(uv - pos);
	if (d > radius * 2.5) {
		return vec3(0.0);
	}
	// Núcleo brillante centrado
	float core = smoothstep(radius * 0.35, 0.0, d);
	// Halo difuso exterior
	float halo = exp(-d / max(radius * 0.65, 0.0001));
	float glow = core * 2.0 + halo * 1.2;
	return color.rgb * glow * pulse * beacon_intensity;
}

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);

	// Cálculo del pulso temporal de cada baliza
	float p1 = calculate_strobe_pulse(TIME, beacon_1_period, beacon_1_phase_offset);
	float p2 = calculate_strobe_pulse(TIME, beacon_2_period, beacon_2_phase_offset);
	float p3 = calculate_strobe_pulse(TIME, beacon_3_period, beacon_3_phase_offset);
	float p4 = calculate_strobe_pulse(TIME, beacon_4_period, beacon_4_phase_offset);

	// Acumulación lumínica de balizas
	vec3 beacon_light = vec3(0.0);
	beacon_light += evaluate_beacon(UV, beacon_1_pos, beacon_1_color, p1, beacon_1_radius);
	beacon_light += evaluate_beacon(UV, beacon_2_pos, beacon_2_color, p2, beacon_2_radius);
	beacon_light += evaluate_beacon(UV, beacon_3_pos, beacon_3_color, p3, beacon_3_radius);
	beacon_light += evaluate_beacon(UV, beacon_4_pos, beacon_4_color, p4, beacon_4_radius);

	float beacon_alpha = clamp(length(beacon_light) * 0.5, 0.0, 1.0);

	// Perspectiva aérea cósmica + iluminación direccional 2.5D + eclipse orbital
	vec3 station_rgb = base_color.rgb;
	if (base_color.a > 0.01) {
		float luma = dot(station_rgb, vec3(0.299, 0.587, 0.114));
		station_rgb = mix(station_rgb, vec3(luma), distance_desaturation);

		vec2 ldir = normalize(light_direction + vec2(0.0001, 0.0));
		vec2 wdir = (length(v_world_dir) > 0.0001) ? normalize(v_world_dir) : vec2(0.0, -1.0);
		float facing = dot(wdir, ldir);
		float shade = smoothstep(-0.60, 0.55, facing) * (1.0 - eclipse_shadow * 0.78);

		// Conservar parcialmente ventanas/reactores auto-iluminados sin apagarlos en sombra
		float emissive_keep = smoothstep(0.62, 0.96, max(base_color.r, max(base_color.g, base_color.b))) * 0.65;
		vec3 key_col = mix(vec3(1.0), star_light_color.rgb, 0.45);
		vec3 lit_station = station_rgb * mix(vec3(0.22, 0.24, 0.36), key_col * 1.12, max(shade, emissive_keep));
		float rim_crescent = smoothstep(0.35, 0.92, facing) * (1.0 - eclipse_shadow * 0.85) * luma;
		lit_station += star_light_color.rgb * rim_crescent * 0.24;

		vec3 haze_col = mix(ambient_haze_color.rgb, biome_tint_color.rgb * 0.65, 0.45);
		float shadow_mask = 1.0 - clamp(shade * 0.85 + luma * 0.25, 0.0, 1.0);
		station_rgb = mix(lit_station, haze_col, ambient_haze_intensity * (0.28 + shadow_mask * 0.72));
	}

	// Composición final: cuerpo difuminado a la distancia + balizas nítidas
	vec3 final_rgb = station_rgb + beacon_light;
	float final_alpha = max(base_color.a, beacon_alpha);

	COLOR = vec4(final_rgb, final_alpha);
}
