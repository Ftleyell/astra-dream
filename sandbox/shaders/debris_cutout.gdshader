shader_type canvas_item;
render_mode blend_mix, unshaded;

// debris_cutout.gdshader
// Shader para fragmentos de restos espaciales instanciados en GPU vía MultiMeshInstance2D.
// Emplea un atlas 2D unificado indexado por INSTANCE_CUSTOM,
// rotación angular y deriva procedural en vertex shader (Zero CPU cost),
// y alpha-cutoff con descarte de fragmentos (discard) para evitar bordes cuadrados.

uniform sampler2D atlas_texture : filter_linear_mipmap;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.08;
uniform float drift_speed : hint_range(0.0, 100.0) = 15.0;
uniform float spin_speed_mult : hint_range(0.0, 5.0) = 0.8;

// INSTANCE_CUSTOM en MultiMeshInstance2D provee un vec4 por instancia:
// INSTANCE_CUSTOM.xy -> UV offset del sub-rect en el atlas
// INSTANCE_CUSTOM.zw -> UV scale (anchura, altura normalizadas) del sub-rect

void vertex() {
	// Variación determinista por instancia basada en su posición o UV offset
	float seed = fract(INSTANCE_CUSTOM.x * 123.45 + INSTANCE_CUSTOM.y * 678.91);
	float spin_rate = (seed - 0.5) * 2.0 * spin_speed_mult;
	float angle = TIME * spin_rate;

	// Rotación 2D sobre el centro del quad local (-0.5 .. 0.5)
	float c = cos(angle);
	float s = sin(angle);
	vec2 rotated_v = vec2(VERTEX.x * c - VERTEX.y * s, VERTEX.x * s + VERTEX.y * c);

	// Deriva sutil determinista en el espacio
	vec2 drift_dir = vec2(cos(seed * 6.28318), sin(seed * 6.28318));
	vec2 drift_offset = drift_dir * (TIME * drift_speed * (0.5 + seed * 0.5));

	VERTEX = rotated_v + drift_offset;

	// Remapeamos UV a la región correspondiente en la textura atlas usando INSTANCE_CUSTOM
	UV = INSTANCE_CUSTOM.xy + UV * INSTANCE_CUSTOM.zw;
}

void fragment() {
	vec4 tex_color = texture(atlas_texture, UV);

	// Alpha testing con descarte temprano de fragmentos para eliminar recuadros
	if (tex_color.a < alpha_cutoff) {
		discard;
	}

	// Modulación de color por el color de la instancia
	COLOR = tex_color * COLOR;
}

