shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

// Contorno 3D caligráfico ArcSys con compensación de distancia en vista/clip-space.
// - Extruye por la normal suave soldada en COLOR.rgb (con fallback a NORMAL).
// - Sincroniza disolución radial por demat_progress con las islas y props.

uniform float outline_width : hint_range(0.004, 0.12) = 0.014;
uniform float reference_distance : hint_range(1.0, 40.0) = 13.8;
uniform float min_world_width : hint_range(0.002, 0.05) = 0.005;
uniform float max_world_width : hint_range(0.010, 0.15) = 0.024;
uniform float outline_calligraphy_amount : hint_range(0.0, 1.0) = 0.65;

uniform vec3 key_light_dir = vec3(-0.48, 0.68, 0.55);
uniform vec4 outline_color : source_color = vec4(0.045, 0.040, 0.095, 1.0);
uniform vec4 outline_lit_color : source_color = vec4(0.11, 0.035, 0.07, 1.0);
uniform float calibration_factor : hint_range(0.0, 1.0) = 0.0;
uniform float tutorial_highlight_pulse : hint_range(0.0, 2.0) = 0.0;
uniform vec4 tutorial_highlight_color : source_color = vec4(0.28, 0.94, 1.0, 1.0);

uniform bool demat_invert = false;
uniform float demat_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 demat_origin = vec3(0.0);
uniform float demat_max_radius = 30.0;
uniform float demat_hex_scale = 2.4;

varying float v_lit_weight;
varying vec3 v_world_pos;

float _hex_cell(vec2 p) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	return max(abs(gv.x), dot(abs(gv), normalize(r)));
}

void vertex() {
	vec3 smooth_n = COLOR.rgb * 2.0 - 1.0;
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

	VERTEX += smooth_n * (world_w * callig_mul * (1.0 + tutorial_highlight_pulse * 0.45));
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (demat_progress > 0.001) {
		float d_origin = length(v_world_pos.xz - demat_origin.xz);
		float hex_jitter = _hex_cell(v_world_pos.xz * demat_hex_scale) * 2.2;
		float wave_r = mix(-2.5, demat_max_radius, demat_progress);
		float edge_d = d_origin + hex_jitter * 0.45;
		if ((!demat_invert && edge_d < wave_r) || (demat_invert && edge_d > wave_r)) {
			discard;
		}
	}
	vec3 ink = mix(outline_color.rgb, outline_lit_color.rgb, v_lit_weight * 0.72 * (1.0 - calibration_factor * 0.5));
	if (tutorial_highlight_pulse > 0.001) {
		ink = mix(ink, tutorial_highlight_color.rgb * (1.2 + tutorial_highlight_pulse * 0.65), clamp(tutorial_highlight_pulse * 0.85, 0.0, 1.0));
	}
	ALBEDO = ink;
}
