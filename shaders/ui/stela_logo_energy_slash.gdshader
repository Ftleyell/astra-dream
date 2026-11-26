shader_type canvas_item;
render_mode blend_add;

// Tajo energético diagonal por delante de "STELA" con plasma animado,
// núcleo blanco incandescente, aura magenta/violeta y estelas cian en los extremos.

uniform float angle_deg : hint_range(-60.0, 60.0) = -27.0;
uniform float flow_speed : hint_range(0.0, 8.0) = 1.90;
uniform float intensity : hint_range(0.0, 3.0) = 1.15;
uniform float cut_progress : hint_range(0.0, 1.0) = 1.0;
uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;

uniform vec4 core_color : source_color = vec4(1.0, 0.92, 1.0, 1.0);
uniform vec4 mid_color : source_color = vec4(0.76, 0.22, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.14, 0.88, 1.0, 1.0);

float _hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float _noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(_hash(i), _hash(i + vec2(1.0, 0.0)), u.x),
		mix(_hash(i + vec2(0.0, 1.0)), _hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	// Leve desplazamiento vertical para cruzar exactamente por el tercio medio de "STELA"
	p.y += 0.035;

	float rad = radians(angle_deg);
	float c = cos(rad);
	float s = sin(rad);
	vec2 rp = vec2(p.x * c - p.y * s, p.x * s + p.y * c);

	// Rango de corte animado (de izquierda-abajo hacia derecha-arriba)
	float along = rp.x + 0.5;
	float cut_mask = 1.0 - smoothstep(max(0.0, cut_progress - 0.10), cut_progress + 0.02, along);
	float taper_len = 1.0 - smoothstep(0.12, 0.50, abs(rp.x));
	if (taper_len <= 0.001 || cut_mask <= 0.001) {
		discard;
	}

	// Curva sutil de tajo + turbulencia de plasma fluyendo
	float curve_y = rp.y - 0.022 * sin(rp.x * 4.2);
	float plasma_n = _noise(vec2(rp.x * 11.0 - TIME * flow_speed * 2.4, curve_y * 28.0));
	float plasma_n2 = _noise(vec2(rp.x * 22.0 - TIME * flow_speed * 3.8, curve_y * 42.0 + 3.1));

	// Grosor afilado en las puntas y ancho en el centro + estela de chispas
	float half_w = mix(0.002, 0.024, pow(taper_len, 0.75)) * (0.85 + 0.30 * plasma_n);
	float d = abs(curve_y + (plasma_n - 0.5) * 0.007 * taper_len);

	float core_w = exp(-pow(d / max(half_w * 0.26, 0.0015), 2.0));
	float mid_w = exp(-pow(d / max(half_w * 0.95, 0.004), 1.65)) * (0.78 + 0.35 * plasma_n2);
	float aura_w = exp(-pow(d / max(half_w * 2.6, 0.010), 1.4)) * (0.42 + 0.30 * plasma_n);

	// Puntas dentadas cian hacia los extremos
	float tip_spurs = smoothstep(0.16, 0.44, abs(rp.x)) * (1.0 - smoothstep(0.44, 0.51, abs(rp.x)));
	float spur_streaks = exp(-pow(abs(curve_y) / 0.028, 1.3)) * tip_spurs * (0.55 + 0.45 * plasma_n2);

	vec3 col = edge_color.rgb * (aura_w * 0.85 + spur_streaks * 1.15)
		+ mid_color.rgb * (mid_w * 1.35)
		+ core_color.rgb * (core_w * 1.65);

	float out_alpha = clamp((core_w + mid_w * 0.85 + aura_w * 0.55 + spur_streaks * 0.65) * taper_len * cut_mask * (1.0 - dissolve_progress) * intensity, 0.0, 1.0);
	COLOR = vec4(col * out_alpha, out_alpha);
}
