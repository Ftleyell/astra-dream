shader_type canvas_item;

// Emblema cromático ligero zero-SubViewport para tarjetas de skins por shader.
// Dibuja la paleta real de PilotSkinPreset (accent, panel, suit_dark, hair)
// con motivo geométrico según categoría (0=pilot, 1=wings, 2=weapon, 3=follow_pilot).

uniform vec4 accent_color : source_color = vec4(0.86, 0.18, 0.32, 1.0);
uniform vec4 panel_color : source_color = vec4(0.36, 0.38, 0.44, 1.0);
uniform vec4 suit_dark_color : source_color = vec4(0.16, 0.15, 0.20, 1.0);
uniform vec4 hair_color : source_color = vec4(0.86, 0.88, 0.94, 1.0);
uniform int category_mode = 0; // 0=pilot, 1=wings, 2=weapon, 3=follow_pilot
uniform int star_level = 1;
uniform bool is_locked = false;

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float sd_chamfer(vec2 p, float r, float c) {
	p = abs(p);
	float d_box = max(p.x, p.y) - r;
	float d_diag = (p.x + p.y - (r * 2.0 - c)) * 0.70710678;
	return max(d_box, d_diag);
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float d_frame = sd_chamfer(p, 0.90, 0.34);
	float outer_alpha = 1.0 - smoothstep(-0.02, 0.03, d_frame);
	if (outer_alpha <= 0.005) {
		discard;
	}

	// Bandas diagonales de la paleta del exo-traje
	float diag = p.x * 0.65 + p.y * 0.76;
	vec3 bg = mix(suit_dark_color.rgb, panel_color.rgb, smoothstep(-0.22, 0.06, diag));
	if (category_mode == 0) {
		float hair_band = smoothstep(0.32, 0.50, diag);
		bg = mix(bg, hair_color.rgb, hair_band * 0.88);
	}

	// Líneas sutiles tech de fondo
	float grid_line = smoothstep(0.035, 0.0, abs(fract((p.x - p.y) * 3.0) - 0.5) - 0.48);
	bg += panel_color.rgb * grid_line * 0.08;

	// Silueta geométrica por categoría
	float glyph = 0.0;
	if (category_mode == 1) {
		// Alas Psíquicas (3 cuchillas simétricas)
		vec2 q = vec2(abs(p.x), p.y);
		float b0 = 1.0 - smoothstep(0.045, 0.07, sd_segment(q, vec2(0.10, 0.16), vec2(0.64, -0.44)));
		float b1 = 1.0 - smoothstep(0.038, 0.06, sd_segment(q, vec2(0.14, 0.24), vec2(0.60, -0.06)));
		float b2 = 1.0 - smoothstep(0.032, 0.055, sd_segment(q, vec2(0.12, 0.30), vec2(0.46, 0.28)));
		glyph = max(b0, max(b1, b2));
	} else if (category_mode == 2) {
		// Rail-Lance Orbital (cañón doble inclinado + núcleo cristalino)
		vec2 q = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * p;
		float r_top = 1.0 - smoothstep(0.03, 0.05, sd_segment(q, vec2(-0.56, -0.10), vec2(0.58, -0.07)));
		float r_bot = 1.0 - smoothstep(0.03, 0.05, sd_segment(q, vec2(-0.56, 0.10), vec2(0.58, 0.07)));
		float core = 1.0 - smoothstep(0.045, 0.07, sd_box(q - vec2(-0.12, 0.0), vec2(0.24, 0.045)));
		glyph = max(max(r_top, r_bot), core);
	} else if (category_mode == 3) {
		// Vínculo Follow Pilot (anillos concéntricos + diamante central)
		float ring = 1.0 - smoothstep(0.035, 0.06, abs(length(p) - 0.40));
		float core = 1.0 - smoothstep(0.03, 0.055, (abs(p.x) + abs(p.y)) - 0.20);
		glyph = max(ring, core);
	} else {
		// Piloto (emblema táctico + visor)
		float diamond = 1.0 - smoothstep(0.03, 0.06, abs((abs(p.x) * 1.15 + abs(p.y) * 0.85) - 0.44));
		float visor = 1.0 - smoothstep(0.025, 0.05, sd_segment(p, vec2(-0.30, -0.06), vec2(0.30, -0.06)));
		glyph = max(diamond, visor);
	}

	vec3 acc_glow = accent_color.rgb * (1.28 + float(max(star_level - 1, 0)) * 0.22);
	vec3 col = mix(bg, acc_glow, glyph * 0.92);

	// Barrido holográfico 2★ / 3★
	if (star_level >= 2 && !is_locked) {
		float sweep = fract(TIME * (star_level >= 3 ? 0.55 : 0.35) - (p.x + p.y) * 0.35);
		float sheen = smoothstep(0.84, 0.96, sweep) * (1.0 - smoothstep(0.96, 1.0, sweep));
		vec3 holo_col = (star_level >= 3)
			? mix(accent_color.rgb, vec3(0.4, 0.95, 1.0), 0.45)
			: accent_color.rgb;
		col += holo_col * sheen * 0.48;
	}

	// Borde metálico y halo perimetral
	float rim = smoothstep(-0.08, -0.02, d_frame) * outer_alpha;
	col = mix(col, accent_color.rgb * 1.15, rim * 0.85);

	if (is_locked) {
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(luma * 0.25), col * 0.28, 0.35);
		col = mix(col, accent_color.rgb * 0.42, rim * 0.7);
	}

	COLOR = vec4(col, outer_alpha);
}
