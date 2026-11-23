shader_type canvas_item;
render_mode blend_mix, unshaded;

// universe_nebula.gdshader
// Shader de estratos nebulares procedurales cósmicos y biomas con anti-tiling descorrelacionado.
// Incorpora FBM simplex/gradient en GPU con dispersión cromática angular y blending smoothstep de biomas.

uniform vec2 camera_world_position = vec2(0.0);
uniform vec2 viewport_resolution = vec2(1920.0, 1080.0);
uniform float parallax_factor : hint_range(0.0, 1.0) = 0.05;
uniform float global_time = 0.0;

// Lecho estelar 8K de fondo casi inmóvil (mezclado con el polvo cósmico)
uniform sampler2D deep_starfield_texture : repeat_enable, filter_linear;
uniform float deep_stars_intensity : hint_range(0.0, 3.0) = 0.55;
uniform float deep_stars_parallax : hint_range(0.0, 0.05) = 0.006;
uniform float deep_stars_scale : hint_range(0.1, 10.0) = 2.8;
uniform float deep_stars_twinkle_speed : hint_range(0.1, 10.0) = 2.2;
uniform float deep_stars_sparkle_intensity : hint_range(0.0, 2.0) = 0.85;
uniform float deep_stars_halo_radius : hint_range(0.1, 3.0) = 1.35;
uniform float deep_stars_gas_interaction : hint_range(0.0, 2.0) = 0.75;

// Segundo estrato estelar 8K (desactivado en shader cuando se usa capa física dedicada en layer -105)
uniform float mid_stars_intensity : hint_range(0.0, 5.0) = 0.0;
uniform float mid_stars_parallax : hint_range(0.0, 0.05) = 0.0065;
uniform float mid_stars_scale : hint_range(0.1, 10.0) = 1.35;
uniform float mid_stars_twinkle_speed : hint_range(0.1, 10.0) = 2.4;
uniform float mid_stars_sparkle_intensity : hint_range(0.0, 3.0) = 1.4;
uniform float mid_stars_halo_radius : hint_range(0.1, 4.0) = 1.8;
uniform float mid_stars_gas_interaction : hint_range(0.0, 2.0) = 0.85;

// Texturas de nebulosa anime seamless (1024x1024) moduladas con FBM
uniform sampler2D nebula_tile_texture : repeat_enable, filter_linear_mipmap;
uniform sampler2D nebula_wisps_texture : repeat_enable, filter_linear_mipmap;
uniform float nebula_tile_scale : hint_range(0.00005, 0.005) = 0.00040;
uniform float nebula_tile_mix : hint_range(0.0, 1.0) = 0.72;
uniform float dark_dust_lane_strength : hint_range(0.0, 1.0) = 0.62;

// Configuración Bioma A
uniform vec4 biome_a_color_deep : source_color = vec4(0.004, 0.005, 0.020, 1.0);
uniform vec4 biome_a_color_gas_primary : source_color = vec4(0.24, 0.06, 0.48, 0.86);
uniform vec4 biome_a_color_gas_secondary : source_color = vec4(0.04, 0.30, 0.56, 0.78);
uniform vec4 biome_a_color_ridge : source_color = vec4(0.96, 0.50, 0.86, 1.0);
uniform vec4 biome_a_star_tint : source_color = vec4(0.90, 0.94, 1.0, 1.0);
uniform float biome_a_density : hint_range(0.1, 3.0) = 1.28;
uniform float biome_a_contrast : hint_range(0.5, 4.0) = 2.40;
uniform float biome_a_frequency : hint_range(0.00001, 0.005) = 0.00062;
uniform float biome_a_band_strength : hint_range(0.0, 1.0) = 0.38;

