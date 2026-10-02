shader_type canvas_item;
render_mode blend_add, unshaded;

uniform sampler2D bullet_atlas : hint_default_black, filter_linear_mipmap;

varying vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
}

void fragment() {
	int b_type = int(round(v_custom.r));

	// Coordenadas normalizadas centradas en el quad: [-1.0, 1.0]
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float dist = length(p);

	// Descartar píxeles fuera de la esfera perfecta
	if (dist > 1.0) {
		discard;
	}

	// Paleta de Peligro Danmaku (Orbes esféricos puros de alta legibilidad)
	vec3 base_color = vec3(1.0, 0.08, 0.15); // Tipo 0: Carmesí Sangre
	if (b_type == 1) {
		base_color = vec3(1.0, 0.44, 0.02); // Tipo 1: Plasma Naranja Fuego
	} else if (b_type == 2) {
		base_color = vec3(1.0, 0.06, 0.68); // Tipo 2: Fucsia Neón Letal
	} else if (b_type == 3) {
		base_color = vec3(0.65, 0.12, 1.0);  // Tipo 3: Vacío Abisal Púrpura
	} else if (b_type == 4) {
		base_color = vec3(1.0, 0.82, 0.12); // Tipo 4: Ámbar Solar
	} else if (b_type == 5) {
		base_color = vec3(0.08, 0.78, 1.0);  // Tipo 5: Cobalto Cuántico
	} else if (b_type >= 6) {
		base_color = vec3(0.88, 0.22, 1.0); // Tipo 6+: Amatista Espectral
	}

	// 1. Núcleo incandescente ultra-blanco/caliente en el centro geométrico (dist < 0.38)
	float core = smoothstep(0.38, 0.0, dist);

	// 2. Anillo de densidad energética y halo de contraste exterior
	float ring = smoothstep(0.92, 0.65, dist) * smoothstep(0.40, 0.60, dist);
	float edge = smoothstep(1.0, 0.88, dist);

	vec3 final_color = mix(base_color, vec3(1.0, 1.0, 1.0), core * 0.95);
	final_color += base_color * ring * 0.65;

	// Salida con emisión luminosa y recorte circular perfecto
	COLOR = vec4(final_color * 1.85, edge);
}
