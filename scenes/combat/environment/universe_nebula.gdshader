shader_type canvas_item;
render_mode unshaded;

// Sincronización de proyección espacial
uniform vec2 camera_world_position = vec2(0.0);
uniform vec2 camera_zoom = vec2(1.0);
uniform vec2 viewport_size = vec2(1920.0, 1080.0);

// Control visual del bioma y gas cósmico
uniform sampler2D noise_texture : repeat_enable, filter_linear, hint_default_black;
uniform vec4 base_space_color : source_color = vec4(0.01, 0.012, 0.025, 1.0);
uniform vec4 nebula_color_primary : source_color = vec4(0.18, 0.05, 0.32, 1.0);
uniform vec4 nebula_color_secondary : source_color = vec4(0.02, 0.22, 0.40, 1.0);
uniform float nebula_density : hint_range(0.0, 3.0) = 0.90;
uniform float nebula_scale : hint_range(0.00001, 0.005) = 0.00035;
uniform float nebula_scroll_scale : hint_range(0.001, 1.0) = 0.04;

// Control analítico de estrellas procedurales
uniform float star_density : hint_range(10.0, 300.0) = 90.0;
uniform float star_brightness_cutoff : hint_range(0.70, 0.999) = 0.965;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.0;

// Parámetros de difracción y polvo cósmico
uniform float star_spike_intensity : hint_range(0.0, 3.0) = 0.95;
uniform float star_spike_angle : hint_range(0.0, 3.14159) = 0.785398; // 45°
uniform float cosmic_dust_intensity : hint_range(0.0, 1.0) = 0.22;
uniform float cosmic_dust_scale : hint_range(0.0005, 0.01) = 0.0022;

// Atlas Estelar Astrofísico 8K (8192 x 8192) continuo
uniform sampler2D deep_starfield_texture : repeat_enable, filter_linear, hint_default_black;
uniform float deep_starfield_intensity : hint_range(0.0, 3.0) = 1.1;
uniform float deep_starfield_scroll_scale : hint_range(0.001, 0.1) = 0.015;

// Proyección espacial de biomas y niebla de frontera en coordenadas de mundo
const int MAX_SECTORS = 4;
uniform int sector_count = 0;
uniform vec2 sector_centers[4];
uniform float sector_radii[4];
uniform float sector_transition_widths[4];
uniform vec4 sector_colors_primary[4];
uniform vec4 sector_colors_secondary[4];
uniform float sector_densities[4];

// Dispersión analítica pseudo-aleatoria robusta (retorna 3 valores independientes)
vec3 hash23(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195));
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}

// Clasificación espectral estelar de Harvard (O, B, A, F, G, K, M)
vec3 get_spectral_color(float seed) {
	if (seed < 0.28) {
		// Enanas rojas / anaranjadas (Clases M y K)
		return mix(vec3(1.0, 0.42, 0.24), vec3(1.0, 0.66, 0.38), seed / 0.28);
	} else if (seed < 0.62) {
		// Estrellas solares / amarillas y blanco cálido (Clases G y F)
		return mix(vec3(1.0, 0.82, 0.52), vec3(1.0, 0.96, 0.88), (seed - 0.28) / 0.34);
	} else if (seed < 0.84) {
		// Estrellas blancas puras / diamante (Clase A)
		return mix(vec3(0.96, 0.98, 1.0), vec3(0.88, 0.94, 1.0), (seed - 0.62) / 0.22);
	} else {
		// Gigantes / enanas azules hipercalientes (Clases B y O)
		return mix(vec3(0.65, 0.82, 1.0), vec3(0.42, 0.68, 1.0), (seed - 0.84) / 0.16);
	}
}

