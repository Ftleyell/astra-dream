shader_type canvas_item;
render_mode blend_mix, unshaded;

// debris_cutout.gdshader
// Shader para fragmentos de restos espaciales instanciados en GPU vía MultiMeshInstance2D.
// Emplea un atlas 2D unificado indexado por INSTANCE_CUSTOM,
// rotación angular y deriva procedural en vertex shader (Zero CPU cost),
// y alpha-cutoff con descarte de fragmentos (discard) para evitar bordes cuadrados.

uniform sampler2D atlas_texture : filter_linear_mipmap;
uniform float global_time = 0.0;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.08;
uniform float drift_speed : hint_range(0.0, 100.0) = 15.0;
uniform float spin_speed_mult : hint_range(0.0, 5.0) = 0.8;

uniform float cell_radius = 6000.0;
uniform float edge_fade_margin = 1200.0;

varying vec2 v_local_pos;

void vertex() {
	v_local_pos = VERTEX;
	float t = (global_time > 0.0) ? global_time : TIME;
	// Semilla determinista derivada de UVs y coordenadas del atlas
	float seed = fract(sin(float(INSTANCE_ID) * 12.9898 + INSTANCE_CUSTOM.x * 78.233 + INSTANCE_CUSTOM.y * 37.719) * 43758.5453);
	float spin_rate = (seed - 0.5) * 2.0 * spin_speed_mult;
	float angle = t * spin_rate;

	// Rotación 2D limpia sobre el centro del quad local (-0.5 .. 0.5)
	float c = cos(angle);
	float s = sin(angle);
	vec2 rotated_v = vec2(VERTEX.x * c - VERTEX.y * s, VERTEX.x * s + VERTEX.y * c);

	// Deriva armónica suave con amplitud atenuada para evitar jitter subpixel frente a la cámara
	vec2 drift_offset = vec2(
		cos(t * 0.15 + seed * 6.28318),
		sin(t * 0.12 + seed * 6.28318)
	) * (drift_speed * 0.02);

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

	// Desvanecimiento suave en los bordes extremos del cuadrante para evitar cortes bruscos
	float dist_from_center = max(abs(v_local_pos.x), abs(v_local_pos.y));
	float fade_factor = 1.0 - smoothstep(cell_radius - edge_fade_margin, cell_radius, dist_from_center);

	// Modulación de color por el color de la instancia y fade perimetral
	COLOR = tex_color * COLOR;
	COLOR.a *= fade_factor;
}

