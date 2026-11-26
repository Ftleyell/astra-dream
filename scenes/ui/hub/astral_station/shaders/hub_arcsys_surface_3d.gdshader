shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Shader maestro ArcSys para pisos y mamparos arquitectónicos del Hub 3D (Estación Astral v2).
// - Lee bundle Multi-Mapa compilado (albedo, id_mask, ilm_mask, ink_sdf 2x sin mipmaps en LOD 0).
// - Recolorea canales emisivos reactivos hacia pilot_accent_color y tiñe placas por ala.
// - Implementa void light() cel-shaded de 3 bandas para recibir sombras proyectadas reales con corte anime.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D id_mask_tex : filter_nearest, repeat_enable;
uniform sampler2D ilm_mask_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D ink_sdf_tex : filter_linear, repeat_enable;
uniform sampler2D normal_map_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D pbr_orm_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D cosmos_reflection_tex : source_color, filter_linear_mipmap, repeat_disable;

uniform bool has_maps = false;
uniform bool has_pbr_maps = false;
uniform bool has_cosmos_reflection = false;
uniform float cosmos_reflection_strength : hint_range(0.0, 1.0) = 0.44;
uniform vec2 uv_scale = vec2(6.0, 5.5);
uniform vec2 tex_native_size = vec2(1024.0, 1024.0);

uniform vec4 pilot_accent_color : source_color = vec4(0.95, 0.16, 0.34, 1.0);
uniform vec4 wing_plate_tint : source_color = vec4(0.20, 0.25, 0.38, 1.0);
uniform vec4 wing_chassis_tint : source_color = vec4(0.055, 0.068, 0.12, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.24, 0.28, 0.46, 1.0);
uniform vec4 ink_color : source_color = vec4(0.035, 0.032, 0.080, 1.0);

uniform bool enable_deck_zoning = false;
uniform vec4 astral_gold_color : source_color = vec4(0.91, 0.78, 0.44, 1.0);
uniform vec4 west_wing_tint : source_color = vec4(0.58, 0.34, 1.0, 1.0);
uniform vec4 east_wing_tint : source_color = vec4(1.0, 0.16, 0.62, 1.0);
uniform float tile_emissive_mult : hint_range(0.0, 2.0) = 0.16;
uniform float halftone_strength : hint_range(0.0, 1.0) = 0.22;

uniform float ink_strength : hint_range(0.0, 1.0) = 0.88;
uniform float ink_expand : hint_range(-1.5, 2.5) = 0.22;
uniform float emissive_boost : hint_range(0.0, 4.0) = 1.65;
uniform float ambient_fill : hint_range(0.0, 0.9) = 0.24;
uniform float specular_strength : hint_range(0.0, 1.5) = 0.48;
uniform float normal_bevel_strength : hint_range(0.0, 2.0) = 0.72;
uniform float fresnel_sheen_strength : hint_range(0.0, 1.0) = 0.22;

// Iluminación viva acoplada a CosmicLightingSampler
uniform vec4 cosmic_shadow_tint : source_color = vec4(0.24, 0.28, 0.46, 1.0);
uniform vec4 cosmic_rim_color : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float cosmic_light_mix : hint_range(0.0, 1.0) = 0.50;

