shader_type canvas_item;
render_mode blend_add, unshaded;

/**
 * planetary_crepuscular_shaft.gdshader
 *
 * Emite filos crepusculares aditivos tangentes al cono de sombra de cada planeta
 * donde la luz estelar atraviesa el polvo espacial justo por fuera de la penumbra.
 */

uniform float base_radius = 120.0;
uniform float expansion_factor : hint_range(1.0, 3.5) = 1.85;
uniform float penumbra_ratio : hint_range(0.05, 0.9) = 0.45;
uniform float planet_sun_dist = 2000.0;
uniform float heliopause_radius = 4500.0;
uniform float heliosphere_edge_feather : hint_range(0.02, 0.5) = 0.22;
uniform float cone_length = 2600.0;
uniform float quad_height = 900.0;

uniform vec4 shaft_color : source_color = vec4(1.0, 0.88, 0.65, 1.0);
uniform float shaft_strength : hint_range(0.0, 1.0) = 0.45;
uniform float global_time = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 41.23);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	if (shaft_strength <= 0.005) {
		discard;
	}

	float x_dist = clamp(UV.x, 0.0, 1.0) * cone_length;
	float y_dist = (UV.y - 0.5) * quad_height;
	float abs_y = abs(y_dist);

	float x_from_sun = planet_sun_dist + x_dist;
	float r_sun = sqrt((x_from_sun * x_from_sun) + (y_dist * y_dist));
	if (r_sun >= heliopause_radius) {
		discard;
	}

	float norm_r = r_sun / max(heliopause_radius, 1.0);
	float edge_fade = smoothstep(1.0, 1.0 - heliosphere_edge_feather, norm_r);

	float dist_ratio = clamp(x_dist / max(cone_length, 1.0), 0.0, 1.0);
	float r_penumbra = base_radius * mix(1.03, expansion_factor, pow(dist_ratio, 0.88));
	float y_rim = r_penumbra * 1.04;
	float band_width = max(base_radius * 0.22, 16.0) * (1.0 + dist_ratio * 1.4);

	float dy = abs_y - y_rim;
	float rim_band = exp(-pow(dy / band_width, 2.0));
	if (rim_band <= 0.01) {
		discard;
	}

	float r_local = length(vec2(x_dist, y_dist));
	float sphere_attach = smoothstep(base_radius * 0.72, base_radius * 1.08, r_local);
	float long_taper = pow(1.0 - dist_ratio, 1.15);

	float n1 = value_noise(vec2(x_dist * 0.0032 - global_time * 0.04, y_dist * 0.0075));
	float n2 = value_noise(vec2(x_dist * 0.0068 + global_time * 0.02, y_dist * 0.014 - global_time * 0.015));
	float wisp = 0.58 + 0.52 * (n1 * 0.65 + n2 * 0.35);

	float intensity = clamp(rim_band * sphere_attach * edge_fade * long_taper * wisp * shaft_strength * 0.32, 0.0, 0.32);
	if (intensity <= 0.002) {
		discard;
	}

	vec3 col = clamp(shaft_color.rgb * intensity, vec3(0.0), vec3(0.32));
	COLOR = vec4(col, 1.0);
}
