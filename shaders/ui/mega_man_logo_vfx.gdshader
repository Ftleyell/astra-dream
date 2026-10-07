shader_type canvas_item;
render_mode blend_mix;

// Controles de Flash (Fase 1)
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Controles de Glitch y Aberración Cromática (Fase 2)
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float glitch_frequency = 24.0;
uniform float chromatic_separation = 0.035;

// Controles de Barrido de Luz Espectral (Fase 3)
uniform bool shine_active = false;
uniform vec4 shine_color : source_color = vec4(2.0, 2.0, 2.5, 1.0); // HDR Glow
uniform float shine_speed = 0.8;
uniform float shine_width = 0.15;
uniform float shine_angle = 45.0;
uniform float shine_pause = 3.5;

float random_noise(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// 1. Desplazamiento por Franjas Horizontales (Glitch)
	if (glitch_intensity > 0.0) {
		float band = floor(uv.y * glitch_frequency);
		float noise = random_noise(vec2(band, floor(TIME * 25.0)));
		if (noise < glitch_intensity * 0.7) {
			float shift = (random_noise(vec2(noise, band)) - 0.5) * glitch_intensity * 0.12;
			uv.x = clamp(uv.x + shift, 0.0, 1.0);
		}
	}

	// 2. Muestreo con Aberración Cromática Local
	float chrom_offset = chromatic_separation * glitch_intensity;
	vec4 tex_r = texture(TEXTURE, vec2(uv.x + chrom_offset, uv.y));
	vec4 tex_g = texture(TEXTURE, uv);
	vec4 tex_b = texture(TEXTURE, vec2(uv.x - chrom_offset, uv.y));

	vec4 base_color;
	base_color.r = tex_r.r;
	base_color.g = tex_g.g;
	base_color.b = tex_b.b;
	base_color.a = (tex_r.a + tex_g.a + tex_b.a) / 3.0;

	if (base_color.a <= 0.001) {
		discard;
	}

	// 3. Aplicación del Flash de Impacto
	vec3 mixed_color = mix(base_color.rgb, flash_color.rgb, flash_amount);

	// 4. Barrido de Luz Espectral (Shine)
	if (shine_active) {
		float rad = radians(shine_angle);
		vec2 dir = vec2(cos(rad), sin(rad));
		float proj = dot(uv, dir);

		float cycle_duration = 1.0 + shine_pause;
		float progress = mod(TIME * shine_speed, cycle_duration);
		float beam_pos = progress - 0.5;

		float d = abs(proj - beam_pos);
		float shine_mask = smoothstep(shine_width, 0.0, d);

		// Mezcla aditiva ponderada por el canal alfa original
		mixed_color += shine_color.rgb * shine_mask * base_color.a;
	}

	COLOR = vec4(mixed_color, base_color.a);
}
