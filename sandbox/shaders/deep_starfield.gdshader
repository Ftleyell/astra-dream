shader_type canvas_item;
render_mode blend_add, unshaded;

// deep_starfield.gdshader
// Renderizado óptico de alta luminancia para buffer estelar 8K (máscara RGB sobre fondo negro).
// Muestrea starfield_texture de forma directa 1:1 preservando los puntos redondos naturales.
// Elimina completamente cualquier fondo negro con discard (100% transparente para ver nebulosas y galaxias).
// Asigna colores espectrales ricos y variados (rojos cálidos, amarillos dorados, azules eléctricos)
// con distintas intensidades de brillo basadas en la magnitud nativa de cada estrella.

uniform sampler2D starfield_texture : repeat_enable, filter_linear;
uniform float star_intensity : hint_range(0.1, 5.0) = 1.8;
uniform float threshold_cutoff : hint_range(0.005, 0.20) = 0.02;

// Control de ventana y escala del recorrido (valores mayores = estrellas más pequeñas)
uniform float window_scale : hint_range(0.1, 10.0) = 2.8;
uniform vec2 window_offset = vec2(0.0);

// Centelleo orgánico
uniform float twinkle_amount : hint_range(0.0, 1.0) = 0.20;
uniform float twinkle_speed : hint_range(0.1, 10.0) = 2.0;

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

	// 1. Muestreo directo del píxel de la máscara 8K
	vec3 star_raw = texture(starfield_texture, base_uv).rgb;
	float star_luma = max(star_raw.r, max(star_raw.g, star_raw.b));

	// 2. ELIMINAR TOTALMENTE FONDO NEGRO:
	// Si no hay estrella por encima del umbral, descartar el fragmento de inmediato.
	if (star_luma <= threshold_cutoff) {
		discard;
	}

	// 3. Suavizado anti-cuadrados:
	// Caída radial suave para eliminar bordes o mesetas rectangulares
	float smooth_luma = smoothstep(threshold_cutoff, 0.95, star_luma);
	float radial_curve = pow(smooth_luma, 1.2);

	// 4. Asignación espectral viva con gran contraste cromático
	float r_w = pow(star_raw.r, 2.0);
	float g_w = pow(star_raw.g, 2.0);
	float b_w = pow(star_raw.b, 2.0);
	float sum_w = r_w + g_w + b_w;

	vec3 star_tint;
	float star_seed = hash_star(floor(base_uv * BUFFER_SIZE));

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

	// 5. Brillo puro y color vivo (sin formar cuadrados blancos)
	vec3 colored_body = star_tint * radial_curve * 2.8;

	// Núcleo brillante sutil solo en el punto máximo central
	float core_sparkle = pow(smoothstep(0.40, 1.0, star_luma), 4.0) * 0.35;
	vec3 star_disc = colored_body + vec3(core_sparkle);

	// 6. Centelleo cósmico orgánico asíncrono
	float current_time = global_time > 0.001 ? global_time : TIME;
	float twinkle = 1.0 - (twinkle_amount * 0.5) + (twinkle_amount * 0.5) * sin(current_time * twinkle_speed + star_seed * 6.2831);

	// Salida final en modo blend_add
	vec3 final_color = star_disc * twinkle * star_intensity;
	COLOR = vec4(final_color, 1.0);
}
