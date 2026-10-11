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
uniform float deep_stars_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float deep_stars_parallax : hint_range(0.0, 0.05) = 0.006;
uniform float deep_stars_scale : hint_range(0.1, 10.0) = 2.8;

// Textura de nebulosa seamless en tiles (2048x2048) modulada con FBM
uniform sampler2D nebula_tile_texture : repeat_enable, filter_linear;
uniform float nebula_tile_scale : hint_range(0.00005, 0.005) = 0.00035;
uniform float nebula_tile_mix : hint_range(0.0, 1.0) = 0.45;

// Configuración Bioma A
uniform vec4 biome_a_color_deep : source_color = vec4(0.01, 0.01, 0.03, 1.0);
uniform vec4 biome_a_color_gas_primary : source_color = vec4(0.18, 0.04, 0.28, 0.8);
uniform vec4 biome_a_color_gas_secondary : source_color = vec4(0.02, 0.22, 0.38, 0.6);
uniform vec4 biome_a_star_tint : source_color = vec4(0.90, 0.94, 1.0, 1.0);
uniform float biome_a_density : hint_range(0.1, 3.0) = 2.00;
uniform float biome_a_contrast : hint_range(0.5, 4.0) = 1.8;
uniform float biome_a_frequency : hint_range(0.00001, 0.005) = 0.00045;

