shader_type canvas_item;
render_mode blend_mix;

// Post-procesado Full-Screen Sakuga para Skill [R] y Ultimate [Q] — Astra Dream
// Fase 0: Dimming dramático + Speedlines radiales
// Fase 1: Impact Frame SAKUGA B/N ULTRA-FILOSO (binario duro step() + contornos Sobel + strobe invertido + rayos cortantes)
// Fase 2: Fractura de Cristal Obsidiana (Voronoi GPU + facetas binarias B/N + grietas Carmesí/Amatista HDR)
// Fase 3: Release Flash + Aberración Cromática Radial

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform int effect_phase : hint_range(0, 3) = 0;
uniform float effect_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float bw_invert_strobe : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center_uv = vec2(0.5, 0.5);
uniform vec4 accent_color : source_color = vec4(0.98, 0.14, 0.34, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.545, 0.361, 0.965, 1.0);
uniform float bw_luma_threshold : hint_range(0.05, 0.85) = 0.28;
uniform float accent_hdr_boost : hint_range(0.5, 3.5) = 1.90;
uniform float shatter_cell_density : hint_range(4.0, 40.0) = 16.0;
uniform float shatter_crack_width_px : hint_range(0.5, 10.0) = 2.6;
uniform float shatter_refraction_px : hint_range(0.0, 48.0) = 14.0;
uniform float radial_speedlines_strength : hint_range(0.0, 1.5) = 0.62;
uniform float chromatic_aberration_px : hint_range(0.0, 30.0) = 9.5;
uniform float time_sec = 0.0;

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453123);
}

float luma_of(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Rayos Sakuga afilados (binarios, sin desenfoque)
float compute_sakuga_spikes(vec2 uv, vec2 c_uv, float t) {
	vec2 d = uv - c_uv;
	float dist = length(d);
	float ang = atan(d.y, d.x);
	float s1 = sin(ang * 34.0 + floor(t * 24.0) * 1.9);
	float s2 = sin(ang * 79.0 - floor(t * 24.0) * 2.7 + 0.8);
	float s3 = sin(ang * 13.0 + 0.4);
	float spike = step(0.62, s1 * 0.50 + s2 * 0.35 + s3 * 0.25 + dist * 0.38);
	float ring_mask = step(0.18, dist);
	return spike * ring_mask;
}

float compute_soft_speedlines(vec2 uv, vec2 c_uv, float t) {
	vec2 d = uv - c_uv;
	float dist = length(d);
	float ang = atan(d.y, d.x);
	float ray_a = sin(ang * 44.0 + t * 18.0) * 0.5 + 0.5;
	float ray_b = sin(ang * 88.0 - t * 24.0 + 1.7) * 0.5 + 0.5;
	return smoothstep(0.76, 0.97, ray_a * 0.6 + ray_b * 0.4) * smoothstep(0.14, 0.60, dist);
}

// Sobel 3x3 para contornos de tinta manga brutales
float sobel_edge(vec2 uv, vec2 px) {
	float tl = luma_of(textureLod(screen_texture, clamp(uv + vec2(-px.x, -px.y), vec2(0.0), vec2(1.0)), 0.0).rgb);
	float tc = luma_of(textureLod(screen_texture, clamp(uv + vec2(0.0,   -px.y), vec2(0.0), vec2(1.0)), 0.0).rgb);
	float tr = luma_of(textureLod(screen_texture, clamp(uv + vec2(px.x,  -px.y), vec2(0.0), vec2(1.0)), 0.0).rgb);
	float ml = luma_of(textureLod(screen_texture, clamp(uv + vec2(-px.x,  0.0),  vec2(0.0), vec2(1.0)), 0.0).rgb);
	float mr = luma_of(textureLod(screen_texture, clamp(uv + vec2(px.x,   0.0),  vec2(0.0), vec2(1.0)), 0.0).rgb);
	float bl = luma_of(textureLod(screen_texture, clamp(uv + vec2(-px.x,  px.y), vec2(0.0), vec2(1.0)), 0.0).rgb);
	float bc = luma_of(textureLod(screen_texture, clamp(uv + vec2(0.0,    px.y), vec2(0.0), vec2(1.0)), 0.0).rgb);
	float br = luma_of(textureLod(screen_texture, clamp(uv + vec2(px.x,   px.y), vec2(0.0), vec2(1.0)), 0.0).rgb);
	float gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
	float gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;
	return length(vec2(gx, gy));
}

// Voronoi analítico para fractura de cristal obsidiana
vec4 voronoi_shatter(vec2 uv, vec2 aspect, float scale) {
	vec2 p = uv * aspect * scale;
	vec2 n = floor(p);
	vec2 f = fract(p);

	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	vec2 best_id = vec2(0.0);

	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			vec2 r = g + (0.15 + 0.70 * o) - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
				best_id = n + g;
			}
		}
	}

	float edge_d = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			vec2 r = g + (0.15 + 0.70 * o) - f;
			if (dot(mr - r, mr - r) > 0.0001) {
				edge_d = min(edge_d, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}

	vec2 cell_rnd = hash22(best_id + vec2(19.3, 7.1));
	return vec4(edge_d, cell_rnd.x, cell_rnd.x * 2.0 - 1.0, cell_rnd.y * 2.0 - 1.0);
}

