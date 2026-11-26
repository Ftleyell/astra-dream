shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Shader exclusivo de geometría sagrada / astrolabio para el estrado circular de la Cápsula Hero.
// - Reemplaza por completo las texturas estiradas sobre el piso de la Cápsula.
// - Trazos limpios en Oro Astral, titanio oscuro cepillado y anillo energético con reflejo del Cosmos.

uniform sampler2D cosmos_reflection_tex : source_color, filter_linear_mipmap, repeat_disable;

uniform bool has_cosmos_reflection = false;
uniform float cosmos_reflection_strength : hint_range(0.0, 1.0) = 0.40;
uniform float dais_radius : hint_range(0.8, 3.5) = 1.88;

uniform vec4 base_titanium_color : source_color = vec4(0.11, 0.135, 0.22, 1.0);
uniform vec4 inner_ring_color : source_color = vec4(0.16, 0.19, 0.30, 1.0);
uniform vec4 astral_gold_color : source_color = vec4(0.92, 0.78, 0.42, 1.0);
uniform vec4 pilot_accent_color : source_color = vec4(0.95, 0.16, 0.34, 1.0);
uniform vec4 ink_color : source_color = vec4(0.035, 0.032, 0.080, 1.0);
uniform vec4 cosmic_shadow_tint : source_color = vec4(0.24, 0.28, 0.46, 1.0);
uniform vec4 cosmic_rim_color : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float cosmic_light_mix : hint_range(0.0, 1.0) = 0.50;
uniform float emissive_boost : hint_range(0.0, 4.0) = 1.35;

uniform float demat_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 demat_origin = vec3(0.0);
uniform float demat_max_radius = 34.0;
uniform vec4 demat_edge_color : source_color = vec4(0.15, 0.95, 1.0, 1.0);

varying vec2 v_local_xz;
varying vec3 v_world_pos;

float _hex_cell(vec2 p) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	return max(abs(gv.x), dot(abs(gv), normalize(r)));
}

