shader_type canvas_item;
render_mode blend_add, unshaded;

varying vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
}

void fragment() {
	// Coordenadas centradas en el quad: [-1.0, 1.0]
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float dist_sq = dot(p, p);
	
	// Si sale del círculo unitario, descartar
	if (dist_sq > 1.0) {
		discard;
	}
	
	// Identificar tipo de proyectil (red channel de custom data)
	int b_type = int(v_custom.r);
	vec3 base_color = vec3(1.0, 0.22, 0.35); // Tipo 0: Carmesí de choque
	
	if (b_type == 1) {
		base_color = vec3(1.0, 0.8, 0.15); // Tipo 1: Oro solar / Ámbar
	} else if (b_type == 2) {
		base_color = vec3(0.2, 0.85, 1.0); // Tipo 2: Cian eléctrico
	} else if (b_type == 3) {
		base_color = vec3(0.85, 0.3, 1.0); // Tipo 3: Púrpura gravitatorio
	}
	
	// Núcleo blanco brillante en el centro + halo exterior de color
	float dist = sqrt(dist_sq);
	float core = smoothstep(0.45, 0.05, dist);
	float halo = smoothstep(1.0, 0.2, dist);
	
	vec3 final_color = mix(base_color, vec3(1.0), core);
	
	// Salida con emisión luminosa (bloom) y atenuación radial suave
	COLOR = vec4(final_color * 1.8, halo);
}
