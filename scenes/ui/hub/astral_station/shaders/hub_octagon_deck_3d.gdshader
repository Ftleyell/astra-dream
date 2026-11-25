shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Shader procedural ArcSys Octagonal 8-Fold para cubiertas de Estación Astral v4.
// - Geometría polar/octogonal centrada en VERTEX.xz (simetría de 8 caras alineada a puentes).
// - Normales analíticas nítidas sin artefactos de UVs estiradas.
// - Reflejo planar del Cosmos en tiempo real, cel-shading de 3 bandas y desmaterialización hexagonal.

uniform sampler2D cosmos_reflection_tex : source_color, filter_linear_mipmap, repeat_disable;

uniform bool has_cosmos_reflection = false;
uniform float cosmos_reflection_strength : hint_range(0.0, 1.0) = 0.36;
uniform float deck_radius : hint_range(1.5, 12.0) = 7.5;
uniform bool is_bastion_mode = false;
uniform float bastion_mirror_sign : hint_range(-1.0, 1.0) = 1.0;

uniform vec4 wing_plate_tint : source_color = vec4(0.16, 0.21, 0.34, 1.0);
uniform vec4 wing_chassis_tint : source_color = vec4(0.055, 0.068, 0.135, 1.0);
uniform vec4 pilot_accent_color : source_color = vec4(0.95, 0.16, 0.34, 1.0);
uniform vec4 astral_gold_color : source_color = vec4(0.92, 0.78, 0.42, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.24, 0.28, 0.46, 1.0);
uniform vec4 ink_color : source_color = vec4(0.035, 0.032, 0.080, 1.0);

uniform float ink_strength : hint_range(0.0, 1.0) = 0.90;
uniform float emissive_boost : hint_range(0.0, 4.0) = 1.25;
uniform float ambient_fill : hint_range(0.0, 0.9) = 0.26;
uniform float normal_bevel_strength : hint_range(0.0, 2.0) = 0.85;
uniform float halftone_strength : hint_range(0.0, 1.0) = 0.20;

// Iluminación viva acoplada a CosmicLightingSampler
uniform vec4 cosmic_shadow_tint : source_color = vec4(0.24, 0.28, 0.46, 1.0);
uniform vec4 cosmic_rim_color : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float cosmic_light_mix : hint_range(0.0, 1.0) = 0.50;

// Desmaterialización Tecnológica
uniform float demat_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 demat_origin = vec3(0.0);
uniform float demat_max_radius = 34.0;
uniform float demat_hex_scale = 2.4;
uniform vec4 demat_edge_color : source_color = vec4(0.15, 0.95, 1.0, 1.0);

varying vec3 v_world_pos;
varying vec2 v_local_xz;

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

