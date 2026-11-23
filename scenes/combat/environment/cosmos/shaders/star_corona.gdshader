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
uniform float core_brightness : hint_range(0.8, 3.0) = 1.25;
uniform float corona_intensity : hint_range(0.0, 2.0) = 0.85;
uniform float black_threshold : hint_range(0.01, 0.3) = 0.05;
uniform float anamorphic_flare_strength : hint_range(0.0, 1.5) = 0.10;
uniform float anamorphic_flare_sharpness : hint_range(2.0, 24.0) = 14.0;
uniform float corona_cel_ring_strength : hint_range(0.0, 1.5) = 0.14;
uniform bool dark_core_mode = false;

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
	if (dist > 0.496) {
		discard;
	}

	// Tiempo animado de convección
	float t = TIME * pulse_speed;

	// Distorsión radial y tangencial de calor suave
	vec2 turb = heat_turb(UV * 2.0, t);
	float heat_falloff = 1.0 - smoothstep(0.0, 0.48, dist);
	vec2 distorted_uv = UV + turb * (heat_distortion_strength * heat_falloff);

	// Muestreo de textura con distorsión térmica
	vec4 tex = texture(star_texture, distorted_uv);

	// Luminancia de la textura para detección de fondo negro
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

	// Máscara radial amplia para no recortar prominencias ni arcos de agujero negro/magnetar
	float radial_mask = smoothstep(0.496, 0.415, dist);

	// Máscara de corte de negros + halo atmosférico suave alrededor del disco solar
	float lum_mask = smoothstep(black_threshold, black_threshold + 0.12, lum);
	float soft_atmo = exp(-dist * dist * 13.5) * 0.55 * (1.0 - smoothstep(0.40, 0.495, dist));
	float horiz_flare = exp(-abs(delta.y) * anamorphic_flare_sharpness * 3.2) * exp(-abs(delta.x) * 5.2);
	float vert_flare = exp(-abs(delta.x) * anamorphic_flare_sharpness * 3.8) * exp(-abs(delta.y) * 6.5) * 0.55;
	float flare_mask = (horiz_flare + vert_flare) * radial_mask * anamorphic_flare_strength;

	float alpha = max(lum_mask * radial_mask, max(soft_atmo * 0.45, flare_mask * 0.55));
	float horizon_occlude = 0.0;
	if (dark_core_mode) {
		horizon_occlude = 1.0 - smoothstep(0.175, 0.215, dist);
		alpha = max(alpha, horizon_occlude);
	}
	if (alpha <= 0.005) {
		discard;
	}

	// Pulsación térmica lenta de la corona
	float pulse = 1.0 + sin(t * 1.8) * 0.06 + sin(t * 3.7 + dist * 10.0) * 0.03;

	// Brillo HDR central real (supera el hombro gris de AgX hacia incandescencia limpia con bloom sutil)
	float core_factor = pow(smoothstep(0.25, 0.0, dist), 1.65) * core_brightness;
	float hdr_heart = pow(smoothstep(0.17, 0.0, dist), 2.3) * core_brightness;
	vec3 core_white = mix(star_tint.rgb, vec3(1.0, 0.99, 0.96), 0.78);

	// Corona radiante + halo atmosférico HDR
	float rim = smoothstep(0.18, 0.45, dist) * (1.0 - smoothstep(0.42, 0.49, dist));
	float cel_ring = smoothstep(0.28, 0.34, dist) * (1.0 - smoothstep(0.35, 0.42, dist)) * corona_cel_ring_strength;
	vec3 corona_glow = star_tint.rgb * ((rim * corona_intensity * 0.78 + soft_atmo * 0.95 + cel_ring) * pulse);
	vec3 flare_glow = mix(star_tint.rgb, core_white, 0.62) * flare_mask * 0.95;

	// Preserva cromatismo saturado de la fotosfera evitando lavado beige/gris
	vec3 normalized_tint_tex = tex.rgb * mix(vec3(1.0), star_tint.rgb * 1.42, 0.28);
	float limb_darken = mix(1.05, 0.84, smoothstep(0.18, 0.39, dist));
	vec3 tex_rich = normalized_tint_tex * (1.26 * limb_darken);
	vec3 final_color = tex_rich * pulse;
	if (dark_core_mode) {
		float photon_rim = exp(-pow((dist - 0.212) / 0.011, 2.0));
		final_color += vec3(1.0, 0.88, 0.72) * (photon_rim * 1.35);
		final_color += corona_glow * 0.42;
		final_color *= (1.0 - horizon_occlude);
	} else {
		final_color += core_white * (core_factor * (0.48 + lum * 0.60)) + vec3(1.0, 0.98, 0.94) * (hdr_heart * 1.65 * (0.45 + lum * 0.55));
		final_color += corona_glow + flare_glow;
	}
	final_color = final_color / (vec3(1.0) + max(final_color - vec3(2.8), vec3(0.0)) * 0.22);

	COLOR = vec4(final_color, alpha * star_tint.a);
}