// Desmaterialización / Materialización Tecnológica
uniform bool demat_invert = false;
uniform float demat_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 demat_origin = vec3(0.0);
uniform float demat_max_radius = 30.0;
uniform float demat_hex_scale = 2.4;
uniform vec4 demat_edge_color : source_color = vec4(0.15, 0.95, 1.0, 1.0);

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
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float demat_edge = 0.0;
	float hex_wire = 0.0;
	if (demat_progress > 0.001) {
		float d_origin = length(v_world_pos.xz - demat_origin.xz);
		float hex_d = _hex_cell(v_world_pos.xz * demat_hex_scale);
		float wave_r = mix(-2.5, demat_max_radius, demat_progress);
		float signed_wave = (d_origin + hex_d * 1.1) - wave_r;
		if (!demat_invert) {
			if (signed_wave < 0.0) {
				discard;
			}
			demat_edge = 1.0 - smoothstep(0.0, 2.2, signed_wave);
			hex_wire = smoothstep(0.38, 0.48, hex_d) * (1.0 - smoothstep(2.2, 4.8, signed_wave));
		} else {
			if (signed_wave > 0.0) {
				discard;
			}
			demat_edge = 1.0 - smoothstep(0.0, 2.2, -signed_wave);
			hex_wire = smoothstep(0.38, 0.48, hex_d) * (1.0 - smoothstep(2.2, 4.8, -signed_wave));
		}
	}
	vec2 uv_t = UV * uv_scale;

	vec3 base_rgb = wing_plate_tint.rgb * 0.90;
	vec3 id_m = vec3(0.0, 1.0, 0.0);
	vec4 ilm_m = vec4(0.55, 0.65, 0.45, 0.0);
	float ink_mask = 0.0;
	vec3 normal_map_sample = vec3(0.5, 0.5, 1.0);
	float rough_v = 0.52;
	float cavity_ao = 0.90;
	float metal_v = 0.25;
	vec3 zone_accent_col = pilot_accent_color.rgb;
	float corridor_guide = 0.0;
	float outer_gutter = 0.0;
	float walkway_m = 0.0;
	float west_w = 0.0;
	float ignition_boost = 0.0;
	float contact_ao = 1.0;

	if (enable_deck_zoning) {
		float corridor_z = smoothstep(-9.9, -9.5, v_world_pos.z) * (1.0 - smoothstep(8.2, 8.6, v_world_pos.z));
		walkway_m = (1.0 - smoothstep(3.05, 3.35, abs(v_world_pos.x))) * corridor_z;
		float guide_z = smoothstep(-6.4, -6.0, v_world_pos.z) * (1.0 - smoothstep(5.0, 5.4, v_world_pos.z));
		float d_rail = abs(abs(v_world_pos.x) - 3.22);
		outer_gutter = (1.0 - smoothstep(0.045, 0.085, d_rail)) * guide_z;
		corridor_guide = (1.0 - smoothstep(0.010, 0.032, d_rail)) * guide_z;

		west_w = 1.0 - smoothstep(-7.2, -4.4, v_world_pos.x);
		float east_w = smoothstep(4.4, 7.2, v_world_pos.x);
		zone_accent_col = mix(zone_accent_col, west_wing_tint.rgb, west_w * 0.85);
		zone_accent_col = mix(zone_accent_col, east_wing_tint.rgb, east_w * 0.85);

		float ign_d = length(v_world_pos.xz - vec2(0.0, -7.35));
		float cap_d = length(v_world_pos.xz - vec2(0.0, 1.6));
		ignition_boost = (1.0 - smoothstep(2.0, 3.8, ign_d)) * 0.85 + (1.0 - smoothstep(1.8, 3.2, cap_d)) * 0.55 + walkway_m * 0.35;

		float wall_prox_x = smoothstep(10.5, 12.0, abs(v_world_pos.x));
		float wall_prox_n = 1.0 - smoothstep(-10.6, -9.1, v_world_pos.z);
		contact_ao = mix(1.0, 0.58, clamp(max(wall_prox_x, wall_prox_n), 0.0, 1.0));
	}

	if (has_maps) {
		vec3 raw_alb = texture(albedo_tex, uv_t).rgb;
		id_m = texture(id_mask_tex, uv_t).rgb;
		ilm_m = texture(ilm_mask_tex, uv_t);

		// Tinta vectorial SDF 2x en LOD 0 (sin mipmaps) con ancho consciente de pantalla
		float sdf_sample = textureLod(ink_sdf_tex, uv_t, 0.0).r;
		float sdf_tex = (sdf_sample - 0.5) * 16.0;
		float px_in_texels = max(length(fwidth(uv_t * tex_native_size)), 0.001);
		float sdf_px = sdf_tex / px_in_texels;
		ink_mask = (1.0 - smoothstep(-0.65 + ink_expand, 0.65 + ink_expand, sdf_px)) * ink_strength;

		if (has_pbr_maps) {
			normal_map_sample = texture(normal_map_tex, uv_t).rgb;
			vec3 orm = texture(pbr_orm_tex, uv_t).rgb;
			rough_v = orm.r;
			cavity_ao = orm.g;
			metal_v = orm.b;
		} else {
			// Normal map procedural desde SDF de biseles + canal ILM (relieve real sin mapa externo)
			vec2 tex_step = 1.6 / max(tex_native_size, vec2(256.0));
			float h_c = clamp(sdf_sample * 0.58 + ilm_m.g * 0.30 + ilm_m.r * 0.12, 0.0, 1.0);
			float h_x = clamp(textureLod(ink_sdf_tex, uv_t + vec2(tex_step.x, 0.0), 0.0).r * 0.58 + texture(ilm_mask_tex, uv_t + vec2(tex_step.x, 0.0)).g * 0.30 + texture(ilm_mask_tex, uv_t + vec2(tex_step.x, 0.0)).r * 0.12, 0.0, 1.0);
			float h_y = clamp(textureLod(ink_sdf_tex, uv_t + vec2(0.0, tex_step.y), 0.0).r * 0.58 + texture(ilm_mask_tex, uv_t + vec2(0.0, tex_step.y)).g * 0.30 + texture(ilm_mask_tex, uv_t + vec2(0.0, tex_step.y)).r * 0.12, 0.0, 1.0);
			vec2 grad_uv = vec2(h_c - h_x, h_c - h_y) * (3.2 * normal_bevel_strength);
			float grain = sin(uv_t.x * 180.0) * sin(uv_t.y * 180.0) * 0.025 * normal_bevel_strength;
			vec3 n_tan = normalize(vec3(grad_uv.x + grain, grad_uv.y - grain, 1.0));
			normal_map_sample = n_tan * 0.5 + 0.5;
			rough_v = clamp(1.0 - ilm_m.r * specular_strength * 0.72, 0.18, 0.92);
			cavity_ao = ilm_m.g;
			metal_v = 0.25 * ilm_m.r;
		}

		// Recoloreo Night Hull preservando micro-biseles; atenúa canal rojo periférico para limpieza visual
		float luma = dot(raw_alb, vec3(0.299, 0.587, 0.114));
		float floor_accent_albedo_scale = enable_deck_zoning ? mix(0.28, 0.62, clamp(ignition_boost, 0.0, 1.0)) : 0.78;
		vec3 plate_col = mix(wing_plate_tint.rgb * (0.82 + 0.30 * luma), raw_alb * wing_plate_tint.rgb * 1.15, 0.32);
		vec3 chassis_col = wing_chassis_tint.rgb * (0.85 + 0.38 * luma);
		vec3 accent_col = zone_accent_col * (0.82 + 0.26 * luma) * floor_accent_albedo_scale;

		float w_sum = max(id_m.r + id_m.g + id_m.b, 0.001);
		base_rgb = (accent_col * id_m.r + plate_col * id_m.g + chassis_col * id_m.b) / w_sum;
	} else {
		vec2 cell = fract(uv_t);
		float border = step(cell.x, 0.03) + step(cell.y, 0.03);
		ink_mask = clamp(border, 0.0, 1.0) * ink_strength;
	}

	float masked_guide = 0.0;
	if (enable_deck_zoning) {
		base_rgb *= mix(1.0, 0.82, walkway_m);
		base_rgb *= mix(1.0, 0.88, west_w);
		// Enmascara las líneas guía estrictamente respetando juntas Ink y zanjas
		float plate_surface_mask = clamp((1.0 - ink_mask * 0.85) * mix(0.35, 1.0, id_m.g), 0.0, 1.0);
		float masked_gutter = outer_gutter * plate_surface_mask;
		masked_guide = corridor_guide * plate_surface_mask;
		base_rgb = mix(base_rgb, ink_color.rgb, masked_gutter * 0.72);
		vec3 guide_base = mix(astral_gold_color.rgb, pilot_accent_color.rgb, 0.18);
		base_rgb = mix(base_rgb, guide_base * 0.85, clamp(masked_guide * 0.90, 0.0, 0.95));
	}

	// AO horneado de cavidades + Contact AO perimetral + tinta vectorial encima
	float ao_bias = mix(0.68, 1.04, cavity_ao) * contact_ao;
	base_rgb *= ao_bias;
	base_rgb = mix(base_rgb, ink_color.rgb, ink_mask);

	// Emisión: suelo ambiental discreto + canales HDR acotados + filetes guía dorados + reflejo planar estilizado del Cosmos
	float local_tile_emit = tile_emissive_mult * (1.0 + ignition_boost * 2.0);
	float emit_mask = ilm_m.a * (1.0 - ink_mask * 0.85) * local_tile_emit;
	vec3 eff_shadow = mix(shadow_tint.rgb, cosmic_shadow_tint.rgb, cosmic_light_mix);
	vec3 eff_rim = mix(vec3(0.28, 0.72, 1.0), cosmic_rim_color.rgb, cosmic_light_mix);
	vec3 ambient_floor = base_rgb * eff_shadow * ambient_fill;
	vec3 hdr_channels = zone_accent_col * (emit_mask * emissive_boost * 0.85);
	vec3 guide_hdr = mix(astral_gold_color.rgb, pilot_accent_color.rgb, 0.22) * (masked_guide * emissive_boost * 0.85);
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, 2.8) * fresnel_sheen_strength * (0.35 + (1.0 - rough_v) * 0.65) * (1.0 - ink_mask * 0.7);
	vec3 cosmos_sheen = mix(eff_rim, pilot_accent_color.rgb, 0.30) * fresnel * 0.38;
	vec3 demat_glow = mix(demat_edge_color.rgb, pilot_accent_color.rgb, 0.30) * (demat_edge * 2.8 + hex_wire * 1.35);

	vec3 cosmos_floor_refl = vec3(0.0);
	if (has_cosmos_reflection) {
		vec2 norm_distort = (normal_map_sample.xy - vec2(0.5)) * 0.036;
		vec2 refl_uv = enable_deck_zoning ? vec2(
			clamp(0.5 + v_world_pos.x / 23.0 + norm_distort.x, 0.02, 0.98),
			clamp(0.16 + (v_world_pos.z + 10.5) / 24.0 + norm_distort.y, 0.04, 0.96)
		) : vec2(
			clamp(0.5 + v_world_pos.x / 46.0 + norm_distort.x, 0.02, 0.98),
			clamp(0.5 + v_world_pos.z / 30.0 + norm_distort.y, 0.02, 0.98)
		);
		vec3 refl_c = texture(cosmos_reflection_tex, refl_uv).rgb * 0.40;
		refl_c += texture(cosmos_reflection_tex, clamp(refl_uv + vec2(0.012, 0.0), 0.01, 0.99)).rgb * 0.15;
		refl_c += texture(cosmos_reflection_tex, clamp(refl_uv - vec2(0.012, 0.0), 0.01, 0.99)).rgb * 0.15;
		refl_c += texture(cosmos_reflection_tex, clamp(refl_uv + vec2(0.0, 0.012), 0.01, 0.99)).rgb * 0.15;
		refl_c += texture(cosmos_reflection_tex, clamp(refl_uv - vec2(0.0, 0.012), 0.01, 0.99)).rgb * 0.15;
		float north_falloff = enable_deck_zoning ? smoothstep(11.0, -9.5, v_world_pos.z) : 1.0;
		float refl_weight = clamp((1.0 - rough_v * 0.85) * (0.32 + 0.68 * pow(1.0 - ndv, 1.6)) * (1.0 - ink_mask * 0.92) * north_falloff, 0.0, 1.0);
		cosmos_floor_refl = refl_c * refl_weight * cosmos_reflection_strength;
	}

	ALBEDO = mix(base_rgb, demat_edge_color.rgb, demat_edge * 0.65);
	NORMAL_MAP = normal_map_sample;
	NORMAL_MAP_DEPTH = normal_bevel_strength;
	EMISSION = ambient_floor + hdr_channels + guide_hdr + cosmos_sheen + cosmos_floor_refl + demat_glow;
	METALLIC = metal_v * (1.0 - ink_mask * 0.9);
	ROUGHNESS = mix(rough_v, 0.92, ink_mask * 0.75);
	SPECULAR = mix(0.45, 0.10, rough_v);
}

