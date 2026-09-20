shader_type canvas_item;
render_mode blend_add, unshaded;

varying vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
}

void fragment() {
	// Coordenadas centradas en el quad: [-1.0, 1.0]
	// p.x está alineado con la dirección del vector velocidad
	vec2 p = (UV - vec2(0.5)) * 2.0;

	// Silueta de dardo / aguja de energía hostil (teardrop direccional):
	// Afilado hacia el frente (+X) y estela de eyección estilizada en (-X)
	float shape_dist;
	if (p.x > 0.0) {
		// Punta afilada hacia delante
		shape_dist = p.x * 0.85 + abs(p.y) * 1.75;
	} else {
		// Cuerpo y estela trasera
		shape_dist = abs(p.x) * 0.75 + abs(p.y) * 1.35;
	}

	if (shape_dist > 1.0) {
		discard;
	}

	// Paleta de Peligro Hostil (Cero confusión con gemas/EXP)
	int b_type = int(v_custom.r);
	vec3 base_color = vec3(1.0, 0.08, 0.15); // Tipo 0: Carmesí Sangre de Impacto

	if (b_type == 1) {
		base_color = vec3(1.0, 0.38, 0.02); // Tipo 1: Plasma Naranja Fuego
	} else if (b_type == 2) {
		base_color = vec3(1.0, 0.05, 0.60); // Tipo 2: Fucsia Neón Letal
	} else if (b_type == 3) {
		base_color = vec3(0.65, 0.08, 1.0); // Tipo 3: Vacío Abisal Púrpura
	}

	// Núcleo blanco incandescente en el centro de masa del proyectil
	vec2 core_pos = p - vec2(0.15, 0.0);
	float core_dist = length(core_pos * vec2(1.4, 2.4));
	float core = smoothstep(0.42, 0.04, core_dist);

	// Borde de emisión de energía
	float edge = smoothstep(1.0, 0.35, shape_dist);

	vec3 final_color = mix(base_color, vec3(1.0, 0.98, 0.92), core);

	// Salida con emisión luminosa (bloom) intensa
	COLOR = vec4(final_color * 2.1, edge);
}