// Configuración Bioma B
uniform vec4 biome_b_color_deep : source_color = vec4(0.02, 0.01, 0.01, 1.0);
uniform vec4 biome_b_color_gas_primary : source_color = vec4(0.35, 0.12, 0.03, 0.85);
uniform vec4 biome_b_color_gas_secondary : source_color = vec4(0.40, 0.28, 0.05, 0.65);
uniform vec4 biome_b_star_tint : source_color = vec4(0.90, 0.94, 1.0, 1.0);
uniform float biome_b_density : hint_range(0.1, 3.0) = 2.00;
uniform float biome_b_contrast : hint_range(0.5, 4.0) = 1.8;
uniform float biome_b_frequency : hint_range(0.00001, 0.005) = 0.00055;

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

	// Modulación con textura seamless en tiles (2048x2048) si nebula_tile_mix > 0.0
	if (nebula_tile_mix > 0.001) {
		vec2 tile_uv = sample_p * nebula_tile_scale;
		vec3 tile_tex_rgb = texture(nebula_tile_texture, tile_uv).rgb;
		float tile_density = dot(tile_tex_rgb, vec3(0.299, 0.587, 0.114));
		float modulated_density = tile_density * 1.8;
		gas_a = mix(gas_a, gas_a * modulated_density, nebula_tile_mix);
		gas_b = mix(gas_b, gas_b * modulated_density, nebula_tile_mix);
	}

	// Curvas y contraste de gas según bioma
	float intensity_a = pow(smoothstep(0.25, 0.85, gas_a * biome_a_density), biome_a_contrast * 0.5);
	float intensity_b = pow(smoothstep(0.25, 0.85, gas_b * biome_b_density), biome_b_contrast * 0.5);

	// Gradación de color para Bioma A
	vec3 col_gas_a = mix(biome_a_color_gas_primary.rgb, biome_a_color_gas_secondary.rgb, gas_a_b);
	vec3 final_a = mix(biome_a_color_deep.rgb, col_gas_a, intensity_a);

	// Gradación de color para Bioma B
	vec3 col_gas_b = mix(biome_b_color_gas_primary.rgb, biome_b_color_gas_secondary.rgb, gas_b_b);
	vec3 final_b = mix(biome_b_color_deep.rgb, col_gas_b, intensity_b);

	// Transición suave entre biomas según biome_blend_factor (smoothstep)
	float blend = smoothstep(0.0, 1.0, biome_blend_factor);
	vec3 combined_color = mix(final_a, final_b, blend);
	float combined_alpha = mix(
		clamp(intensity_a * max(biome_a_color_gas_primary.a, biome_a_color_gas_secondary.a), 0.0, 1.0),
		clamp(intensity_b * max(biome_b_color_gas_primary.a, biome_b_color_gas_secondary.a), 0.0, 1.0),
		blend
	);

	// Iluminación y teñido cromático del gas nebular por soles activos cercanos
	for (int i = 0; i < MAX_STAR_LIGHTS; i++) {
		if (i >= star_light_count) {
			break;
		}
		vec2 s_pos = star_light_positions[i];
		vec4 s_col = star_light_colors[i];
		float s_rad = max(star_light_radii[i], 1.0);
		float s_dist = length(screen_coord - s_pos);
		if (s_dist < s_rad) {
			float norm_dist = s_dist / s_rad;
			// Atenuación suave cúbica-cuadrática
			float star_inf = pow(1.0 - norm_dist, 1.3);
			float edge_feather = smoothstep(1.0, 0.75, norm_dist);
			float light_factor = star_inf * edge_feather * s_col.a;
			// 1. Teñir el gas existente con el espectro estelar del sol con mayor saturación y contraste
			combined_color = mix(combined_color, combined_color * s_col.rgb * 2.6, light_factor * 0.85);
			// 2. Dispersión lumínica etérea (ambient scattering) sobre el polvo nebular
			combined_color += s_col.rgb * light_factor * 1.15 * (intensity_a + intensity_b + 0.40);
			// 3. Aumentar densidad lumínica
			combined_alpha = max(combined_alpha, combined_alpha + light_factor * 0.50);
		}
	}

	// Muestreo del lecho de micro-estrellas de fondo casi inmóvil (Ventana amplia para puntos diminutos de 1-2px)
	const float BUFFER_SIZE = 8192.0;
	vec2 deep_star_world_pos = camera_world_position * deep_stars_parallax + (screen_coord - viewport_resolution * 0.5);
	vec2 deep_star_uv = (deep_star_world_pos * deep_stars_scale) / BUFFER_SIZE;
	vec3 deep_star_raw = texture(deep_starfield_texture, deep_star_uv).rgb;
	
	// Detección de la máscara estelar RGB pura sobre fondo negro
	float deep_star_max = max(deep_star_raw.r, max(deep_star_raw.g, deep_star_raw.b));
	
	if (deep_star_max > 0.015) {
		// Asignación espectral saturada por canal dominante (R: cálido/rojo, G: dorado/amarillo, B: azul eléctrico)
		vec3 col_r = vec3(1.70, 0.40, 0.25); // Enana roja / rubí cálido
		vec3 col_g = vec3(1.60, 1.35, 0.40); // Amarilla media / dorada
		vec3 col_b = vec3(0.55, 1.05, 1.95); // Azul fría / gigante eléctrica
		
		float sum_rgb = deep_star_raw.r + deep_star_raw.g + deep_star_raw.b + 0.0001;
		vec3 star_color = (deep_star_raw.r * col_r + deep_star_raw.g * col_g + deep_star_raw.b * col_b) / sum_rgb;
		
		// Matizar con el tinte estelar armónico de los biomas activos
		vec3 biome_star_tint = mix(biome_a_star_tint.rgb, biome_b_star_tint.rgb, blend);
		star_color *= biome_star_tint;

		// Variedad de magnitudes (distintas intensidades de brillo conservando la redondez natural)
		float radial_falloff = pow(deep_star_max, 0.85);
		vec3 colored_body = star_color * radial_falloff * 2.2;
		
		// Núcleo blanco incandescente sutil SOLO en las estrellas más brillantes (evita el lavado a blanco puro)
		vec3 subtle_white = vec3(1.0) * pow(smoothstep(0.05, 0.75, deep_star_max), 2.5) * 0.5;
		vec3 deep_stars = (colored_body + subtle_white) * deep_stars_intensity;
		
		// Sumar aditivamente al lecho cósmico sin alterar la niebla circundante
		combined_color += deep_stars;
	}

	COLOR = vec4(combined_color, max(combined_alpha, 0.95));
}
