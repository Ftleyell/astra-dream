shader_type canvas_item;

// Anillos astrolabio contrarrotativos procedurales detrás del medallón de Stela Galactica.
// Geometría sagrada, arcos festoneados, ticks de grados y nodos orbitales luminosos.

uniform float outer_speed : hint_range(-1.0, 1.0) = 0.08;
uniform float inner_speed : hint_range(-1.0, 1.0) = -0.15;
uniform float global_alpha : hint_range(0.0, 1.0) = 0.62;
uniform vec4 primary_color : source_color = vec4(0.58, 0.42, 0.98, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.18, 0.90, 1.0, 1.0);
uniform float reveal_progress : hint_range(0.0, 1.0) = 1.0;
uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;

float _ring_line(float r, float target_r, float width) {
	return 1.0 - smoothstep(width * 0.45, width, abs(r - target_r));
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);

	float reveal_mask = 1.0 - smoothstep(max(0.01, reveal_progress - 0.14), reveal_progress + 0.02, r);
	float dissolve_mask = 1.0 - smoothstep(max(0.0, 1.05 - dissolve_progress * 1.25 - 0.18), max(0.01, 1.05 - dissolve_progress * 1.25), r);
	float active_mask = reveal_mask * (1.0 - dissolve_progress * 0.85) * smoothstep(1.0, 0.88, r);
	if (dissolve_progress > 0.01) {
		active_mask *= dissolve_mask;
	}
	if (active_mask < 0.005) {
		discard;
	}

	// Capa exterior: doble anillo + ticks orbitales + cruz sutil
	float a_out = ang + TIME * outer_speed;
	float outer_1 = _ring_line(r, 0.89, 0.010);
	float outer_2 = _ring_line(r, 0.83, 0.007);
	float outer_3 = _ring_line(r, 0.72, 0.008);

	float tick_ang = abs(fract(a_out * (36.0 / TAU)) - 0.5) * 2.0;
	float ticks = (1.0 - smoothstep(0.14, 0.24, tick_ang)) * smoothstep(0.83, 0.84, r) * (1.0 - smoothstep(0.88, 0.89, r));

	// Festones geométricos exteriores entre 0.66 y 0.78 (inspirados en la referencia)
	float petal_ang = abs(fract(a_out * (12.0 / TAU)) - 0.5) * 2.0;
	float petal_r = 0.71 + 0.055 * cos(petal_ang * 3.14159);
	float petal_arc = _ring_line(r, petal_r, 0.011) * step(0.64, r);

	// Capa interior contrarrotativa
	float a_in = ang + TIME * inner_speed;
	float inner_1 = _ring_line(r, 0.61, 0.011);
	float inner_2 = _ring_line(r, 0.54, 0.007);
	float inner_dash = step(0.32, fract(a_in * (16.0 / TAU)));
	float inner_dashed_ring = _ring_line(r, 0.575, 0.013) * inner_dash;

	// Ejes cardinales finos
	float axis_mask = smoothstep(0.55, 0.62, r) * (1.0 - smoothstep(0.92, 0.96, r));
	float cardinal = (1.0 - smoothstep(0.006, 0.014, abs(sin(a_out * 2.0) * r))) * axis_mask * 0.45;

	// Dos nodos orbitales brillantes (superior izquierdo e inferior derecho)
	vec2 orb_a = vec2(-0.46, -0.42);
	vec2 orb_b = vec2(0.46, 0.42);
	float da = length(p - orb_a);
	float db = length(p - orb_b);
	float orb_core = exp(-da * 14.0) + exp(-db * 14.0);
	float orb_ring = (_ring_line(da, 0.14, 0.010) + _ring_line(da, 0.20, 0.007) + _ring_line(db, 0.14, 0.010) + _ring_line(db, 0.20, 0.007)) * 0.75;

	float prim_energy = clamp(outer_1 + outer_2 * 0.7 + petal_arc * 0.8 + ticks * 0.65 + cardinal, 0.0, 1.2);
	float sec_energy = clamp(outer_3 * 0.75 + inner_1 + inner_2 * 0.7 + inner_dashed_ring * 0.85 + orb_ring, 0.0, 1.3);

	vec3 col = primary_color.rgb * prim_energy + secondary_color.rgb * sec_energy + vec3(0.85, 0.96, 1.0) * orb_core * 0.95;
	float alpha = clamp((prim_energy * 0.55 + sec_energy * 0.65 + orb_core * 0.85) * global_alpha * active_mask, 0.0, 1.0);

	COLOR = vec4(col, alpha);
}