// Configuración Bioma B
uniform vec4 biome_b_color_deep : source_color = vec4(0.007, 0.004, 0.016, 1.0);
uniform vec4 biome_b_color_gas_primary : source_color = vec4(0.36, 0.05, 0.16, 0.86);
uniform vec4 biome_b_color_gas_secondary : source_color = vec4(0.56, 0.22, 0.05, 0.76);
uniform vec4 biome_b_color_ridge : source_color = vec4(1.0, 0.80, 0.38, 1.0);
uniform vec4 biome_b_star_tint : source_color = vec4(1.0, 0.90, 0.70, 1.0);
uniform float biome_b_density : hint_range(0.1, 3.0) = 1.26;
uniform float biome_b_contrast : hint_range(0.5, 4.0) = 2.55;
uniform float biome_b_frequency : hint_range(0.00001, 0.005) = 0.00068;
uniform float biome_b_band_strength : hint_range(0.0, 1.0) = 0.36;

// Factor de mezcla continua entre Bioma A y Bioma B [0.0 = Solo A, 1.0 = Solo B]
uniform float biome_blend_factor : hint_range(0.0, 1.0) = 0.0;

// Fuentes de luz estelar dinámicas (Soles activos en el cosmos)
const int MAX_STAR_LIGHTS = 4;
uniform vec2 star_light_positions[4];
uniform vec4 star_light_colors[4];
uniform float star_light_radii[4];
uniform int star_light_count : hint_range(0, 4) = 0;

// Parámetros ópticos y dispersión
uniform float chromatic_dispersion : hint_range(0.0, 0.05) = 0.004;
uniform float flow_drift_speed : hint_range(0.0, 0.1) = 0.012;

// Estilizado Anime Space-Opera y protección de legibilidad danmaku
uniform float stylized_banding_strength : hint_range(0.0, 1.0) = 0.12;
uniform float filament_sharpness : hint_range(0.5, 3.0) = 1.65;
uniform float nebula_vibrance : hint_range(0.5, 1.8) = 1.28;
uniform float max_bg_luma : hint_range(0.25, 1.2) = 0.52;

// Generador de gradiente pseudoaleatorio 2D
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// Gradient Noise suave 2D
float gradient_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
	               dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
	           mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
	               dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

// FBM de 4 octavas con dominio rotatorio para remolinos de gas
float fbm_nebula(vec2 st, float freq) {
	vec2 p = st * freq;
	float value = 0.0;
	float amp = 0.55;
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));

	for (int i = 0; i < 4; i++) {
		value += amp * gradient_noise(p);
		p = rot * p * 2.05 + vec2(1.3, 2.7);
		amp *= 0.5;
	}
	return (value + 0.5); // Rango aproximado [0.0, 1.0]
}

// Función sample_starfield_anti_tile: doble muestreo descorrelacionado para evitar repetición
float sample_starfield_anti_tile(vec2 p, float freq) {
	vec2 sample_a = p;
	// Desplazamiento no coplanar con rotación áurea (anti-tile)
	vec2 sample_b = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * p + vec2(429.31, 881.19);

	float n_a = fbm_nebula(sample_a, freq);
	float n_b = fbm_nebula(sample_b, freq * 1.13);

	// Combinación no lineal que desvanece cualquier grilla o artefacto periódico
	return mix(n_a, n_b, 0.5);
}