// Rotación 2D para romper cualquier alineación ortogonal
vec2 rotate_2d(vec2 v, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Domain warp suave para eliminar cualquier alineación de cuadrícula
vec2 warp_domain(vec2 p, float strength) {
	return p + vec2(
		sin(p.y * 0.007 + 1.7) * cos(p.x * 0.005 + 0.4),
		cos(p.x * 0.007 + 2.3) * sin(p.y * 0.005 + 1.1)
	) * strength;
}

const float GOLDEN_ANGLE = 2.39996323; // 137.507764 grados en radianes

// Muestreador unificado y orgánico con Ley de Potencias Astronómica
vec3 sample_star_layer(
	vec2 pos_px,
	float cell_size,
	float occupancy,
	float min_radius,
	float max_radius,
	float min_lum,
	float max_lum,
	float halo_strength,
	bool enable_spikes,
	float spike_mult,
	float cluster_bias,
	float layer_id
) {
	// 1. Deformación no lineal de coordenadas para erradicar cualquier cuadrícula
	vec2 warped_pos = warp_domain(pos_px, cell_size * 0.45);
	vec2 base_cell = floor(warped_pos / cell_size);
	vec2 local_pos = warped_pos - base_cell * cell_size;
	vec3 acc_color = vec3(0.0);

	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 cell_offset = vec2(float(dx), float(dy));
			vec2 cell_id = base_cell + cell_offset;

			// Generar 3 variables pseudo-aleatorias independientes por celda
			vec3 rnd = hash23(cell_id + vec2(layer_id * 149.23, layer_id * 313.79));

			// Modulación por cúmulos naturales (la nebulosa favorece la presencia estelar)
			float eff_thresh = clamp(1.0 - occupancy * (1.0 + cluster_bias * 0.45), 0.50, 0.985);

			if (rnd.x > eff_thresh) {
				// Jitter continuo y asimétrico dentro de la celda
				vec2 jitter = (rnd.yz - vec2(0.5)) * (cell_size * 0.78);
				vec2 star_pos = cell_offset * cell_size + vec2(cell_size * 0.5) + jitter;
				vec2 delta = local_pos - star_pos;
				float dist = length(delta);

				float max_r = cell_size * 0.95;
				if (dist > max_r) {
					continue;
				}

				// LEY DE POTENCIAS ASTRONÓMICA: Diversidad extrema de brillo y tamaño
				// La gran mayoría son micro-estrellas tenues; solo una pequeña fracción brilla con fuerza
				float raw_mag = pow(rnd.y, 3.8);

				// Radio: desde min_radius hasta max_radius
				float r_core = mix(min_radius, max_radius, pow(raw_mag, 1.4));
				float r_glow = r_core * (2.2 + raw_mag * 3.5);

				// Perfil gaussiano de doble dispersión (núcleo fino + halo atmosférico suave)
				float core = exp(-0.5 * (dist * dist) / max(r_core * r_core, 0.05));
				float glow = exp(-0.5 * (dist * dist) / max(r_glow * r_glow, 0.10));
				float star_shape = core * 0.72 + glow * (0.28 + halo_strength * raw_mag * 0.85);

				// Picos de difracción de 4 puntas: únicamente en las estrellas raras más luminosas
				float spikes = 0.0;
				if (enable_spikes && raw_mag > 0.45) {
					vec2 p_spike = rotate_2d(delta, star_spike_angle);
					vec2 abs_spike = abs(p_spike);

					float spike_x = exp(-abs_spike.y * 1.5) * exp(-abs_spike.x * 0.040);
					float spike_y = exp(-abs_spike.x * 1.5) * exp(-abs_spike.y * 0.040);
					float spike_shape = max(spike_x, spike_y);

					float spike_int = smoothstep(0.45, 1.0, raw_mag);
					spikes = spike_shape * spike_int * spike_mult * 0.45;
				}

				// Centelleo espectral orgánico (twinkle desfasado)
				float t_speed1 = 0.75 + rnd.x * 1.5;
				float t_speed2 = 1.35 + rnd.z * 2.1;
				float twinkle_wave = sin(TIME * t_speed1 + rnd.z * 61.3) * 0.65 + sin(TIME * t_speed2 + rnd.x * 37.7) * 0.35;
				float twinkle = 1.0 + twinkle_wave * (0.10 + raw_mag * 0.20);

				// Luminosidad dinámica con amplio rango (desde estrellas casi invisibles hasta gemas)
				float luminosity = mix(min_lum, max_lum, raw_mag) * twinkle;
				float intensity = (star_shape + spikes) * luminosity;

				// Clasificación espectral basada en rnd.z
				vec3 spectral_tint = get_spectral_color(rnd.z);
				vec3 final_color = mix(spectral_tint, vec3(0.97, 0.98, 1.0), clamp(core * 0.80, 0.0, 1.0));

				acc_color += final_color * intensity;
			}
		}
	}
	return acc_color;
}

