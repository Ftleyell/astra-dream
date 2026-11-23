shader_type canvas_item;
render_mode blend_add, unshaded;

/**
 * star_anomaly_halo.gdshader (v2.5)
 *
 * Firma visual única Anime Space-Opera para los arquetipos estelares especiales:
 * - anomaly_mode = 1 (Magnetar / Púlsar): disco de acreción 2.5D inclinado + jets polares relativistas.
 * - anomaly_mode = 2 (Enana Blanca): anillo expansivo de nebulosa planetaria bi-banda + destello.
 * - anomaly_mode = 3 (Agujero Negro / Singularidad): disco de acreción inclinado dorado-violeta
 *   + doble arco gravitacional curvado tipo lente + anillo de fotones razor-sharp.
 * - anomaly_mode = 4 (Nova Esmeralda): doble onda de choque expansiva + rayos radiales prismáticos.
 */

uniform int anomaly_mode : hint_range(0, 4) = 1;
uniform vec4 primary_color : source_color = vec4(0.78, 0.28, 1.0, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.24, 0.96, 1.0, 1.0);
uniform float tilt_angle : hint_range(-3.1416, 3.1416) = 0.42;
uniform float intensity : hint_range(0.0, 3.0) = 1.25;
uniform float pulse_speed : hint_range(0.1, 8.0) = 2.6;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r_quad = length(p);
	if (anomaly_mode == 0 || r_quad >= 0.495) {
		discard;
	}

	float c = cos(tilt_angle);
	float s = sin(tilt_angle);
	vec2 pr = vec2(p.x * c + p.y * s, -p.x * s + p.y * c);
	float outer_fade = 1.0 - smoothstep(0.42, 0.492, r_quad);

	vec3 col = vec3(0.0);

	if (anomaly_mode == 1) {
		// 1. Magnetar: Jets polares relativistas finos + onda pulsante armónica sobre el ecuador sin duplicar disco
		float y_abs = abs(pr.y);
		float jet_env = smoothstep(0.12, 0.22, y_abs) * (1.0 - smoothstep(0.32, 0.48, y_abs));
		float jet_width = 0.008 + y_abs * 0.055;
		float jet_core = exp(-pow(pr.x / jet_width, 2.0) * 3.8);
		float jet_sheath = exp(-pow(pr.x / (jet_width * 2.4), 2.0) * 2.2);
		float knots = 0.62 + 0.38 * sin(y_abs * 34.0 - TIME * pulse_speed * 3.0);

		float pulse_wave = exp(-abs(fract(r_quad * 2.4 - TIME * 0.32) - 0.5) * 14.0) * smoothstep(0.18, 0.44, r_quad) * (1.0 - smoothstep(0.40, 0.485, r_quad));
		col += mix(secondary_color.rgb, vec3(0.95, 0.98, 1.0), 0.62) * (jet_core * jet_env * knots * 1.15);
		col += primary_color.rgb * (jet_sheath * jet_env * 0.52 + pulse_wave * 0.35);
	} else if (anomaly_mode == 2) {
		// 2. Enana Blanca: Doble velo circular cristalino + destello estelar de diamante sutil
		float outer_shell = exp(-pow((r_quad - 0.365) / 0.022, 2.0));
		float inner_shell = exp(-pow((r_quad - 0.285) / 0.016, 2.0));
		float ang = atan(pr.y, pr.x);
		float shimmer = 0.78 + 0.22 * sin(ang * 4.0 + TIME * 0.8);
		float breathe = 0.90 + 0.10 * sin(TIME * pulse_speed * 0.9);
		col += primary_color.rgb * (outer_shell * 0.48 * shimmer * breathe);
		col += secondary_color.rgb * (inner_shell * 0.36 * breathe);

		float flare_h = exp(-abs(pr.y) * 58.0) * exp(-abs(pr.x) * 6.5);
		float flare_v = exp(-abs(pr.x) * 58.0) * exp(-abs(pr.y) * 6.5);
		col += vec3(0.94, 0.98, 1.0) * ((flare_h + flare_v) * 0.72);
	} else if (anomaly_mode == 3) {
		// 3. Agujero Negro / Singularidad: Horizonte oscuro intacto + anillo de fotones ceñido a 0.90 + brillo Doppler sutil alineado
		vec2 d_p = vec2(pr.x, pr.y * 3.85);
		float d_r = length(d_p);
		float d_ang = atan(d_p.y, d_p.x);
		float swirl = 0.5 + 0.5 * sin(d_ang * 4.0 - d_r * 38.0 + TIME * pulse_speed * 1.9);
		float disc_bands = smoothstep(0.32, 0.76, swirl);
		float center_clear = smoothstep(0.102, 0.124, r_quad);
		float disc_env = smoothstep(0.130, 0.215, d_r) * (1.0 - smoothstep(0.32, 0.44, d_r)) * center_clear;
		// Asimetría Doppler sutil (un solo plano gravitacional integrado, cero doble disco)
		float doppler = mix(0.65, 1.28, smoothstep(-0.35, 0.35, -pr.x));
		col += mix(secondary_color.rgb, primary_color.rgb, 0.48 + disc_bands * 0.52) * (disc_env * (0.18 + disc_bands * 0.34) * doppler);

		// Lente gravitacional esférica ceñida al borde del horizonte de eventos real
		float photon_ring = exp(-pow((r_quad - 0.116) / 0.0055, 2.0));
		float lens_arch = exp(-pow((r_quad - 0.160) / 0.010, 2.0)) * smoothstep(0.04, 0.16, abs(pr.y));
		col += mix(primary_color.rgb, vec3(1.0, 0.96, 0.86), 0.78) * (photon_ring * 1.05);
		col += secondary_color.rgb * (lens_arch * 0.60);
	} else {
		// 4. Nova Esmeralda: Ondas de choque sutiles + turbulencia coronal orgánica + picos anamórficos de estrella
		float ang = atan(pr.y, pr.x);
		float wave_t = fract(TIME * pulse_speed * 0.16);
		float r_wave1 = 0.23 + wave_t * 0.22;
		float ring1 = exp(-pow((r_quad - r_wave1) / 0.012, 2.0)) * (1.0 - wave_t) * 0.42;

		float spiral = 0.5 + 0.5 * sin(ang * 3.0 - r_quad * 18.0 + TIME * 1.35 + 1.2 * cos(ang * 2.0 - TIME * 0.7));
		float corona_wisp = pow(spiral, 2.2) * exp(-pow((r_quad - 0.27) / 0.075, 2.0)) * smoothstep(0.16, 0.22, r_quad) * 0.48;

		float flare_h = exp(-abs(pr.y) * 52.0) * exp(-abs(pr.x) * 6.8);
		float flare_v = exp(-abs(pr.x) * 52.0) * exp(-abs(pr.y) * 6.8);
		vec2 d45 = vec2((pr.x - pr.y) * 0.7071, (pr.x + pr.y) * 0.7071);
		float flare_diag = (exp(-abs(d45.y) * 64.0) * exp(-abs(d45.x) * 14.0) + exp(-abs(d45.x) * 64.0) * exp(-abs(d45.y) * 14.0)) * 0.35;

		col += primary_color.rgb * (ring1 + corona_wisp);
		col += mix(secondary_color.rgb, vec3(0.92, 1.0, 0.98), 0.65) * ((flare_h + flare_v + flare_diag) * 0.85);
	}

	col *= outer_fade * intensity;
	col = col / (vec3(1.0) + max(col - vec3(1.2), vec3(0.0)) * 0.38);
	float alpha = clamp(max(col.r, max(col.g, col.b)), 0.0, 1.0);
	if (alpha <= 0.004) {
		discard;
	}
	COLOR = vec4(col, alpha);
}