float _eval_panel_height(vec2 p, out float ink_m, out float accent_m, out float gold_m, out float chassis_m) {
	float r = length(p);
	float ang = atan(p.y, p.x);

	// 8 sectores cardinales/diagonales alineados a 0, 45, 90...
	float sector = PI * 0.25;
	float ang_in_sec = abs(mod(ang + sector * 0.5, sector) - sector * 0.5);
	float radial_dist = r * sin(ang_in_sec);

	// Múltiplos de ranura octogonal escalada al radio de la isla
	float rn = r / max(deck_radius, 1.5);
	float d_oct = cos(ang_in_sec) * rn;

	// Anillos estructurales octogonales, micro-placas escalonadas y sub-divisiones limpias
	float ring1 = abs(d_oct - 0.34);
	float ring1b = abs(d_oct - 0.50);
	float ring2 = abs(d_oct - 0.64);
	float ring2b = abs(d_oct - 0.77);
	float ring3 = abs(d_oct - 0.87);
	float ring_dist = min(min(ring1, ring2), min(min(ring3, ring1b * 1.35), ring2b * 1.45)) * deck_radius;

	// Costuras radiales de 8 pliegues (estrictamente recortadas al borde exterior de ring1 usando d_oct)
	float spoke_mask = smoothstep(0.342, 0.354, d_oct);
	float spoke_dist = radial_dist + (1.0 - spoke_mask) * 2.0;

	// Sub-costura diagonal fina en el punto medio de cada sector (pi/8)
	float half_ang = abs(mod(ang, sector) - sector * 0.5);
	float mid_spoke_dist = r * sin(half_ang) + (1.0 - smoothstep(0.36, 0.64, d_oct)) * 2.0;

	float seam_dist = min(ring_dist, min(spoke_dist, mid_spoke_dist * 1.35));
	if (d_oct < 0.336) {
		seam_dist = ring_dist;
	}

	// Tinta vectorial nítida consciente de fwidth
	float px_w = max(max(length(dFdx(p)), length(dFdy(p))) * 1.25, 0.012);
	ink_m = (1.0 - smoothstep(0.014, 0.014 + px_w, seam_dist)) * ink_strength;

	// Bisel / altura del panel para calcular normal map analítico
	float groove = smoothstep(0.016, 0.095, seam_dist);
	chassis_m = (1.0 - groove) * smoothstep(0.342, 0.358, d_oct);

	// Filetes luminosos + chevrones direccionales sutiles hacia las 8 bocas de puente
	float vein_ring = (1.0 - smoothstep(0.016, 0.038, ring2 * deck_radius)) * smoothstep(0.08, 0.25, abs(sin(ang * 4.0)));
	float in_corridor = (1.0 - smoothstep(0.45, 0.68, radial_dist)) * smoothstep(0.65, 0.69, d_oct) * (1.0 - smoothstep(0.83, 0.87, d_oct));
	float chev_d = fract((d_oct * 14.0) - abs(radial_dist) * 2.2);
	float chev_m = smoothstep(0.76, 0.84, chev_d) * (1.0 - smoothstep(0.89, 0.96, chev_d)) * in_corridor;
	accent_m = clamp(max(vein_ring * 0.85, chev_m * 0.68), 0.0, 1.0);

	// Doble anillo hairline dorado fino en perímetro interior y medio
	float gold_ring_d = min(abs(d_oct - 0.885), min(abs(d_oct - 0.355), abs(d_oct - 0.51) * 1.4)) * deck_radius;
	gold_m = (1.0 - smoothstep(0.013, 0.013 + px_w * 1.2, gold_ring_d)) * 0.90;

	return groove * 0.72 + smoothstep(0.30, 0.345, d_oct) * 0.20 + smoothstep(0.48, 0.54, d_oct) * 0.08;
}

