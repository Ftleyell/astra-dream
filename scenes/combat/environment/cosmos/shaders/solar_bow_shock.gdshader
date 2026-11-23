shader_type canvas_item;
render_mode blend_add, unshaded;

/**
 * solar_bow_shock.gdshader
 * Frente de choque magnético ("bow-shock interface") entre dos heliopausas solares cercanas (Cosmos Engine v3.2c).
 * +X apunta de Estrella A hacia Estrella B; la frontera choca en arco parabólico suave alrededor de x = 0,
 * con filamentos de viento solar fluyendo hacia +-Y y envelope radial estricto (cero cortes de quad).
 */

uniform float global_time = -1.0;
uniform float seed_phase : hint_range(0.0, 6.2832) = 0.0;
uniform int quality_level : hint_range(0, 2) = 2;

uniform vec4 color_a : source_color = vec4(1.0, 0.78, 0.42, 1.0);
uniform vec4 color_b : source_color = vec4(0.36, 0.82, 1.0, 1.0);
uniform vec4 biome_tint_color : source_color = vec4(0.18, 0.28, 0.55, 1.0);
uniform float curve_sign : hint_range(-1.0, 1.0) = 1.0;
uniform float intensity : hint_range(0.0, 1.5) = 0.58;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 41.9);
	return fract(p.x * p.y);
}

float vnoise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	if (r >= 0.495) {
		discard;
	}

	float t = (global_time >= 0.0) ? global_time : TIME;
	float outer_env = (1.0 - smoothstep(0.28, 0.485, r)) * (1.0 - smoothstep(0.20, 0.46, abs(p.y)));

	float arc_x = (p.y * p.y) * 1.15 * curve_sign;
	float dx = p.x - arc_x;

	float flow_n = vnoise(vec2(dx * 10.0, abs(p.y) * 7.5 - t * 0.42 + seed_phase));
	float fine_n = (quality_level >= 1) ? vnoise(vec2(dx * 22.0 + 3.1, abs(p.y) * 16.0 - t * 0.78)) : flow_n;
	float stream_tex = 0.62 + 0.38 * (flow_n * 0.65 + fine_n * 0.35);

	// Dos frentes de choque acoplados separados por un fino surco magnético central
	float shock_a = exp(-pow((dx + 0.024) / 0.020, 2.0));
	float shock_b = exp(-pow((dx - 0.024) / 0.020, 2.0));
	float sheath_a = exp(-pow((dx + 0.055) / 0.068, 2.0)) * 0.42;
	float sheath_b = exp(-pow((dx - 0.055) / 0.068, 2.0)) * 0.42;
	float spine = exp(-pow(dx / 0.007, 2.0)) * 0.65;

	float ripple_wave = 0.78 + 0.22 * sin(abs(p.y) * 26.0 - t * 1.45 + flow_n * 4.0);

	vec3 ca = mix(color_a.rgb, biome_tint_color.rgb, 0.22);
	vec3 cb = mix(color_b.rgb, biome_tint_color.rgb, 0.22);
	vec3 c_mid = mix(mix(ca, cb, 0.5), vec3(0.95, 0.98, 1.0), 0.42);

	vec3 col = vec3(0.0);
	col += ca * ((shock_a + sheath_a) * stream_tex);
	col += cb * ((shock_b + sheath_b) * stream_tex);
	col += c_mid * (spine * ripple_wave);

	col *= outer_env * ripple_wave * intensity;
	float alpha = clamp(max(col.r, max(col.g, col.b)), 0.0, 1.0);
	if (alpha <= 0.002) {
		discard;
	}
	COLOR = vec4(col, smoothstep(0.0, 0.28, alpha));
}
