shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Shader Cel-Shading ArcSys 3D para el Rail-Lance Autónomo (Guns Lab — Valentina v2).
// Combina rampas de 3 bandas cel-shaded, brillo especular Blinn-Phong nítido,
// rim-light en espacio de vista, núcleo HDR y atenuación atmosférica trasera.

uniform int material_kind = 0; // 0 = placas armadura, 1 = chasis oscuro, 2 = cristal/energía
uniform vec4 base_color : source_color = vec4(0.88, 0.92, 0.97, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.52, 0.55, 0.72, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 key_light_dir = vec3(-0.48, 0.68, 0.55);
uniform vec4 key_light_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float key_light_boost : hint_range(0.3, 2.0) = 1.0;
uniform float emissive_boost : hint_range(0.5, 2.5) = 1.0;

uniform vec4 rim_color : source_color = vec4(0.84, 0.92, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 1.5) = 0.55;
uniform float specular_sweep_strength : hint_range(0.0, 1.5) = 0.42;

uniform float orbit_depth : hint_range(-1.0, 1.0) = 0.0;
uniform float depth_back_dim : hint_range(0.0, 0.8) = 0.28;
uniform vec4 depth_back_tint : source_color = vec4(0.32, 0.36, 0.62, 1.0);

uniform float fire_flash : hint_range(0.0, 2.5) = 0.0;
uniform vec4 fire_glow_color : source_color = vec4(0.95, 0.18, 0.36, 1.0);

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	vec3 l = normalize(key_light_dir);
	float ndl = dot(n, l);

	vec3 rgb = base_color.rgb;

	if (material_kind == 2) {
		// Cristal facetado y conductos energéticos: alto contraste + brillo HDR
		float band_mid = smoothstep(-0.18, -0.02, ndl);
		float band_hi = smoothstep(0.45, 0.58, ndl);
		vec3 c_sh = base_color.rgb * vec3(0.42, 0.35, 0.52);
		vec3 c_mid = base_color.rgb * 1.12 * mix(vec3(1.0), key_light_tint.rgb, 0.35);
		vec3 c_hi = mix(base_color.rgb * 1.35 * mix(vec3(1.0), key_light_tint.rgb, 0.35), highlight_color.rgb, 0.52);
		rgb = mix(c_sh, c_mid, band_mid);
		rgb = mix(rgb, c_hi, band_hi);

		// Emisión permanente sutil + destello intenso al disparar (realzada en eclipse)
		rgb += fire_glow_color.rgb * (0.32 * emissive_boost + fire_flash * 1.45);
	} else {
		float sh_mul = (material_kind == 1) ? 0.58 : 1.0;
		float band_mid = smoothstep(-0.08, 0.04, ndl);
		float band_hi = smoothstep(0.64, 0.74, ndl);

		vec3 c_sh = base_color.rgb * shadow_tint.rgb * sh_mul;
		vec3 c_mid = base_color.rgb * key_light_tint.rgb * key_light_boost;
		vec3 c_hi = mix(base_color.rgb * 1.20 * key_light_tint.rgb * key_light_boost, highlight_color.rgb * key_light_tint.rgb, (material_kind == 0) ? 0.45 : 0.18);

		rgb = mix(c_sh, c_mid, band_mid);
		rgb = mix(rgb, c_hi, band_hi);

		// Reflejo especular metálico nítido estilo ArcSys
		vec3 h = normalize(l + v);
		float ndh = max(dot(n, h), 0.0);
		float spec = smoothstep(0.86, 0.93, ndh) * specular_sweep_strength;
		float spec_scale = (material_kind == 0) ? 1.0 : 0.45;
		rgb += mix(base_color.rgb, key_light_tint.rgb, 0.75) * spec * spec_scale * key_light_boost;

		// Iluminación de retroalimentación durante el disparo
		if (fire_flash > 0.001) {
			float muzzle_bounce = smoothstep(-0.2, 0.6, -n.z) * 0.32;
			rgb += fire_glow_color.rgb * muzzle_bounce * fire_flash;
		}
	}

	// Rim-light en silueta
	float ndv = clamp(abs(dot(n, v)), 0.0, 1.0);
	float rim = smoothstep(0.45, 0.85, pow(1.0 - ndv, 2.4)) * rim_strength;
	float front_boost = mix(0.45, 1.15, orbit_depth * 0.5 + 0.5);
	rgb += rim_color.rgb * rim * front_boost * ((material_kind == 1) ? 0.45 : 0.85);

	// Atenuación atmosférica cuando orbita detrás de Valentina
	float back_factor = clamp(-orbit_depth, 0.0, 1.0);
	if (back_factor > 0.001 && depth_back_dim > 0.001) {
		float dim_amt = back_factor * depth_back_dim;
		rgb = mix(rgb, rgb * depth_back_tint.rgb, dim_amt * 0.85);
		rgb *= (1.0 - dim_amt * 0.35);
	}

	ALBEDO = rgb;
}
