shader_type canvas_item;

// Shader de telegrafiado visual para Jefes de Dominio (Astra Dream / Picayune Dreams style)
// Proporciona:
// 1. Aberración cromática (separación de canales RGB en bordes)
// 2. Flash de carga / sobreexposición (charge flash) antes del impacto
// 3. Jitter / distorsión sutil de escaneo glitch
// 4. Modulación de color de dominio (tinte psicodélico/eldritch)

uniform float chromatic_aberration : hint_range(0.0, 0.1) = 0.0;
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float glitch_jitter : hint_range(0.0, 0.05) = 0.0;
uniform vec4 domain_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float emission_boost : hint_range(1.0, 4.0) = 1.0;

void fragment() {
	vec2 uv = UV;

	// Jitter horizontal aleatorio en líneas de escaneo
	if (glitch_jitter > 0.0) {
		float scanline = sin(uv.y * 120.0 + TIME * 30.0);
		if (scanline > 0.7) {
			uv.x += (sin(TIME * 60.0) * glitch_jitter);
		}
	}

	// Muestreo con separación cromática RGB
	float r = texture(TEXTURE, uv + vec2(chromatic_aberration, 0.0)).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, uv - vec2(chromatic_aberration, 0.0)).b;
	float a = texture(TEXTURE, uv).a;

	vec4 tex_color = vec4(r, g, b, a);

	// Aplicación del tinte de dominio psicológico
	vec3 tinted = mix(tex_color.rgb, tex_color.rgb * domain_tint.rgb, domain_tint.a);

	// Flash de advertencia incandescente previo al disparo
	vec3 flashed = mix(tinted, vec3(1.0, 1.0, 1.0), flash_intensity);

	// Multiplicador de brillo para compatibilidad con WorldEnvironment / Bloom
	COLOR = vec4(flashed * emission_boost, a * domain_tint.a);
}