void fragment() {
	float zoom_factor = max(camera_zoom.x, 0.001);
	vec2 screen_pixel = (SCREEN_UV - vec2(0.5)) * (viewport_size / zoom_factor);
	
	// Coordenadas reales de mundo del píxel para proyección de horizonte de bioma
	vec2 world_pos = camera_world_position + screen_pixel;

	// Coordenadas del fondo de gas y polvo cósmico con desplazamiento suave sincronizado
	vec2 uv_gas_world = screen_pixel + camera_world_position * nebula_scroll_scale;

	// Proyección espacial de biomas y niebla de frontera
	vec3 cur_neb_primary = nebula_color_primary.rgb;
	vec3 cur_neb_secondary = nebula_color_secondary.rgb;
	float cur_neb_density = nebula_density;

	if (sector_count > 0) {
		float total_w = 0.0;
		vec3 acc_prim = vec3(0.0);
		vec3 acc_sec = vec3(0.0);
		float acc_dens = 0.0;

		for (int i = 0; i < MAX_SECTORS; i++) {
			if (i >= sector_count) {
				break;
			}
			float dist = distance(world_pos, sector_centers[i]);
			if (dist < sector_radii[i]) {
				float inner_b = sector_radii[i] - sector_transition_widths[i];
				float w = 1.0;
				if (dist > inner_b) {
					float factor = clamp((sector_radii[i] - dist) / max(sector_transition_widths[i], 1.0), 0.0, 1.0);
					// Curva quíntica C2 de Perlin: 6t^5 - 15t^4 + 10t^3
					w = factor * factor * factor * (factor * (factor * 6.0 - 15.0) + 10.0);
				}
				total_w += w;
				acc_prim += sector_colors_primary[i].rgb * w;
				acc_sec += sector_colors_secondary[i].rgb * w;
				acc_dens += sector_densities[i] * w;
			}
		}

		if (total_w < 1.0) {
			float fill = 1.0 - total_w;
			acc_prim += nebula_color_primary.rgb * fill;
			acc_sec += nebula_color_secondary.rgb * fill;
			acc_dens += nebula_density * fill;
		} else {
			acc_prim /= total_w;
			acc_sec /= total_w;
			acc_dens /= total_w;
		}

		cur_neb_primary = acc_prim;
		cur_neb_secondary = acc_sec;
		cur_neb_density = acc_dens;
	}

	// 1. Color base de radiación de fondo
	vec3 out_color = base_space_color.rgb;

	// 2. Composición de nebulosa con respiración viva y deriva suave
	float neb_pulse = 1.0 + sin(TIME * 0.14) * 0.08 + cos(TIME * 0.09 + 1.2) * 0.05;
	vec2 uv_gas_layer_a = (uv_gas_world + vec2(sin(TIME * 0.04) * 35.0, cos(TIME * 0.03) * 25.0)) * nebula_scale * 0.5;
	vec2 uv_gas_layer_b = (uv_gas_world + vec2(2341.0 + cos(TIME * 0.05) * 30.0, -1193.0)) * (nebula_scale * 1.25);

	float gas_a = texture(noise_texture, uv_gas_layer_a).r;
	float gas_b = texture(noise_texture, uv_gas_layer_b + vec2(chromatic_aberration, 0.0)).g;

	float composite_gas = smoothstep(0.20, 0.88, (gas_a * 0.65 + gas_b * 0.55) * (cur_neb_density * neb_pulse));
	vec3 gas_palette = mix(cur_neb_primary, cur_neb_secondary, gas_b);
	out_color += gas_palette * composite_gas;

	// 3. Polvo estelar micro-volumétrico filtrado
	vec2 dust_uv1 = uv_gas_world * cosmic_dust_scale;
	vec2 dust_uv2 = (uv_gas_world + vec2(2731.0, -1894.0)) * (cosmic_dust_scale * 1.7);
	float dust_sample_a = texture(noise_texture, dust_uv1).r;
	float dust_sample_b = texture(noise_texture, dust_uv2).r;

	float micro_dust = pow(dust_sample_a * dust_sample_b, 1.7) * 2.5;
	vec3 dust_color = mix(cur_neb_primary, cur_neb_secondary, dust_sample_b);
	dust_color = mix(base_space_color.rgb * 2.2, dust_color, 0.40);
	out_color += dust_color * (micro_dust * cosmic_dust_intensity);

	// Modulación de cúmulos estelares basada en el gas interestelar
	float cluster_bias = (gas_a - 0.45) * 1.2;

	// Densidad global rebalanceada (limpia y despejada para alta legibilidad)
	float density_factor = clamp(star_density / 90.0, 0.3, 3.0);
	float sqrt_dens = sqrt(density_factor);

	// 4. Atlas Estelar Profundo 8K Astrofísico (27,780 estrellas continuas, sin cuadrícula, Poisson sub-píxel)
	vec2 starfield_world_pos = screen_pixel + camera_world_position * deep_starfield_scroll_scale;
	vec2 starfield_uv = starfield_world_pos / 8192.0;
	vec3 star_sample = texture(deep_starfield_texture, starfield_uv).rgb;

	if (star_sample.r + star_sample.g > 0.003) {
		// Reconstrucción del color espectral estelar (Harvard OBAFGKM) mediante canal B empacado
		vec3 star_spectral_tint = get_spectral_color(star_sample.b);

		// Centelleo orgánico dinámico en GPU desfasado por posición única
		float star_twinkle = 1.0 + 0.14 * sin(TIME * (1.1 + star_sample.b * 1.6) + starfield_uv.x * 4119.0 + starfield_uv.y * 2917.0);

		// Núcleo blanco brillante con halo cromático
		vec3 core_rgb = mix(star_spectral_tint, vec3(0.97, 0.98, 1.0), clamp(star_sample.r * 1.5, 0.0, 1.0));
		vec3 star_rgb = (core_rgb * star_sample.r + star_spectral_tint * star_sample.g * 0.75) * (star_twinkle * deep_starfield_intensity);
		out_color += star_rgb;
	}

	// 5. Gemas Focales Cercanas con Picos de Difracción (scroll 0.20 - muy escasas, movimiento cinemático)
	float cell_focal = 311.0 / sqrt_dens;
	vec2 pos_focal = rotate_2d(screen_pixel + camera_world_position * 0.200, 2.0 * GOLDEN_ANGLE) + vec2(2833.0, -1367.0);
	out_color += sample_star_layer(pos_focal, cell_focal, 0.12, 0.85, 2.10, 0.40, 1.65, 0.45, true, star_spike_intensity, cluster_bias, 2.0);

	COLOR = vec4(out_color, 1.0);
}

