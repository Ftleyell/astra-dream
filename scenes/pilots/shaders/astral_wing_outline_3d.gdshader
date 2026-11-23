shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

// Contorno 3D caligráfico estilo ArcSys / pilot_rig_pass2.gdshader:
// - Extruye por la normal suave soldada (UV/UV2) para evitar grietas en aristas duras.
// - Modula el grosor según la luz (más grueso en sombra, más fino y afilado en luz).
// - Alterna el color de tinta entre índigo profundo en sombra y ciruela cálido en luz,
//   igualando la silueta de Valentina v2 (02_valentina_razor_sharp).

uniform float outline_width : hint_range(0.002, 0.10) = 0.020;
uniform float outline_calligraphy_amount : hint_range(0.0, 1.0) = 0.65;
uniform vec3 key_light_dir = vec3(-0.48, 0.68, 0.55);
uniform vec4 outline_color : source_color = vec4(0.045, 0.040, 0.095, 1.0);
uniform vec4 outline_lit_color : source_color = vec4(0.11, 0.035, 0.07, 1.0);
uniform float orbit_depth : hint_range(-1.0, 1.0) = 0.0;
uniform float depth_back_dim : hint_range(0.0, 0.8) = 0.22;

varying float v_lit_weight;

void vertex() {
	vec3 smooth_n = vec3(UV.x, UV.y, UV2.x);
	if (length(smooth_n) < 0.1) {
		smooth_n = NORMAL;
	} else {
		smooth_n = normalize(smooth_n);
	}

	// Normal en espacio de vista para caligrafía consistente respecto a la luz clave
	vec3 view_n = normalize((MODELVIEW_MATRIX * vec4(smooth_n, 0.0)).xyz);
	vec3 l = normalize(key_light_dir);
	float ndl = dot(view_n, l);
	v_lit_weight = smoothstep(-0.25, 0.55, ndl);

	// Lado de sombra más grueso (hasta 1.32x), lado iluminado más fino (hasta 0.62x)
	float callig_mul = mix(1.0, mix(1.32, 0.62, v_lit_weight), outline_calligraphy_amount);
	VERTEX += smooth_n * (outline_width * callig_mul);
}

void fragment() {
	vec3 ink = mix(outline_color.rgb, outline_lit_color.rgb, v_lit_weight * 0.72);
	float back_factor = clamp(-orbit_depth, 0.0, 1.0);
	float dim = 1.0 - back_factor * depth_back_dim * 0.28;
	ALBEDO = ink * dim;
}
