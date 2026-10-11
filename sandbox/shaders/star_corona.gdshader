shader_type canvas_item;
render_mode blend_mix, unshaded;

// star_corona.gdshader
// Shader estelar para soles en Cosmos Engine:
// 1. Recorte circular suave y descarte de fondo negro de texturas JPG.
// 2. Ondulaciones de calor / convección térmica y plasma vivo animado.
// 3. Corona radiante exterior con respiración procedural.
// 4. Núcleo incandescente térmico.

uniform sampler2D star_texture : filter_linear_mipmap, repeat_disable;
uniform vec4 star_tint : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float heat_distortion_strength : hint_range(0.0, 0.15) = 0.045;
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.5;
uniform float core_brightness : hint_range(1.0, 3.0) = 1.6;
uniform float corona_intensity : hint_range(0.0, 2.0) = 0.85;
uniform float black_threshold : hint_range(0.01, 0.3) = 0.06;

// Ruido pseudo-estocástico rápido para turbulencia de calor
vec2 heat_turb(vec2 p, float t) {
	float n1 = sin(p.x * 12.0 + t * 2.3) * cos(p.y * 14.0 - t * 1.7);
	float n2 = sin(p.y * 22.0 + t * 3.1) * cos(p.x * 20.0 - t * 2.5);
	return vec2(n1, n2);
}

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 delta = UV - center;
	float dist = length(delta);

	// Si está fuera del rango del quad, descartar inmediatamente
	if (dist > 0.495) {
		discard;
	}

	// Tiempo animado de convección
	float t = TIME * pulse_speed;

	// Distorsión radial y tangencial de calor (mayor cerca del centro y borde del plasma)
	vec2 turb = heat_turb(UV * 2.0, t);
	float heat_falloff = 1.0 - smoothstep(0.0, 0.48, dist);
	vec2 distorted_uv = UV + turb * (heat_distortion_strength * heat_falloff);

	// Muestreo de textura con distorsión térmica
	vec4 tex = texture(star_texture, distorted_uv);

	// Luminancia de la textura para detección de fondo negro
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

	// Máscara radial suave para redondear perfectamente la textura JPG sin esquinas cuadradas
	float radial_mask = smoothstep(0.48, 0.38, dist);

	// Máscara de corte de negros de la textura
	float lum_mask = smoothstep(black_threshold, black_threshold + 0.12, lum);

	float alpha = lum_mask * radial_mask;
	if (alpha <= 0.005) {
		discard;
	}

	// Pulsación térmica lenta de la corona
	float pulse = 1.0 + sin(t * 1.8) * 0.08 + sin(t * 3.7 + dist * 10.0) * 0.04;

	// Núcleo hiper-incandescente (temperatura estelar máxima en el centro)
	float core_factor = smoothstep(0.35, 0.0, dist) * core_brightness;
	vec3 core_white = vec3(1.0, 0.98, 0.92);

	// Corona radiante en el borde exterior del disco estelar
	float rim = smoothstep(0.15, 0.45, dist) * (1.0 - smoothstep(0.42, 0.48, dist));
	vec3 corona_glow = star_tint.rgb * (rim * corona_intensity * pulse);

	// Colorimetría final enriquecida: textura base teñida + corona + núcleo térmico
	vec3 final_color = tex.rgb * star_tint.rgb * pulse;
	final_color = mix(final_color, core_white, core_factor * lum);
	final_color += corona_glow;

	COLOR = vec4(final_color, alpha * star_tint.a);
}
