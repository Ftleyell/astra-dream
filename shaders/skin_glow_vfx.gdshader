shader_type canvas_item;
render_mode blend_mix;

// =========================================================================
// SHADER DE COSMÉTICOS Y SKINS — ASTRA DREAM
// Decora ALREDEDOR de la silueta en el exterior transparente y proyecta
// micro-chispas (sparks) sutiles sin tapar ni oscurecer la ilustración PNG.
// =========================================================================

uniform int star_level : hint_range(1, 3) = 1;
uniform vec4 glow_color : source_color = vec4(0.0, 0.94, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.0, 0.5, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.6;
uniform float pulse_speed : hint_range(0.1, 10.0) = 3.0;

// Ruido pseudo-aleatorio para micro-chispas (sparks)
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Macro segura para muestrear canal alfa con control de límites
#define SAMPLE_ALPHA(c) (((c).x < 0.0 || (c).x > 1.0 || (c).y < 0.0 || (c).y > 1.0) ? 0.0 : texture(TEXTURE, (c)).a)

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float alpha = tex_color.a;

	if (star_level <= 1) {
		// 1★: Textura pura nítida
		COLOR = tex_color;
	} else {
		// Detección morfológica perimetral en 8 direcciones
		vec2 texel = TEXTURE_PIXEL_SIZE;
		float radius = 3.2;
	float accum = 0.0;
	accum += SAMPLE_ALPHA(UV + vec2( radius, 0.0) * texel);
	accum += SAMPLE_ALPHA(UV + vec2(-radius, 0.0) * texel);
	accum += SAMPLE_ALPHA(UV + vec2(0.0,  radius) * texel);
	accum += SAMPLE_ALPHA(UV + vec2(0.0, -radius) * texel);
	accum += SAMPLE_ALPHA(UV + vec2( radius * 0.707,  radius * 0.707) * texel);
	accum += SAMPLE_ALPHA(UV + vec2(-radius * 0.707,  radius * 0.707) * texel);
	accum += SAMPLE_ALPHA(UV + vec2( radius * 0.707, -radius * 0.707) * texel);
	accum += SAMPLE_ALPHA(UV + vec2(-radius * 0.707, -radius * 0.707) * texel);
	accum /= 8.0;

	// Máscara exterior estricta: sólo decora alrededor de la silueta en zona transparente
	float outer_glow_mask = smoothstep(0.02, 0.85, accum) * (1.0 - alpha);
	float pulse = 0.78 + 0.22 * sin(TIME * pulse_speed);

	if (star_level == 2) {
		// 2★: Halo perimetral exterior suave pulsante
		vec4 aura = glow_color * (outer_glow_mask * pulse * glow_intensity);
		aura.a = outer_glow_mask * pulse * 0.85;

		// Borde interno sutil (rim-light) sin alterar el cuerpo ni rostro
		vec3 rgb = tex_color.rgb;
		if (alpha > 0.01) {
			float inner_rim = accum * (1.0 - smoothstep(0.7, 1.0, accum));
			rgb += glow_color.rgb * (inner_rim * 0.45 * pulse);
		}

		COLOR = mix(aura, vec4(rgb, alpha), alpha);
	} else {
		// 3★: Doble aura exterior cromática + micro-chispas (sparks) flotantes + destello sutil
		float shimmer = 0.5 + 0.5 * sin((UV.x + UV.y) * 6.0 + TIME * 3.5);
		vec3 aura_color = mix(glow_color.rgb, accent_color.rgb, shimmer);

		vec4 aura = vec4(aura_color, 1.0) * (outer_glow_mask * pulse * (glow_intensity * 1.25));
		aura.a = outer_glow_mask * pulse * 0.92;

		vec3 rgb = tex_color.rgb;
		if (alpha > 0.01) {
			// 1. Rim-light interior fino
			float inner_rim = accum * (1.0 - smoothstep(0.7, 1.0, accum));
			rgb += aura_color * (inner_rim * 0.60 * pulse);

			// 2. Micro-chispas (sparks) procedurales que titilan sutilmente sobre la silueta
			vec2 grid_uv = UV * 35.0; // Cuadrícula para partículas
			vec2 grid_id = floor(grid_uv);
			vec2 grid_pos = fract(grid_uv) - vec2(0.5);
			
			float spark_seed = hash21(grid_id);
			float spark_time = TIME * 4.0 + spark_seed * 6.28;
			float spark_blink = max(0.0, sin(spark_time));
			spark_blink = pow(spark_blink, 8.0); // Destello estelar rápido y puntual

			float spark_dist = length(grid_pos);
			float spark_shape = smoothstep(0.22, 0.02, spark_dist);
			float spark_intensity = spark_shape * spark_blink * (spark_seed > 0.65 ? 1.0 : 0.0);

			vec3 spark_color = mix(vec3(1.0), accent_color.rgb, 0.4);
			rgb += spark_color * (spark_intensity * 0.85);

			// 3. Barrido diagonal tenue (gleam) de diamante
			float sweep = sin((UV.x * 2.0 - UV.y) * 4.0 - TIME * 2.0);
			float sweep_line = smoothstep(0.97, 0.995, sweep);
			rgb += vec3(1.0) * (sweep_line * 0.22);
		}

		COLOR = mix(aura, vec4(rgb, alpha), alpha);
	}
}
}
