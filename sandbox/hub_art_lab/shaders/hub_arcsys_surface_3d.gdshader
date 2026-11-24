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

uniform bool has_maps = false;
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
uniform float specular_strength : hint_range(0.0, 1.5) = 0.36;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv_t = UV * uv_scale;

	vec3 base_rgb = wing_plate_tint.rgb * 0.90;
	vec3 id_m = vec3(0.0, 1.0, 0.0);
	vec4 ilm_m = vec4(0.55, 0.65, 0.45, 0.0);
	float ink_mask = 0.0;
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

		float ign_d = length(v_world_pos.xz - vec2(0.0, -8.2));
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

		// Recoloreo Night Hull preservando micro-biseles; atenúa el canal rojo exterior del suelo
		float luma = dot(raw_alb, vec3(0.299, 0.587, 0.114));
		float floor_accent_albedo_scale = enable_deck_zoning ? mix(0.45, 0.85, clamp(ignition_boost, 0.0, 1.0)) : 1.0;
		vec3 plate_col = mix(wing_plate_tint.rgb * (0.78 + 0.34 * luma), raw_alb * wing_plate_tint.rgb * 1.12, 0.35);
		vec3 chassis_col = wing_chassis_tint.rgb * (0.72 + 0.45 * luma);
		vec3 accent_col = zone_accent_col * (0.85 + 0.30 * luma) * floor_accent_albedo_scale;

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

	// AO del mapa ILM + Contact AO perimetral + tinta vectorial encima
	float ao_bias = mix(0.84, 1.04, ilm_m.g) * contact_ao;
	base_rgb *= ao_bias;
	base_rgb = mix(base_rgb, ink_color.rgb, ink_mask);

	// Emisión: suelo ambiental discreto + canales HDR acotados + filetes guía dorados afilados
	float local_tile_emit = tile_emissive_mult * (1.0 + ignition_boost * 2.0);
	float emit_mask = ilm_m.a * (1.0 - ink_mask * 0.85) * local_tile_emit;
	vec3 ambient_floor = base_rgb * shadow_tint.rgb * ambient_fill;
	vec3 hdr_channels = zone_accent_col * (emit_mask * emissive_boost * 0.85);
	vec3 guide_hdr = mix(astral_gold_color.rgb, pilot_accent_color.rgb, 0.22) * (masked_guide * emissive_boost * 0.85);

	ALBEDO = base_rgb;
	EMISSION = ambient_floor + hdr_channels + guide_hdr;
	METALLIC = 0.0;
	ROUGHNESS = clamp(1.0 - ilm_m.r * specular_strength * 0.65, 0.16, 1.0);
	SPECULAR = 0.0;
}

void light() {
	float lit = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	float band_mid = smoothstep(0.04, 0.16, lit);
	float band_hi = smoothstep(0.58, 0.70, lit);

	// Paso cel-shading calibrado (< 0.85 lineal para cero bloom accidental) + halftone en penumbra
	float penumbra = band_mid * (1.0 - band_mid) * 4.0;
	float ht = 0.5 + 0.5 * (sin(FRAGCOORD.x * 0.9) * sin(FRAGCOORD.y * 0.9));
	float cel_intensity = band_mid * 0.62 + band_hi * 0.22;
	cel_intensity *= (1.0 - penumbra * halftone_strength * ht);
	DIFFUSE_LIGHT += cel_intensity * LIGHT_COLOR;

	// Especular cel estrecho modulado por el canal R de ILM
	float spec_weight = clamp((1.0 - ROUGHNESS) * 1.25, 0.0, 1.0);
	vec3 h = normalize(LIGHT + VIEW);
	float ndh = max(dot(NORMAL, h), 0.0);
	float spec_band = smoothstep(0.88, 0.94, ndh) * band_mid;
	SPECULAR_LIGHT += spec_band * spec_weight * LIGHT_COLOR * 0.24;
}