void fragment() {
	if (effect_intensity <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 px = SCREEN_PIXEL_SIZE;
		vec2 aspect = vec2(px.y / max(px.x, 0.00001), 1.0);
		vec3 src = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
		vec3 out_rgb = src;

		if (effect_phase == 0) {
			// Fase 0: Dimming dramático + viñeta + líneas de velocidad
			vec2 d = (SCREEN_UV - center_uv) * aspect;
			float vig = smoothstep(0.20, 1.15, length(d));
			float lines = compute_soft_speedlines(SCREEN_UV, center_uv, time_sec) * radial_speedlines_strength;
			out_rgb = mix(src * 0.52, vec3(0.02, 0.015, 0.045), vig * 0.68);
			out_rgb += accent_color.rgb * lines * 0.55;
		} else if (effect_phase == 1) {
			// Fase 1: SAKUGA IMPACT FRAME — Blanco y Negro Binario ULTRA-FILOSO (cero grises lavados)
			float luma = luma_of(src);
			float edge = sobel_edge(SCREEN_UV, px * 1.65);
			float ink_contour = step(0.18, edge);
			float spikes = compute_sakuga_spikes(SCREEN_UV, center_uv, time_sec) * step(0.15, radial_speedlines_strength);

			// Binarización dura sin smoothstep suave
			float bw_raw = step(bw_luma_threshold, luma);
			// Strobe 0 = Fondo negro tinta + siluetas/rayos blancos cegadores; Strobe 1 = Fondo blanco puro + siluetas/rayos tinta negra
			float bw = mix(bw_raw, 1.0 - bw_raw, step(0.5, bw_invert_strobe));
			// Los contornos Sobel y los rayos Sakuga invierten el píxel para crear trazos manga brutales
			bw = mix(bw, 1.0 - bw, max(ink_contour * 0.95, spikes * 0.85));

			vec3 pitch_black = vec3(0.0, 0.0, 0.0);
			vec3 blinding_white = vec3(1.85, 1.85, 1.92);
			vec3 sakuga_bw = mix(pitch_black, blinding_white, step(0.5, bw));

			// Solo un corte quirúrgico del color acento en bordes de máxima saturación
			float chroma = max(src.r, max(src.g, src.b)) - min(src.r, min(src.g, src.b));
			float slash_accent = step(0.48, chroma) * ink_contour;
			out_rgb = mix(sakuga_bw, accent_color.rgb * accent_hdr_boost * 1.25, slash_accent);
		} else if (effect_phase == 2) {
			// Fase 2: Fractura de Cristal Obsidiana (Voronoi GPU + Facetas B/N Filosas + Grietas Carmesí/Amatista HDR)
			vec4 vor = voronoi_shatter(SCREEN_UV - center_uv + vec2(0.5), aspect, shatter_cell_density);
			float edge_d = vor.x;
			float cell_h = vor.y;
			vec2 shard_dir = normalize(vor.zw + vec2(0.0001));

			vec2 refr_uv = clamp(SCREEN_UV + shard_dir * px * shatter_refraction_px * (0.45 + 0.55 * cell_h), vec2(0.0), vec2(1.0));
			vec3 shard_col = textureLod(screen_texture, refr_uv, 0.0).rgb;
			float luma = luma_of(shard_col);
			float sharp_bw = step(bw_luma_threshold, luma);

			// Alternar facetas obsidiana pura y facetas blancas filosas con borde de tinta
			vec3 obsidian = vec3(0.005, 0.004, 0.012);
			vec3 shard_lit = mix(vec3(1.70, 1.68, 1.78), accent_color.rgb * 1.55, step(0.72, cell_h));
			vec3 shard_base = mix(obsidian, shard_lit, (1.0 - sharp_bw) * step(0.45, cell_h) + sharp_bw * 0.85);

			// Grietas incandescentes ultra-filosas
			float crack_w = shatter_crack_width_px * px.y * shatter_cell_density;
			float crack_core = 1.0 - step(crack_w * 0.75, edge_d);
			float crack_halo = (1.0 - smoothstep(crack_w * 0.75, crack_w * 2.8, edge_d)) * 0.65;
			vec3 crack_tint = mix(accent_color.rgb, secondary_color.rgb, step(0.52, cell_h));
			vec3 crack_hdr = mix(crack_tint * accent_hdr_boost, vec3(2.0, 1.95, 2.05), crack_core * 0.70);

			out_rgb = shard_base + crack_tint * crack_halo * accent_hdr_boost + crack_hdr * crack_core;
		} else {
			// Fase 3: Release Flash + Aberración Cromática Radial
			vec2 dir = normalize(SCREEN_UV - center_uv + vec2(0.0001));
			float rad = length(SCREEN_UV - center_uv);
			vec2 ca_off = dir * px * chromatic_aberration_px * (0.4 + rad * 1.5) * effect_intensity;
			float r_ch = textureLod(screen_texture, clamp(SCREEN_UV + ca_off, vec2(0.0), vec2(1.0)), 0.0).r;
			float g_ch = src.g;
			float b_ch = textureLod(screen_texture, clamp(SCREEN_UV - ca_off, vec2(0.0), vec2(1.0)), 0.0).b;
			out_rgb = vec3(r_ch, g_ch, b_ch) + vec3(0.42 * effect_intensity) + accent_color.rgb * (0.25 * effect_intensity);
		}

		COLOR = vec4(mix(src, out_rgb, effect_intensity), 1.0);
	}
}
