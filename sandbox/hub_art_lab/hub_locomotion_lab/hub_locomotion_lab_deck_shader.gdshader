shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Deck de calibración astral para Hub 3D Locomotion Lab con grilla métrica 1m/4m, anillos concéntricos y ejes 8-dir.

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 xz = v_world_pos.xz;
	float r = length(xz);

	vec3 base_col = vec3(0.035, 0.045, 0.085);
	float radial_tint = exp(-r * r * 0.0045);
	base_col += vec3(0.025, 0.032, 0.065) * radial_tint;

	// Grilla métrica 1m y líneas maestras 4m
	vec2 g1 = abs(fract(xz - 0.5) - 0.5) / max(fwidth(xz), vec2(0.0005));
	float line_1m = 1.0 - min(min(g1.x, g1.y), 1.0);

	vec2 g4 = abs(fract(xz * 0.25 - 0.5) - 0.5) / max(fwidth(xz * 0.25), vec2(0.0005));
	float line_4m = 1.0 - min(min(g4.x, g4.y), 1.0);

	// Anillos concéntricos cada 4m para medir longitud de salto y ripples
	float ring_d = abs(fract(r * 0.25 + 0.5) - 0.5) / max(fwidth(r * 0.25), 0.0005);
	float ring_line = 1.0 - min(ring_d, 1.0);

	// Ejes cardinales X / Z
	float axis_x = 1.0 - smoothstep(0.0, 0.045, abs(xz.y));
	float axis_z = 1.0 - smoothstep(0.0, 0.045, abs(xz.x));

	float edge_fade = 1.0 - smoothstep(18.0, 24.0, r);

	vec3 col = base_col;
	col = mix(col, vec3(0.11, 0.16, 0.28), line_1m * 0.45 * edge_fade);
	col = mix(col, vec3(0.22, 0.44, 0.72), line_4m * 0.65 * edge_fade);
	col = mix(col, vec3(0.32, 0.78, 0.96), ring_line * 0.40 * edge_fade);
	col = mix(col, vec3(0.95, 0.34, 0.58), axis_x * 0.35 * edge_fade);
	col = mix(col, vec3(0.32, 0.90, 1.00), axis_z * 0.35 * edge_fade);

	ALBEDO = col;
}
