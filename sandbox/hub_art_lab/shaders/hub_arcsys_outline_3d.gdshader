shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

// Contorno 3D caligráfico ArcSys con compensación de distancia en vista/clip-space.
// - Extruye por la normal suave soldada (UV.xy / UV2.x) para evitar grietas en aristas duras.
// - Escala proporcionalmente a la profundidad de vista dentro de límites seguros para mantener
//   un grosor uniforme tanto en cámara Diorama (-42°) como en zoom frontal de Cápsula Central.

uniform float outline_width : hint_range(0.004, 0.12) = 0.014;
uniform float reference_distance : hint_range(1.0, 40.0) = 13.8;
uniform float min_world_width : hint_range(0.002, 0.05) = 0.005;
uniform float max_world_width : hint_range(0.010, 0.15) = 0.024;
uniform float outline_calligraphy_amount : hint_range(0.0, 1.0) = 0.65;

uniform vec3 key_light_dir = vec3(-0.48, 0.68, 0.55);
uniform vec4 outline_color : source_color = vec4(0.045, 0.040, 0.095, 1.0);
uniform vec4 outline_lit_color : source_color = vec4(0.11, 0.035, 0.07, 1.0);
uniform float calibration_factor : hint_range(0.0, 1.0) = 0.0;

varying float v_lit_weight;

void vertex() {
	vec3 smooth_n = vec3(UV.x, UV.y, UV2.x);
	if (length(smooth_n) < 0.1) {
		smooth_n = NORMAL;
	} else {
		smooth_n = normalize(smooth_n);
	}

	vec3 view_n = normalize((MODELVIEW_MATRIX * vec4(smooth_n, 0.0)).xyz);
	vec3 l = normalize(key_light_dir);
	float ndl = dot(view_n, l);
	v_lit_weight = smoothstep(-0.25, 0.55, ndl);

	float callig_mul = mix(1.0, mix(1.32, 0.62, v_lit_weight), outline_calligraphy_amount);
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float dist = max(-view_pos.z, 0.5);
	float dist_scale = dist / max(reference_distance, 0.5);
	float world_w = clamp(outline_width * dist_scale, min_world_width, max_world_width);

	VERTEX += smooth_n * (world_w * callig_mul);
}

void fragment() {
	vec3 ink = mix(outline_color.rgb, outline_lit_color.rgb, v_lit_weight * 0.72 * (1.0 - calibration_factor * 0.5));
	ALBEDO = ink;
}
