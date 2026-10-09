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

// Perspectiva Aérea Cósmica (Ofuscación de distancia, velo ambiental y levantamiento de sombras)
uniform vec4 ambient_haze_color : source_color = vec4(0.06, 0.09, 0.18, 1.0);
uniform float ambient_haze_intensity : hint_range(0.0, 1.0) = 0.38;
uniform float distance_desaturation : hint_range(0.0, 1.0) = 0.25;


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

	// Perspectiva aérea cósmica: fundir sombras con la niebla ambiental para disimular imperfecciones
	vec3 station_rgb = base_color.rgb;
	if (base_color.a > 0.01) {
		float luma = dot(station_rgb, vec3(0.299, 0.587, 0.114));
		station_rgb = mix(station_rgb, vec3(luma), distance_desaturation);

		float shadow_mask = 1.0 - clamp(luma * 1.6, 0.0, 1.0);
		station_rgb = mix(station_rgb, ambient_haze_color.rgb, ambient_haze_intensity * (0.35 + shadow_mask * 0.65));
	}

	// Composición final: cuerpo difuminado a la distancia + balizas nítidas
	vec3 final_rgb = station_rgb + beacon_light;
	float final_alpha = max(base_color.a, beacon_alpha);

	COLOR = vec4(final_rgb, final_alpha);
}