void vertex() {
	v_local_xz = VERTEX.xz;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float demat_edge = 0.0;
	if (demat_progress > 0.001) {
		float d_origin = length(v_world_pos.xz - demat_origin.xz);
		float hex_d = _hex_cell(v_world_pos.xz * 2.4);
		float wave_r = mix(-2.5, demat_max_radius, demat_progress);
		float signed_wave = (d_origin + hex_d * 1.1) - wave_r;
		if (signed_wave < 0.0) {
			discard;
		}
		demat_edge = 1.0 - smoothstep(0.0, 2.2, signed_wave);
	}

	float r = length(v_local_xz);
	float rn = clamp(r / max(dais_radius, 0.5), 0.0, 1.0);
	float ang = atan(v_local_xz.y, v_local_xz.x);
	float px_w = max(max(length(dFdx(v_local_xz)), length(dFdy(v_local_xz))) * 1.25, 0.006);

	// 8 divisiones cardinales/diagonales limpias + anillo astrolabio de rotación sutil
	float sector = PI * 0.25;
	float ang_d = abs(mod(ang + sector * 0.5, sector) - sector * 0.5);
	float radial_seam = r * sin(ang_d) + (1.0 - smoothstep(0.26, 0.34, rn)) * 2.0;

	// Tres anillos limpios: núcleo interior, pista astrolabio y anillo LED exterior
	float d_r1 = abs(rn - 0.34) * dais_radius;
	float d_r2 = abs(rn - 0.64) * dais_radius;
	float d_r3 = abs(rn - 0.87) * dais_radius;
	float ink_m = 1.0 - smoothstep(0.010, 0.010 + px_w, min(min(d_r1, d_r2), radial_seam));

	// Ticks orbitales giratorios sutiles entre r1 y r2
	float rot_ang = ang - TIME * 0.14;
	float tick_mod = abs(mod(rot_ang + (PI / 12.0), PI / 6.0) - (PI / 12.0));
	float tick_d = r * sin(tick_mod);
	float in_tick_band = smoothstep(0.40, 0.43, rn) * (1.0 - smoothstep(0.56, 0.59, rn));
	float gold_tick = (1.0 - smoothstep(0.012, 0.012 + px_w, tick_d)) * in_tick_band;
	float gold_line = (1.0 - smoothstep(0.013, 0.013 + px_w, min(d_r1, d_r2)));
	float gold_m = clamp(max(gold_line * 0.85, gold_tick * 0.72), 0.0, 1.0);

	// Anillo LED fino reactivo al color de piloto en el perímetro de la tarima
	float accent_ring = 1.0 - smoothstep(0.016, 0.016 + px_w * 1.4, d_r3);
	float pulse = 0.78 + 0.22 * sin(TIME * 2.2 - rn * 3.0);

	vec3 base_rgb = mix(base_titanium_color.rgb, inner_ring_color.rgb, smoothstep(0.32, 0.36, rn) * (1.0 - smoothstep(0.62, 0.66, rn)));
	base_rgb = mix(base_rgb, ink_color.rgb, ink_m * 0.72);
	base_rgb = mix(base_rgb, astral_gold_color.rgb, gold_m);
	base_rgb = mix(base_rgb, pilot_accent_color.rgb, accent_ring);

	float rough_v = mix(0.36, 0.20, gold_m);
	rough_v = mix(rough_v, 0.85, ink_m * 0.7);
	float metal_v = mix(0.32, 0.82, gold_m) * (1.0 - ink_m * 0.8);

	vec3 eff_shadow = mix(vec3(0.24, 0.28, 0.46), cosmic_shadow_tint.rgb, cosmic_light_mix);
	vec3 eff_rim = mix(vec3(0.45, 0.85, 1.0), cosmic_rim_color.rgb, cosmic_light_mix);
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);

	vec3 cosmos_refl = vec3(0.0);
	if (has_cosmos_reflection) {
		vec2 r_uv = vec2(clamp(0.5 + v_world_pos.x / 48.0, 0.02, 0.98), clamp(0.5 + v_world_pos.z / 38.0, 0.02, 0.98));
		cosmos_refl = texture(cosmos_reflection_tex, r_uv).rgb * cosmos_reflection_strength * (0.30 + 0.70 * pow(1.0 - ndv, 1.6)) * (1.0 - ink_m * 0.85);
	}

	vec3 em_col = base_rgb * eff_shadow * 0.24;
	em_col += pilot_accent_color.rgb * (accent_ring * emissive_boost * 1.15 * pulse);
	em_col += astral_gold_color.rgb * (gold_m * 0.20);
	em_col += eff_rim * pow(1.0 - ndv, 2.8) * 0.14;
	em_col += cosmos_refl;
	em_col += demat_edge_color.rgb * (demat_edge * 2.8);

	ALBEDO = mix(base_rgb, demat_edge_color.rgb, demat_edge * 0.65);
	EMISSION = em_col;
	METALLIC = metal_v;
	ROUGHNESS = rough_v;
	SPECULAR = 0.55;
}

void light() {
	float ndotl = max(dot(NORMAL, LIGHT), 0.0);
	float shadow_f = smoothstep(0.12, 0.88, ATTENUATION);
	float band_mid = smoothstep(0.06, 0.30, ndotl) * shadow_f;
	float band_hi = smoothstep(0.52, 0.80, ndotl) * shadow_f;
	float cel_i = 0.12 + band_mid * 0.62 + band_hi * 0.24;
	DIFFUSE_LIGHT = min(DIFFUSE_LIGHT + cel_i * LIGHT_COLOR, vec3(0.98));
	vec3 h = normalize(LIGHT + VIEW);
	float ndh = max(dot(NORMAL, h), 0.0);
	float spec_b = smoothstep(0.76, 0.92, ndh) * band_mid;
	SPECULAR_LIGHT = min(SPECULAR_LIGHT + spec_b * (1.0 - ROUGHNESS) * LIGHT_COLOR * 0.50, vec3(0.58));
}
