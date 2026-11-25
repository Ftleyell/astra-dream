shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, fog_disabled;

// Domo espacial 3D profundo para Estación Astral v2 (cielo visible en todas direcciones sin depender de BG_SKY).

uniform vec4 zenith_color : source_color = vec4(0.035, 0.042, 0.105, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.085, 0.048, 0.155, 1.0);
uniform vec4 nebula_crimson : source_color = vec4(0.76, 0.16, 0.42, 1.0);
uniform vec4 nebula_cyan : source_color = vec4(0.12, 0.56, 0.88, 1.0);
uniform float nebula_intensity : hint_range(0.0, 2.0) = 0.95;
uniform float star_brightness : hint_range(0.0, 3.0) = 1.95;

varying vec3 v_world_dir;

void vertex() {
	v_world_dir = normalize((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

float hash31(vec3 p) {
	p = fract(p * vec3(443.8975, 397.2973, 491.1871));
	p += dot(p, p.yxz + 19.19);
	return fract((p.x + p.y) * p.z);
}

float star_layer(vec3 dir, float scale_v, float threshold) {
	vec3 g = floor(dir * scale_v);
	vec3 f = fract(dir * scale_v) - 0.5;
	float rnd = hash31(g);
	if (rnd < threshold) {
		return 0.0;
	}
	vec3 jitter = vec3(hash31(g + 1.3), hash31(g + 7.1), hash31(g + 13.7)) - 0.5;
	float d = length(f - jitter * 0.40);
	float tw = 0.72 + 0.28 * sin(TIME * (1.2 + rnd * 3.0) + rnd * 6.2831);
	return smoothstep(0.20, 0.02, d) * tw;
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

void fragment() {
	vec3 dir = normalize(v_world_dir);
	float horiz = pow(1.0 - clamp(abs(dir.y), 0.0, 1.0), 1.7);
	vec3 col = mix(zenith_color.rgb, horizon_color.rgb, horiz);

	float band_coord = dir.y * 0.75 + dir.x * 0.42 - dir.z * 0.25;
	float band = exp(-band_coord * band_coord * 4.5);
	float n1 = value_noise(dir * 3.2 + vec3(0.0, TIME * 0.006, 0.0));
	float n2 = value_noise(dir * 6.8 - vec3(TIME * 0.004, 0.0, 0.0));
	float cloud = clamp(n1 * 0.62 + n2 * 0.38, 0.0, 1.0);

	col += nebula_crimson.rgb * band * cloud * nebula_intensity * 0.45;
	col += nebula_cyan.rgb * band * (1.0 - cloud * 0.55) * nebula_intensity * 0.36;
	col += mix(nebula_cyan.rgb, nebula_crimson.rgb, n2) * horiz * 0.16;

	float s_small = star_layer(dir, 140.0, 0.962);
	float s_mid = star_layer(dir + vec3(0.31), 78.0, 0.976);
	float s_bright = star_layer(dir + vec3(0.73), 38.0, 0.986);
	vec3 star_tint = mix(vec3(0.78, 0.92, 1.0), vec3(1.0, 0.85, 0.75), n1);
	col += star_tint * (s_small * 0.45 + s_mid * 0.85 + s_bright * 1.45) * star_brightness;

	ALBEDO = col;
}
