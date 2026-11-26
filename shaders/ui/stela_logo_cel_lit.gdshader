shader_type canvas_item;

// Shader Cel-Shaded ArcSys + Normal Map para el logotipo de Stela Galactica.
// Acoplado en vivo al muestreo de luz direccional, clave y sombra del Cosmos Engine.

uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D masks_tex : filter_linear_mipmap, repeat_disable;

uniform float normal_strength : hint_range(0.0, 2.0) = 0.90;
uniform float cel_shadow_threshold : hint_range(-0.5, 0.8) = 0.16;
uniform float cel_spec_threshold : hint_range(0.2, 0.98) = 0.72;

uniform vec3 cosmos_light_dir = vec3(-0.45, -0.55, 0.70);
uniform vec4 cosmos_key_color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform vec4 cosmos_shadow_tint : source_color = vec4(0.20, 0.22, 0.44, 1.0);
uniform vec4 cosmos_rim_color : source_color = vec4(0.22, 0.88, 1.0, 1.0);
uniform float cosmos_light_mix : hint_range(0.0, 1.0) = 0.68;

uniform float rim_intensity : hint_range(0.0, 2.5) = 0.85;
uniform float gold_specular_intensity : hint_range(0.0, 2.5) = 1.15;
uniform float sprite_rotation_rad = 0.0;
uniform float shine_progress : hint_range(-0.6, 1.6) = -0.6;
uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_edge_color : source_color = vec4(0.24, 0.94, 1.0, 1.0);

float _hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 base_sample = texture(TEXTURE, UV);
	float alpha = base_sample.a * COLOR.a;
	if (alpha < 0.02) {
		discard;
	}

	// Disolución estelar radial hacia el Hub
	float dissolve_glow = 0.0;
	if (dissolve_progress > 0.001) {
		vec2 centered = UV - vec2(0.5);
		float r = length(centered) * 1.42;
		float noise_v = _hash21(floor(UV * 84.0)) * 0.28 + _hash21(floor(UV * 26.0)) * 0.22;
		float wave = (1.0 - r) + noise_v;
		float cutoff = mix(-0.15, 1.65, dissolve_progress);
		if (wave < cutoff) {
			discard;
		}
		dissolve_glow = 1.0 - smoothstep(0.0, 0.14, wave - cutoff);
	}

	vec3 albedo = base_sample.rgb * COLOR.rgb;
	vec3 masks = texture(masks_tex, UV).rgb;
	float metal_mask = masks.r;
	float accent_mask = masks.g;
	float height_ao = masks.b;

	vec3 n_raw = texture(normal_tex, UV).xyz * 2.0 - 1.0;
	vec3 n = normalize(vec3(n_raw.x * normal_strength, n_raw.y * normal_strength, max(n_raw.z, 0.15)));
	vec3 l_dir = normalize(cosmos_light_dir);
	float rot_c = cos(-sprite_rotation_rad);
	float rot_s = sin(-sprite_rotation_rad);
	l_dir.xy = vec2(l_dir.x * rot_c - l_dir.y * rot_s, l_dir.x * rot_s + l_dir.y * rot_c);
	vec3 view_dir = vec3(0.0, 0.0, 1.0);

	float luma = dot(albedo, vec3(0.299, 0.587, 0.114));
	float ink_preserve = 1.0 - smoothstep(0.06, 0.18, luma);

	// Bandas cel-shaded ArcSys
	float ndotl = dot(n, l_dir);
	float cel_lit = smoothstep(cel_shadow_threshold - 0.06, cel_shadow_threshold + 0.06, ndotl);
	float cel_hi = smoothstep(cel_spec_threshold - 0.05, cel_spec_threshold + 0.05, ndotl);

	vec3 eff_shadow = mix(vec3(0.45, 0.42, 0.62), cosmos_shadow_tint.rgb * 1.45, cosmos_light_mix);
	vec3 eff_key = mix(vec3(1.0), cosmos_key_color.rgb, cosmos_light_mix * 0.65);
	vec3 lit_rgb = mix(albedo * mix(vec3(0.72), eff_shadow, 0.55), albedo * eff_key, cel_lit);

	// Especular cortante metálico en oro y cromo
	vec3 h_vec = normalize(l_dir + view_dir);
	float ndoth = max(dot(n, h_vec), 0.0);
	float spec_cut = smoothstep(cel_spec_threshold, cel_spec_threshold + 0.04, ndoth);
	float metal_spec = (spec_cut * 0.85 + cel_hi * 0.35) * metal_mask * gold_specular_intensity;
	lit_rgb += eff_key * metal_spec * 0.58;

	// Rim estelar + acento cian reactivo al Cosmos
	float fresnel_edge = pow(1.0 - clamp(n.z, 0.0, 1.0), 1.7);
	float rim_factor = clamp(fresnel_edge * 0.85 + accent_mask * 0.55, 0.0, 1.0) * rim_intensity * (1.0 - ink_preserve * 0.85);
	lit_rgb += mix(vec3(0.22, 0.88, 1.0), cosmos_rim_color.rgb, cosmos_light_mix) * rim_factor * 0.42;

	// Barrido diagonal de brillo anime periódico
	float diag_coord = UV.x * 0.78 + (1.0 - UV.y) * 0.55;
	float shine_band = 1.0 - smoothstep(0.0, 0.09, abs(diag_coord - shine_progress));
	float shine_core = 1.0 - smoothstep(0.0, 0.03, abs(diag_coord - shine_progress));
	lit_rgb += (eff_key * shine_band * 0.42 + vec3(1.0) * shine_core * 0.55) * (0.35 + metal_mask * 0.65) * (1.0 - ink_preserve);

	// Respetar tinta negra y AO de biseles
	lit_rgb *= mix(0.84, 1.04, height_ao);
	lit_rgb = mix(lit_rgb, albedo, ink_preserve * 0.92);
	lit_rgb = mix(lit_rgb, dissolve_edge_color.rgb * 1.45, dissolve_glow);

	COLOR = vec4(lit_rgb, alpha);
}