void fragment() {
	// Proyección de posición espacial continua del fragmento en el universo
	vec2 screen_coord = SCREEN_UV * viewport_resolution;
	vec2 world_sample_pos = camera_world_position * parallax_factor + (screen_coord - viewport_resolution * 0.5);

	// Flujo temporal cósmico sutil
	float drift = global_time * flow_drift_speed;
	vec2 flow_vec = vec2(drift * 0.7, -drift * 0.5);
	vec2 sample_p = world_sample_pos + flow_vec;

	// Dispersión cromática angular en canales RGB
	vec2 offset_r = vec2(chromatic_dispersion * 120.0, 0.0);
	vec2 offset_g = vec2(0.0);
	vec2 offset_b = vec2(-chromatic_dispersion * 120.0, 0.0);

	// Muestreo Bioma A
	float gas_a_r = sample_starfield_anti_tile(sample_p + offset_r, biome_a_frequency);
	float gas_a_g = sample_starfield_anti_tile(sample_p + offset_g, biome_a_frequency);
	float gas_a_b = sample_starfield_anti_tile(sample_p + offset_b, biome_a_frequency);
	float gas_a = (gas_a_r + gas_a_g + gas_a_b) * 0.333333;

	// Muestreo Bioma B
	float gas_b_r = sample_starfield_anti_tile(sample_p + offset_r, biome_b_frequency);
	float gas_b_g = sample_starfield_anti_tile(sample_p + offset_g, biome_b_frequency);
	float gas_b_b = sample_starfield_anti_tile(sample_p + offset_b, biome_b_frequency);
	float gas_b = (gas_b_r + gas_b_g + gas_b_b) * 0.333333;

	// Warp de dominio orgánico + dual-depth anime filaments/wisps + crestas de fotoionización JWST/Shinkai
	vec2 warp = vec2(
		gradient_noise(sample_p * biome_a_frequency * 1.45),
		gradient_noise(sample_p * biome_a_frequency * 1.45 + vec2(37.2, 81.9))
	) * 340.0;
	float hue_field = fbm_nebula(sample_p + vec2(913.4, -521.7) + warp * 0.40, (biome_a_frequency + biome_b_frequency) * 0.44);
	float carve_field = fbm_nebula(sample_p + vec2(-412.6, 678.3) - warp * 0.30, (biome_a_frequency + biome_b_frequency) * 0.72);

	float dust_carve = 1.0;
	float anime_cloud = 0.55;
	float fil_density = 0.40;
	float wisp_density = 0.35;
	float ridge_mask = 0.0;
	if (nebula_tile_mix > 0.001) {
		vec2 centered_sc = screen_coord - viewport_resolution * 0.5;
		vec2 far_p = camera_world_position * (parallax_factor * 0.35) + centered_sc + flow_vec * 0.45 + warp * 0.65;
		vec2 near_p = camera_world_position * (parallax_factor * 1.85) + centered_sc + vec2(drift * 1.25, -drift * 0.85) - warp * 0.45;
		vec2 tile_uv = far_p * nebula_tile_scale;
		vec2 wisp_uv = (mat2(vec2(0.866, -0.5), vec2(0.5, 0.866)) * near_p) * (nebula_tile_scale * 1.37);
		fil_density = texture(nebula_tile_texture, tile_uv).r;
		wisp_density = texture(nebula_wisps_texture, wisp_uv).r;

		vec2 illum_dir = vec2(-0.72, -0.69);
		float fil_off = texture(nebula_tile_texture, tile_uv - illum_dir * 0.015).r;
		float wisp_off = texture(nebula_wisps_texture, wisp_uv - illum_dir * 0.018).r;
		float cloud_off = clamp(fil_off * 0.66 + wisp_off * 0.54, 0.0, 1.35);

		float nebula_breath = 0.94 + 0.06 * sin(global_time * 0.24 + fil_density * 4.5);
		anime_cloud = clamp(fil_density * 0.66 + wisp_density * 0.54, 0.0, 1.35) * nebula_breath;

		// Conservar el cuerpo amplio FBM para bóvedas ricas de nebulosa + tallar grietas oscuras específicas sin apagar el cielo
		float macro_a = clamp(gas_a * 0.82 + anime_cloud * 0.44, 0.0, 1.35);
		float macro_b = clamp(gas_b * 0.82 + anime_cloud * 0.44, 0.0, 1.35);
		gas_a = mix(gas_a, macro_a, nebula_tile_mix);
		gas_b = mix(gas_b, macro_b, nebula_tile_mix);

		float dark_pocket = (1.0 - smoothstep(0.06, 0.28, fil_density + wisp_density * 0.35)) * (1.0 - smoothstep(0.28, 0.62, carve_field));
		dust_carve = 1.0 - dark_pocket * dark_dust_lane_strength;
		ridge_mask = clamp((anime_cloud - cloud_off) * 3.0, 0.0, 1.0) * smoothstep(0.10, 0.68, anime_cloud) * dust_carve;
	}

	// Curvas volumétricas pictóricas de 3 temperaturas (sin bloques planos ni vaciado excesivo)
	float raw_a = smoothstep(0.10, 0.84, gas_a * biome_a_density);
	float raw_b = smoothstep(0.10, 0.84, gas_b * biome_b_density);
	float cont_a = pow(raw_a, biome_a_contrast * 0.36);
	float cont_b = pow(raw_b, biome_b_contrast * 0.36);
	float cel_a = (smoothstep(0.14, 0.34, raw_a) * 0.34 + smoothstep(0.40, 0.62, raw_a) * 0.38 + smoothstep(0.68, 0.90, raw_a) * 0.28);
	float cel_b = (smoothstep(0.14, 0.34, raw_b) * 0.34 + smoothstep(0.40, 0.62, raw_b) * 0.38 + smoothstep(0.68, 0.90, raw_b) * 0.28);
	float intensity_a = mix(cont_a, cel_a, stylized_banding_strength) * dust_carve;
	float intensity_b = mix(cont_b, cel_b, stylized_banding_strength) * dust_carve;

	float fil_a = pow(clamp(raw_a * (1.0 - raw_a) * 4.0, 0.0, 1.0), filament_sharpness);
	float fil_b = pow(clamp(raw_b * (1.0 - raw_b) * 4.0, 0.0, 1.0), filament_sharpness);

	// Dos temperaturas tejidas + cresta de fotoionización luminosa sobre bordes de polvo oscuro
	float temp_mix_a = clamp(smoothstep(0.20, 0.80, hue_field * 0.60 + wisp_density * 0.40), 0.0, 1.0);
	float temp_mix_b = clamp(smoothstep(0.20, 0.80, (1.0 - hue_field * 0.50) * 0.50 + wisp_density * 0.50), 0.0, 1.0);

	vec3 col_gas_a = mix(biome_a_color_gas_primary.rgb, biome_a_color_gas_secondary.rgb, mix(gas_a_b, temp_mix_a, 0.72));
	col_gas_a = mix(col_gas_a, biome_a_color_ridge.rgb, clamp(ridge_mask * 0.68 + fil_a * 0.14, 0.0, 0.80));
	vec3 final_a = mix(biome_a_color_deep.rgb, col_gas_a * 1.15, intensity_a);
	final_a += biome_a_color_ridge.rgb * (ridge_mask * 0.30 * (0.30 + intensity_a * 0.70));

	vec3 col_gas_b = mix(biome_b_color_gas_primary.rgb, biome_b_color_gas_secondary.rgb, mix(gas_b_b, temp_mix_b, 0.72));
	col_gas_b = mix(col_gas_b, biome_b_color_ridge.rgb, clamp(ridge_mask * 0.68 + fil_b * 0.14, 0.0, 0.80));
	vec3 final_b = mix(biome_b_color_deep.rgb, col_gas_b * 1.15, intensity_b);
	final_b += biome_b_color_ridge.rgb * (ridge_mask * 0.30 * (0.30 + intensity_b * 0.70));

	// Transición suave entre biomas según biome_blend_factor (smoothstep)
	float blend = smoothstep(0.0, 1.0, biome_blend_factor);
	vec3 combined_color = mix(final_a, final_b, blend);
	float combined_alpha = mix(
		clamp(intensity_a * max(biome_a_color_gas_primary.a, biome_a_color_gas_secondary.a), 0.0, 1.0),
		clamp(intensity_b * max(biome_b_color_gas_primary.a, biome_b_color_gas_secondary.a), 0.0, 1.0),
		blend
	);

	// Espina Galáctica / Río de Vía Láctea diagonal periódico con nubes estelares y grietas oscuras
	float eff_band_str = mix(biome_a_band_strength, biome_b_band_strength, blend);
	float galactic_mask = 0.0;
	if (eff_band_str > 0.01) {
		vec2 spine_p = camera_world_position * (parallax_factor * 0.22) + (screen_coord - viewport_resolution * 0.5);
		vec2 spine_rot = mat2(vec2(0.848, -0.530), vec2(0.530, 0.848)) * spine_p * 0.00038;
		float wrapped_y = (fract(spine_rot.y * 0.28 + 0.5) - 0.5) / 0.28;
		float spine_y = wrapped_y + sin(spine_rot.x * 1.8) * 0.22 + (hue_field - 0.5) * 0.34;
		float gal_core = exp(-pow(spine_y * 1.35, 2.0)) * (0.58 + 0.42 * clamp(anime_cloud + fil_density * 0.5, 0.0, 1.2));
		float rift_carve = 1.0 - 0.60 * exp(-pow((spine_y - 0.06) * 5.8, 2.0)) * clamp(1.0 - wisp_density * 0.85, 0.0, 1.0);
		galactic_mask = gal_core * rift_carve * eff_band_str;
		vec3 active_sec = mix(biome_a_color_gas_secondary.rgb, biome_b_color_gas_secondary.rgb, blend);
		vec3 active_ridge = mix(biome_a_color_ridge.rgb, biome_b_color_ridge.rgb, blend);
		vec3 spine_col = mix(active_sec * 0.95, active_ridge * 1.1, 0.52) * (galactic_mask * 0.68);
		combined_color += spine_col;
	}

	// Iluminación acumulada lineal C² sin costuras entre soles (un único tone-map posterior)
	vec3 star_tint_accum = vec3(0.0);
	vec3 star_scatter_accum = vec3(0.0);
	float star_weight_sum = 0.0;
	float gas_presence = clamp(max(intensity_a, intensity_b) * 0.85 + ridge_mask * 0.35 + galactic_mask * 0.25, 0.0, 1.0);
	for (int i = 0; i < MAX_STAR_LIGHTS; i++) {
		if (i >= star_light_count) {
			break;
		}
		vec2 s_pos = star_light_positions[i];
		vec4 s_col = star_light_colors[i];
		float s_rad = max(star_light_radii[i], 1.0);
		float s_dist = length(screen_coord - s_pos);
		if (s_dist < s_rad) {
			float u = clamp(1.0 - (s_dist / s_rad), 0.0, 1.0);
			float quintic = u * u * u * (u * (u * 6.0 - 15.0) + 10.0);
			float w = pow(quintic, 1.15) * s_col.a;
			star_tint_accum += s_col.rgb * w;
			star_scatter_accum += s_col.rgb * (w * 0.16 * gas_presence);
			star_weight_sum += w;
		}
	}
	if (star_weight_sum > 0.0005) {
		vec3 avg_star_col = star_tint_accum / max(star_weight_sum, 0.0005);
		float eff_tint_w = clamp(star_weight_sum * 0.62, 0.0, 0.72);
		vec3 tinted_gas = mix(combined_color, combined_color * avg_star_col * 1.32, eff_tint_w);
		vec3 lit_result = tinted_gas + star_scatter_accum;
		combined_color = lit_result / (vec3(1.0) + lit_result * 0.18);
		combined_alpha = clamp(combined_alpha + min(star_weight_sum, 1.0) * 0.10 * gas_presence, 0.0, 1.0);
	}

	// Vibrancia cromática del gas y tope suave de luminancia para legibilidad danmaku
	float gas_luma = dot(combined_color, vec3(0.2126, 0.7152, 0.0722));
	combined_color = max(vec3(0.0), mix(vec3(gas_luma), combined_color, nebula_vibrance));
	float luma_post = dot(combined_color, vec3(0.2126, 0.7152, 0.0722));
	if (luma_post > max_bg_luma) {
		float soft_luma = max_bg_luma + (luma_post - max_bg_luma) * 0.22;
		combined_color *= soft_luma / max(luma_post, 0.0001);
	}

	// Muestreo continuo bilineal directo del lecho de micro-estrellas (nivel MIP 0 estable sin aliasing):
	const float BUFFER_SIZE = 8192.0;
	vec2 deep_star_world_pos = camera_world_position * deep_stars_parallax + (screen_coord - viewport_resolution * 0.5);
	vec2 deep_star_uv = (deep_star_world_pos * deep_stars_scale) / BUFFER_SIZE;
	
	vec3 deep_star_raw = textureLod(deep_starfield_texture, deep_star_uv, 0.0).rgb;
	float deep_star_max = max(deep_star_raw.r, max(deep_star_raw.g, deep_star_raw.b));

	// Curva analítica continua de contraste y descarte de ruido de fondo
	float star_normalized = smoothstep(0.025, 0.70, deep_star_max);
	float effective_star_luma = pow(star_normalized, 1.4);
	
	if (effective_star_luma > 0.005) {
		// Semillas pseudoaleatorias suavizadas (filtro bilineal en la grilla de bloques para evitar cortes en cuadrado)
		vec2 star_grid_pos = deep_star_uv * 2048.0;
		vec2 grid_i = floor(star_grid_pos);
		vec2 grid_f = fract(star_grid_pos);
		vec2 smooth_f = grid_f * grid_f * (3.0 - 2.0 * grid_f);

		float s00 = fract(sin(dot(grid_i, vec2(127.1, 311.7))) * 43758.5453);
		float s10 = fract(sin(dot(grid_i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
		float s01 = fract(sin(dot(grid_i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
		float s11 = fract(sin(dot(grid_i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
		float star_seed = mix(mix(s00, s10, smooth_f.x), mix(s01, s11, smooth_f.x), smooth_f.y);

		float s2_00 = fract(sin(dot(grid_i + vec2(43.12, 91.73), vec2(269.5, 183.3))) * 28461.183);
		float s2_10 = fract(sin(dot(grid_i + vec2(44.12, 91.73), vec2(269.5, 183.3))) * 28461.183);
		float s2_01 = fract(sin(dot(grid_i + vec2(43.12, 92.73), vec2(269.5, 183.3))) * 28461.183);
		float s2_11 = fract(sin(dot(grid_i + vec2(44.12, 92.73), vec2(269.5, 183.3))) * 28461.183);
		float star_seed2 = mix(mix(s2_00, s2_10, smooth_f.x), mix(s2_01, s2_11, smooth_f.x), smooth_f.y);

		// Clasificación espectral estocástica rica (tonos cálidos, dorados, zafiro y exóticos)
		vec3 star_color;
		if (star_seed < 0.35) {
			star_color = mix(vec3(1.95, 0.50, 0.22), vec3(1.85, 0.80, 0.28), star_seed2); // Rubí cálido / Ámbar
		} else if (star_seed < 0.65) {
			star_color = mix(vec3(1.80, 1.55, 0.45), vec3(1.35, 1.35, 1.10), star_seed2); // Sol dorado / Blanco marfil
		} else if (star_seed < 0.90) {
			star_color = mix(vec3(0.45, 1.15, 2.30), vec3(0.65, 1.60, 2.10), star_seed2); // Gigante azul eléctrico
		} else {
			star_color = mix(vec3(1.45, 0.55, 2.15), vec3(0.35, 1.90, 1.25), star_seed2); // Violeta / Esmeralda
		}
		
		// Matizar con el tinte estelar armónico de los biomas activos
		vec3 biome_star_tint = mix(biome_a_star_tint.rgb, biome_b_star_tint.rgb, blend);
		star_color *= biome_star_tint;

		// Variación de magnitud orgánica (evita que todas parezcan del mismo brillo)
		float star_mag = 0.60 + star_seed2 * 0.85;

		// 1. Destellos y centelleo continuo suave
		float time_now = global_time * deep_stars_twinkle_speed;
		float star_freq = 0.85 + star_seed2 * 0.95;
		float star_phase = star_seed * 6.2831853;
		
		float wave_a = sin(time_now * star_freq + star_phase);
		float wave_b = sin(time_now * (star_freq * 2.31) + star_phase * 1.618);
		float composite_wave = (wave_a * 0.65 + wave_b * 0.35);
		
		float spike_raw = max(0.0, composite_wave);
		float sharp_sparkle = pow(spike_raw, 5.0) * deep_stars_sparkle_intensity * 1.8;
		float twinkle_factor = 0.65 + 0.35 * composite_wave + sharp_sparkle;

		// 2. Resplandor y cuerpo estelar continuo
		float base_falloff = effective_star_luma;
		float halo = pow(star_normalized, 2.2) * deep_stars_halo_radius * 0.6;
		
		vec3 colored_body = star_color * (base_falloff * 2.2 + halo) * twinkle_factor;
		float core_peak = pow(star_normalized, 3.2) * (1.0 + sharp_sparkle * 1.2);
		vec3 incandescent_core = (star_color * 1.5 + vec3(0.20)) * (core_peak * 0.40);

		vec3 deep_stars = (colored_body + incandescent_core) * deep_stars_intensity * star_mag;

		// 3. Integración volumétrica y perforación a través del gas denso (punch-through)
		float local_gas_density = clamp(intensity_a + intensity_b, 0.0, 1.0);
		vec3 local_gas_color = mix(col_gas_a, col_gas_b, blend);
		vec3 gas_illumination = star_color * local_gas_color * (deep_star_max * 1.8) * local_gas_density * deep_stars_gas_interaction * twinkle_factor;
		
		// Las estrellas atraviesan e iluminan el gas espeso con mayor potencia
		float gas_punch_through = 1.0 + local_gas_density * 1.5;
		combined_color += (deep_stars * gas_punch_through) + gas_illumination;
	}

	// Segundo estrato estelar (Mid-Stars medianas más cercanas, con mayor tamaño y paralaje intermedio):
	if (mid_stars_intensity > 0.01) {
		vec2 mid_star_world_pos = camera_world_position * mid_stars_parallax + (screen_coord - viewport_resolution * 0.5);
		vec2 mid_star_uv = (mid_star_world_pos * mid_stars_scale) / BUFFER_SIZE;
		
		vec3 mid_star_raw = textureLod(deep_starfield_texture, mid_star_uv, 0.0).rgb;
		float mid_star_max = max(mid_star_raw.r, max(mid_star_raw.g, mid_star_raw.b));
		
		float mid_normalized = smoothstep(0.02, 0.75, mid_star_max);
		float mid_effective_luma = pow(mid_normalized, 1.3);
		
		if (mid_effective_luma > 0.005) {
			vec2 mid_grid_pos = mid_star_uv * 1024.0;
			vec2 m_grid_i = floor(mid_grid_pos);
			vec2 m_grid_f = fract(mid_grid_pos);
			vec2 m_smooth_f = m_grid_f * m_grid_f * (3.0 - 2.0 * m_grid_f);

			float ms00 = fract(sin(dot(m_grid_i, vec2(127.1, 311.7))) * 43758.5453);
			float ms10 = fract(sin(dot(m_grid_i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
			float ms01 = fract(sin(dot(m_grid_i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
			float ms11 = fract(sin(dot(m_grid_i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
			float star_seed = mix(mix(ms00, ms10, m_smooth_f.x), mix(ms01, ms11, m_smooth_f.x), m_smooth_f.y);

			float ms2_00 = fract(sin(dot(m_grid_i + vec2(43.12, 91.73), vec2(269.5, 183.3))) * 28461.183);
			float ms2_10 = fract(sin(dot(m_grid_i + vec2(44.12, 91.73), vec2(269.5, 183.3))) * 28461.183);
			float ms2_01 = fract(sin(dot(m_grid_i + vec2(43.12, 92.73), vec2(269.5, 183.3))) * 28461.183);
			float ms2_11 = fract(sin(dot(m_grid_i + vec2(44.12, 92.73), vec2(269.5, 183.3))) * 28461.183);
			float star_seed2 = mix(mix(ms2_00, ms2_10, m_smooth_f.x), mix(ms2_01, ms2_11, m_smooth_f.x), m_smooth_f.y);

			vec3 star_color;
			if (star_seed < 0.35) {
				star_color = mix(vec3(1.95, 0.50, 0.22), vec3(1.85, 0.80, 0.28), star_seed2);
			} else if (star_seed < 0.65) {
				star_color = mix(vec3(1.80, 1.55, 0.45), vec3(1.35, 1.35, 1.10), star_seed2);
			} else if (star_seed < 0.90) {
				star_color = mix(vec3(0.45, 1.15, 2.30), vec3(0.65, 1.60, 2.10), star_seed2);
			} else {
				star_color = mix(vec3(1.45, 0.55, 2.15), vec3(0.35, 1.90, 1.25), star_seed2);
			}

			vec3 biome_star_tint = mix(biome_a_star_tint.rgb, biome_b_star_tint.rgb, blend);
			star_color *= biome_star_tint;
			
			float star_mag = 0.65 + star_seed2 * 0.80;

			float time_now = (global_time > 0.001 ? global_time : TIME) * mid_stars_twinkle_speed;
			float star_freq = 0.85 + star_seed2 * 0.95;
			float star_phase = star_seed * 6.2831853;
			
			float wave_a = sin(time_now * star_freq + star_phase);
			float wave_b = sin(time_now * (star_freq * 2.31) + star_phase * 1.618);
			float composite_wave = (wave_a * 0.65 + wave_b * 0.35);
			
			float spike_raw = max(0.0, composite_wave);
			float sharp_sparkle = pow(spike_raw, 5.0) * mid_stars_sparkle_intensity * 1.8;
			float twinkle_factor = 0.65 + 0.35 * composite_wave + sharp_sparkle;
			
			// Disco esférico expandido con halo amplio y núcleo incandescente
			float base_falloff = mid_effective_luma;
			float halo = pow(mid_normalized, 2.0) * mid_stars_halo_radius * 0.75;
			
			vec3 colored_body = star_color * (base_falloff * 2.5 + halo) * twinkle_factor;
			float core_peak = pow(mid_normalized, 2.8) * (1.0 + sharp_sparkle * 1.3);
			vec3 incandescent_core = (star_color * 1.5 + vec3(0.20)) * (core_peak * 0.50);
			
			vec3 mid_stars = (colored_body + incandescent_core) * mid_stars_intensity * star_mag;
			
			// Fusión volumétrica idéntica con el gas cósmico profundo
			float local_gas_density = clamp(intensity_a + intensity_b, 0.0, 1.0);
			vec3 local_gas_color = mix(col_gas_a, col_gas_b, blend);
			vec3 mid_gas_illumination = star_color * local_gas_color * (mid_star_max * 1.8) * local_gas_density * mid_stars_gas_interaction * twinkle_factor;
			
			combined_color += mid_stars + mid_gas_illumination;
		}
	}

	// Translucidez volumétrica: deja respirar las estrellas 8K en layer -105 a través del vacío abisal
	float nebula_alpha = clamp(combined_alpha * 1.08 + galactic_mask * 0.16, 0.0, 0.90);
	COLOR = vec4(combined_color, nebula_alpha);
}