void light() {
	float lit = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	// Terminador cel-PBR suave compatible con sombras PCF 4K
	float band_mid = smoothstep(0.02, 0.28, lit);
	float band_hi = smoothstep(0.50, 0.78, lit);

	float penumbra = band_mid * (1.0 - band_mid) * 3.2;
	float ht = 0.5 + 0.5 * (sin(FRAGCOORD.x * 0.9) * sin(FRAGCOORD.y * 0.9));
	float cel_intensity = 0.08 + band_mid * 0.62 + band_hi * 0.24;
	cel_intensity *= (1.0 - penumbra * halftone_strength * 0.65 * ht);
	vec3 shadow_bounce = mix(shadow_tint.rgb * 0.22, vec3(1.0), band_mid);
	DIFFUSE_LIGHT = min(DIFFUSE_LIGHT + cel_intensity * LIGHT_COLOR * shadow_bounce, vec3(0.98));

	// Especular metálico nítido respondiendo a biseles de Normal Map y Roughness horneado
	float spec_weight = clamp((1.0 - ROUGHNESS) * 1.35, 0.0, 1.0);
	vec3 h = normalize(LIGHT + VIEW);
	float ndh = max(dot(NORMAL, h), 0.0);
	float spec_band = smoothstep(0.76, 0.92, ndh) * band_mid;
	SPECULAR_LIGHT = min(SPECULAR_LIGHT + spec_band * spec_weight * LIGHT_COLOR * 0.48, vec3(0.58));
}
