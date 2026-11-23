shader_type canvas_item;
render_mode blend_add, unshaded;

/**
 * derelict_plasma_arcs.gdshader
 * Aura dramática de fugas de plasma, arcos eléctricos chisporroteantes y pulso SOS para Cementerios de Flotas.
 */

uniform float global_time = -1.0;
uniform float seed_phase : hint_range(0.0, 6.2832) = 0.0;
uniform int quality_level : hint_range(0, 2) = 2;

uniform vec4 plasma_color : source_color = vec4(0.28, 0.78, 1.0, 1.0);
uniform vec4 distress_color : source_color = vec4(1.0, 0.24, 0.18, 1.0);
uniform vec4 biome_tint_color : source_color = vec4(0.18, 0.28, 0.55, 1.0);
uniform float overall_intensity : hint_range(0.0, 2.5) = 1.15;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	if (r >= 0.495) {
		discard;
	}

	float t = (global_time >= 0.0) ? global_time : TIME;
	float ang = atan(p.y, p.x);
	float outer_env = 1.0 - smoothstep(0.32, 0.488, r);

	// Nube de refrigerante/plasma fugado alrededor del casco roto
	vec2 uv_gas = p * 7.2 + vec2(cos(seed_phase), sin(seed_phase)) * 4.0;
	float n1 = vnoise(uv_gas + vec2(t * 0.08, -t * 0.05));
	float n2 = (quality_level >= 1) ? vnoise(uv_gas * 2.1 - vec2(t * 0.12, t * 0.07)) : n1;
	float gas = smoothstep(0.24, 0.84, n1 * 0.62 + n2 * 0.38);
	float gas_env = smoothstep(0.03, 0.13, r) * (1.0 - smoothstep(0.26, 0.45, r));

	// 3 canales de arcos eléctricos en fase escalonada para descargas siempre legibles
	float arc_total = 0.0;
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		float phase_k = seed_phase + fk * 2.09439;
		float raw_wave = 0.5 + 0.5 * sin(t * (2.4 + fk * 0.7) + phase_k);
		float pulse = pow(raw_wave, 3.5);
		float sector_ang = seed_phase * 0.7 + fk * 2.09439 + sin(t * 0.9 + fk * 1.4) * 0.45;
		float da = abs(atan(sin(ang - sector_ang), cos(ang - sector_ang)));
		float jitter = (vnoise(vec2(r * 24.0 + t * 4.5, fk * 7.3)) - 0.5) * 0.15;
		float bolt = exp(-abs(da + jitter - 0.11 * sin(r * 18.0 + fk)) * 30.0);
		float r_win = smoothstep(0.06, 0.14, r) * (1.0 - smoothstep(0.26, 0.40, r));
		arc_total += bolt * r_win * (0.28 + 0.72 * pulse);
	}

	// Doble destello SOS de baliza de emergencia + doble anillo radar fragmentado
	float sos_t = mod(t + seed_phase, 2.4);
	float s1 = smoothstep(0.16, 0.0, abs(sos_t - 0.18));
	float s2 = smoothstep(0.16, 0.0, abs(sos_t - 0.46));
	float sos_pulse = max(s1, s2 * 0.85);
	float sos_glow = exp(-r * 6.8) * (0.34 + 0.66 * sos_pulse);

	float broken_inner = exp(-pow((r - 0.25) / 0.0055, 2.0)) * smoothstep(0.22, 0.72, sin(ang * 6.0 - t * 0.18 + seed_phase));
	float broken_outer = exp(-pow((r - 0.36) / 0.0055, 2.0)) * smoothstep(0.30, 0.78, sin(ang * 9.0 + t * 0.12 + seed_phase));

	vec3 c_plasma = mix(plasma_color.rgb, biome_tint_color.rgb, 0.22);
	vec3 c_sos = mix(distress_color.rgb, vec3(1.0, 0.52, 0.20), 0.24);

	vec3 col = vec3(0.0);
	col += mix(c_plasma, c_sos, 0.22) * (gas * gas_env * 0.68);
	col += mix(c_plasma, vec3(0.95, 0.99, 1.0), 0.62) * (arc_total * 1.15);
	col += c_sos * (sos_glow * 0.78 + (broken_inner + broken_outer * 0.75) * (0.22 + 0.34 * sos_pulse));

	col *= outer_env * overall_intensity;
	float alpha = clamp(max(col.r, max(col.g, col.b)), 0.0, 1.0);
	COLOR = vec4(col, alpha);
}
