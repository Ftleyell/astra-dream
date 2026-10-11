shader_type canvas_item;
render_mode blend_add, unshaded;

// deep_starfield.gdshader
// Renderizado óptico de alta luminancia para buffer estelar 8K (máscara RGB sobre fondo negro).
// Muestrea starfield_texture de forma directa 1:1 preservando los puntos redondos naturales.
// Elimina completamente cualquier fondo negro con discard (100% transparente para ver nebulosas y galaxias).
// Asigna colores espectrales ricos y variados (rojos cálidos, amarillos dorados, azules eléctricos)
// con distintas intensidades de brillo basadas en la magnitud nativa de cada estrella.

uniform sampler2D starfield_texture : repeat_enable, filter_linear;
uniform float star_intensity : hint_range(0.1, 10.0) = 4.0;
uniform float threshold_cutoff : hint_range(0.005, 0.20) = 0.02;

// Control de ventana y escala del recorrido (valores menores = estrellas más grandes)
uniform float window_scale : hint_range(0.1, 10.0) = 1.35;
uniform vec2 window_offset = vec2(0.0);

// Centelleo orgánico
uniform float twinkle_amount : hint_range(0.0, 1.0) = 0.35;
uniform float twinkle_speed : hint_range(0.1, 10.0) = 2.2;

// Lens flare anamórfico Sci-Fi y destellos en cruz
uniform float lens_flare_intensity : hint_range(0.0, 5.0) = 2.5;
uniform float lens_flare_length : hint_range(0.1, 5.0) = 2.0;

// Paleta espectral viva por tipo de estrella (colores ricos, cero tonos deslavados)
uniform vec4 tint_red_star : source_color = vec4(1.80, 0.40, 0.20, 1.0);     // Enana roja / rubí cálido
uniform vec4 tint_yellow_star : source_color = vec4(1.70, 1.40, 0.35, 1.0);  // Amarilla dorada solar
uniform vec4 tint_blue_star : source_color = vec4(0.50, 1.10, 2.10, 1.0);    // Gigante azul eléctrico / zafiro

uniform float global_time = 0.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash_star(vec2 p) {
	vec2 i = floor(p);
	return fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	const float BUFFER_SIZE = 8192.0;
	vec2 base_uv = (world_pos * window_scale + window_offset) / BUFFER_SIZE;

	// Muestreo continuo bilineal directo en nivel MIP 0 (sin saltos erráticos de derivadas dFdx/dFdy)
	vec3 star_raw = textureLod(starfield_texture, base_uv, 0.0).rgb;
	float star_luma = max(star_raw.r, max(star_raw.g, star_raw.b));

	if (star_luma < threshold_cutoff) {
		discard;
	}

	// Curva analítica continua de contraste y expansión esférica pura
	float normalized_luma = smoothstep(threshold_cutoff, 0.85, star_luma);
	float radial_curve = pow(normalized_luma, 1.25);

	// Asignación espectral continua con gran contraste cromático
	float r_w = pow(star_raw.r, 2.0);
	float g_w = pow(star_raw.g, 2.0);
	float b_w = pow(star_raw.b, 2.0);
	float sum_w = r_w + g_w + b_w;

	vec3 star_tint;
	// Semilla pseudoaleatoria basada en bloques UV continuos para coherencia cromática y centelleo
	vec2 color_block_id = floor(base_uv * 1024.0);
	float star_seed = hash_star(color_block_id);

	if (sum_w > 0.0001) {
		star_tint = (r_w * tint_red_star.rgb + g_w * tint_yellow_star.rgb + b_w * tint_blue_star.rgb) / sum_w;
	} else {
		if (star_seed < 0.33) {
			star_tint = tint_red_star.rgb;
		} else if (star_seed < 0.66) {
			star_tint = tint_yellow_star.rgb;
		} else {
			star_tint = tint_blue_star.rgb;
		}
	}

	// Centelleo orgánico continuo
	float current_time = global_time > 0.001 ? global_time : TIME;
	float time_seed = current_time * twinkle_speed + star_seed * 6.2831853;
	float wave_a = sin(time_seed);
	float wave_b = sin(time_seed * 2.73 + star_seed * 3.14);
	float composite_twinkle = wave_a * 0.65 + wave_b * 0.35;
	
	float spike_climax = pow(max(0.0, composite_twinkle), 4.5);
	float twinkle = 0.70 + 0.30 * composite_twinkle + (spike_climax * twinkle_amount * 2.0);

	// Cuerpo estelar esférico puro y halo incandescente expandido
	vec3 colored_body = star_tint * radial_curve * 2.8;
	float core_intensity = pow(normalized_luma, 2.8);
	vec3 core_glow = (star_tint * 1.6 + vec3(0.80)) * (core_intensity * 0.75);

	// Destello de difracción simétrico de 4 puntas en astros brillantes durante picos de centelleo
	float center_peak = smoothstep(0.40, 0.95, star_luma);
	float cross_sparkle = pow(center_peak, 2.2) * (0.35 + spike_climax * 1.6) * lens_flare_intensity;
	vec3 cross_glint = (star_tint * 1.4 + vec3(0.60)) * (cross_sparkle * 0.40);

	vec3 star_disc = colored_body + core_glow + cross_glint;

	// Salida final en modo blend_add
	vec3 final_color = star_disc * twinkle * star_intensity;
	COLOR = vec4(final_color, 1.0);
}
