shader_type canvas_item;
render_mode blend_add, unshaded;

// comet_tail.gdshader
// Cometa elíptico Anime Space-Opera con núcleo helado, coma difusa,
// cola de plasma iónico anti-solar filamentosa y cola de polvo cálida curva.
// El núcleo se ubica en UV = (0.18, 0.50); +X apunta en dirección anti-solar.

uniform vec4 core_color : source_color = vec4(0.92, 0.98, 1.0, 1.0);
uniform vec4 ion_color : source_color = vec4(0.40, 0.86, 1.0, 1.0);
uniform vec4 dust_color : source_color = vec4(1.0, 0.78, 0.54, 1.0);
uniform float solar_proximity : hint_range(0.0, 1.0) = 0.5;
uniform float dust_curve_angle : hint_range(-0.65, 0.65) = 0.14;
uniform float global_time = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
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
	float t = (global_time > 0.001) ? global_time : TIME;
	vec2 nucleus = vec2(0.18, 0.50);
	vec2 rel = UV - nucleus;

	// Máscara de borde para evitar cualquier corte rectangular en el quad
	float box_env = smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.90, 0.99, UV.x))
		* smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.88, 0.99, UV.y));
	if (box_env <= 0.002) {
		discard;
	}

	float dist_n = length(vec2(rel.x, rel.y * 0.58));
	float core_pin = exp(-dist_n * 54.0) * 1.65;
	float star_flare = (exp(-abs(rel.x) * 46.0) * exp(-abs(rel.y) * 9.0) + exp(-abs(rel.y) * 46.0) * exp(-abs(rel.x) * 9.0)) * 0.65;
	float coma = exp(-dist_n * 16.0) * (0.58 + solar_proximity * 0.48);

	// Longitud dinámica según cercanía a la estrella
	float ion_len = mix(0.36, 0.78, solar_proximity);
	float dust_len = mix(0.28, 0.62, solar_proximity);

	// 1. Cola de plasma iónico (ligeramente deflectada por viento solar respecto a la trayectoria, +X = atrás orbital)
	float ion_x = clamp(rel.x / ion_len, 0.0, 1.0);
	float ion_y = rel.y - (dust_curve_angle * ion_x * 0.55);
	float ion_gate = smoothstep(-0.015, 0.030, rel.x) * pow(max(1.0 - ion_x, 0.0), 1.32);
	float ion_width = mix(0.036, 0.110, ion_x);
	float ion_core_line = exp(-pow(ion_y / max(ion_width * 0.46, 0.004), 2.0));
	float ion_halo = exp(-pow(ion_y / max(ion_width * 1.45, 0.008), 2.0));

	float stream_noise = value_noise(vec2(rel.x * 16.0 - t * 2.4, ion_y * 42.0 + 3.1));
	float ion_filaments = mix(0.62, 1.38, stream_noise);
	float ion_tail = (ion_core_line * 0.85 + ion_halo * 0.52) * ion_gate * ion_filaments;

	// 2. Cola de polvo cálida (centrada y ceñida sobre la estela orbital trasera)
	float dust_x = clamp(rel.x / dust_len, 0.0, 1.0);
	float dust_curve_y = rel.y - (dust_curve_angle * dust_x * dust_x * 0.16);
	float dust_gate = smoothstep(-0.01, 0.045, rel.x) * pow(max(1.0 - dust_x, 0.0), 1.58);
	float dust_width = mix(0.056, 0.19, pow(dust_x, 0.82));
	float dust_soft = exp(-pow(dust_curve_y / max(dust_width, 0.008), 2.0));
	float dust_noise = value_noise(vec2(rel.x * 10.0 - t * 1.1 + 7.7, dust_curve_y * 20.0));
	float dust_tail = dust_soft * dust_gate * mix(0.80, 1.24, dust_noise);

	vec3 rgb = core_color.rgb * (core_pin + star_flare)
		+ mix(core_color.rgb, ion_color.rgb, 0.50) * coma
		+ ion_color.rgb * ion_tail * (0.78 + solar_proximity * 0.85)
		+ dust_color.rgb * dust_tail * (0.58 + solar_proximity * 0.68);

	float alpha = clamp((core_pin + star_flare * 0.8 + coma + ion_tail * 0.85 + dust_tail * 0.62) * box_env, 0.0, 1.0);
	if (alpha <= 0.004) {
		discard;
	}
	COLOR = vec4(rgb * box_env, alpha);
}