void fragment() {
	float demat_edge = 0.0;
	float hex_wire = 0.0;
	if (demat_progress > 0.001) {
		float d_origin = length(v_world_pos.xz - demat_origin.xz);
		float hex_d = _hex_cell(v_world_pos.xz * demat_hex_scale);
		float wave_r = mix(-2.5, demat_max_radius, demat_progress);
		float signed_wave = (d_origin + hex_d * 1.1) - wave_r;
		if (signed_wave < 0.0) {
			discard;
		}
		demat_edge = 1.0 - smoothstep(0.0, 2.2, signed_wave);
		hex_wire = smoothstep(0.38, 0.48, hex_d) * (1.0 - smoothstep(2.2, 4.8, signed_wave));
	}

	float ink_m = 0.0;
	float accent_m = 0.0;
	float gold_m = 0.0;
	float chassis_m = 0.0;
	float h_c = _eval_panel_height(v_local_xz, ink_m, accent_m, gold_m, chassis_m);

	float ink_dummy = 0.0;
	float acc_dummy = 0.0;
	float gold_dummy = 0.0;
	float ch_dummy = 0.0;
	float eps = 0.035;
	float h_x = _eval_panel_height(v_local_xz + vec2(eps, 0.0), ink_dummy, acc_dummy, gold_dummy, ch_dummy);
	float h_z = _eval_panel_height(v_local_xz + vec2(0.0, eps), ink_dummy, acc_dummy, gold_dummy, ch_dummy);
	vec2 grad = vec2(h_c - h_x, h_c - h_z) * (4.2 * normal_bevel_strength);
	vec3 n_tan = normalize(vec3(grad.x, grad.y, 1.0));
	vec3 normal_map_sample = n_tan * 0.5 + 0.5;

	float rn = clamp(length(v_local_xz) / max(deck_radius, 1.5), 0.0, 1.2);
	float tonal_step = 0.90 + 0.14 * smoothstep(0.30, 0.40, rn) - 0.10 * smoothstep(0.60, 0.72, rn);
	vec3 base_rgb = wing_plate_tint.rgb * tonal_step;
	base_rgb = mix(base_rgb, wing_chassis_tint.rgb, chassis_m * 0.65);
	base_rgb = mix(base_rgb, astral_gold_color.rgb * 0.92, gold_m);
	base_rgb = mix(base_rgb, pilot_accent_color.rgb, accent_m * 0.85);
	base_rgb = mix(base_rgb, ink_color.rgb, ink_m);

	float rough_v = mix(0.46, 0.24, gold_m);
	rough_v = mix(rough_v, 0.86, ink_m);
	float metal_v = mix(0.28, 0.78, gold_m) * (1.0 - ink_m * 0.9);

	vec3 eff_shadow = mix(shadow_tint.rgb, cosmic_shadow_tint.rgb, cosmic_light_mix);
	vec3 eff_rim = mix(vec3(0.28, 0.72, 1.0), cosmic_rim_color.rgb, cosmic_light_mix);
	vec3 ambient_floor = base_rgb * eff_shadow * ambient_fill;
	vec3 accent_hdr = pilot_accent_color.rgb * (accent_m * emissive_boost * 0.65 * (1.0 - ink_m));
	vec3 gold_sheen = astral_gold_color.rgb * (gold_m * 0.14);

	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, 2.8) * 0.22 * (1.0 - ink_m * 0.75);
	vec3 cosmos_sheen = mix(eff_rim, pilot_accent_color.rgb, 0.28) * fresnel * 0.34;
	vec3 demat_glow = mix(demat_edge_color.rgb, pilot_accent_color.rgb, 0.30) * (demat_edge * 2.8 + hex_wire * 1.35);

	vec3 cosmos_floor_refl = vec3(0.0);
	if (has_cosmos_reflection) {
		vec2 norm_distort = (normal_map_sample.xy - vec2(0.5)) * 0.032;
		vec2 refl_uv = vec2(
			clamp(0.5 + v_world_pos.x / 48.0 + norm_distort.x, 0.02, 0.98),
			clamp(0.5 + v_world_pos.z / 38.0 + norm_distort.y, 0.02, 0.98)
		);
		vec3 refl_c = texture(cosmos_reflection_tex, refl_uv).rgb * 0.52;
		refl_c += texture(cosmos_reflection_tex, clamp(refl_uv + vec2(0.012, 0.0), 0.01, 0.99)).rgb * 0.12;
		refl_c += texture(cosmos_reflection_tex, clamp(refl_uv - vec2(0.012, 0.0), 0.01, 0.99)).rgb * 0.12;
		refl_c += texture(cosmos_reflection_tex, clamp(refl_uv + vec2(0.0, 0.012), 0.01, 0.99)).rgb * 0.12;
		refl_c += texture(cosmos_reflection_tex, clamp(refl_uv - vec2(0.0, 0.012), 0.01, 0.99)).rgb * 0.12;
		float refl_weight = clamp((1.0 - rough_v * 0.85) * (0.34 + 0.66 * pow(1.0 - ndv, 1.6)) * (1.0 - ink_m * 0.92), 0.0, 1.0);
		cosmos_floor_refl = refl_c * refl_weight * cosmos_reflection_strength;
	}

	ALBEDO = mix(base_rgb, demat_edge_color.rgb, demat_edge * 0.65);
	NORMAL_MAP = normal_map_sample;
	NORMAL_MAP_DEPTH = normal_bevel_strength * 0.72;
	EMISSION = ambient_floor + accent_hdr + gold_sheen + cosmos_sheen + cosmos_floor_refl + demat_glow;
	METALLIC = metal_v;
	ROUGHNESS = rough_v;
	SPECULAR = mix(0.46, 0.14, rough_v);
}

void light() {
	float lit = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	float band_mid = smoothstep(0.02, 0.28, lit);
	float band_hi = smoothstep(0.50, 0.78, lit);

	float penumbra = band_mid * (1.0 - band_mid) * 3.2;
	float ht = 0.5 + 0.5 * (sin(FRAGCOORD.x * 0.9) * sin(FRAGCOORD.y * 0.9));
	float cel_intensity = 0.10 + band_mid * 0.60 + band_hi * 0.24;
	cel_intensity *= (1.0 - penumbra * halftone_strength * 0.60 * ht);
	vec3 shadow_bounce = mix(shadow_tint.rgb * 0.26, vec3(1.0), band_mid);
	DIFFUSE_LIGHT = min(DIFFUSE_LIGHT + cel_intensity * LIGHT_COLOR * shadow_bounce, vec3(0.98));

	float spec_weight = clamp((1.0 - ROUGHNESS) * 1.35, 0.0, 1.0);
	vec3 h = normalize(LIGHT + VIEW);
	float ndh = max(dot(NORMAL, h), 0.0);
	float spec_band = smoothstep(0.76, 0.92, ndh) * band_mid;
	SPECULAR_LIGHT = min(SPECULAR_LIGHT + spec_band * spec_weight * LIGHT_COLOR * 0.45, vec3(0.55));
}
