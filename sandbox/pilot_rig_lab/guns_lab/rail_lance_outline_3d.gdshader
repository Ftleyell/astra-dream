shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

// Contorno tipo inverted-hull con normales suaves precomputadas en UV/UV2
// para evitar grietas en aristas duras de mallas facetadas.
uniform float outline_width : hint_range(0.002, 0.12) = 0.032;
uniform vec4 outline_color : source_color = vec4(0.05, 0.06, 0.11, 1.0);
uniform float orbit_depth : hint_range(-1.0, 1.0) = 0.0;
uniform float depth_back_dim : hint_range(0.0, 0.8) = 0.28;

void vertex() {
	vec3 smooth_n = vec3(UV.x, UV.y, UV2.x);
	if (length(smooth_n) < 0.1) {
		smooth_n = NORMAL;
	} else {
		smooth_n = normalize(smooth_n);
	}
	VERTEX += smooth_n * outline_width;
}

void fragment() {
	float back_factor = clamp(-orbit_depth, 0.0, 1.0);
	float dim = 1.0 - back_factor * depth_back_dim * 0.35;
	ALBEDO = outline_color.rgb * dim;
}
