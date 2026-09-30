shader_type canvas_item;

// Outline violeta neón de alta visibilidad para siluetas de enemigos en combate espacial (Doble grosor)
uniform vec4 outline_color : source_color = vec4(0.75, 0.15, 1.0, 1.0);
uniform float outline_thickness : hint_range(0.0, 120.0) = 60.0;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.05;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);
	
	// Si el pixel actual pertenece a la nave, renderizarlo preservando modulate (hit-flash, tints)
	if (base_color.a > alpha_threshold) {
		COLOR = base_color * COLOR;
	} else {
		// Si el pixel es transparente, buscar si colinda con la silueta exterior del sprite
		float max_alpha = 0.0;
		vec2 pixel_size = TEXTURE_PIXEL_SIZE;
		
		const int ANGLES = 16;
		for (int i = 0; i < ANGLES; i++) {
			float angle = float(i) * (6.28318530718 / float(ANGLES));
			vec2 dir = vec2(cos(angle), sin(angle));
			
			// Muestreo concéntrico en 4 radios para asegurar trazo continuo con doble grosor (60px)
			float a1 = texture(TEXTURE, UV + dir * pixel_size * outline_thickness).a;
			float a2 = texture(TEXTURE, UV + dir * pixel_size * (outline_thickness * 0.75)).a;
			float a3 = texture(TEXTURE, UV + dir * pixel_size * (outline_thickness * 0.50)).a;
			float a4 = texture(TEXTURE, UV + dir * pixel_size * (outline_thickness * 0.25)).a;
			
			max_alpha = max(max_alpha, max(max(a1, a2), max(a3, a4)));
			if (max_alpha >= 0.9) {
				break;
			}
		}
		
		if (max_alpha > alpha_threshold) {
			// Borde violeta eléctrico nítido con micro anti-aliasing exterior y modulación reactiva
			COLOR = vec4(outline_color.rgb * COLOR.rgb, outline_color.a * COLOR.a * smoothstep(alpha_threshold, 0.35, max_alpha));
		} else {
			COLOR = vec4(0.0);
		}
	}
}
