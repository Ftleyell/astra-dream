shader_type canvas_item;
render_mode blend_add, unshaded;

/**
 * warp_gate_ring.gdshader
 * Apertura hiperespacial Anime Space-Opera para Puertas de Salto y Estaciones Relé (Cosmos Engine v3.2).
 * Anillos rúnicos antialiaseados, 8 nodos energéticos suaves en rotación, iris espiral y 2 haces guía
 * hacia estrellas vecinas, con fade radial estricto (cero píxeles cuadrados / cero cortes de quad).
 */

uniform float global_time = -1.0;
uniform float seed_phase : hint_range(0.0, 6.2832) = 0.0;
uniform int quality_level : hint_range(0, 2) = 2;

uniform vec4 primary_color : source_color = vec4(0.22, 0.88, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.74, 0.42, 1.0, 1.0);
uniform vec4 biome_tint_color : source_color = vec4(0.18, 0.28, 0.55, 1.0);

uniform float guide_angle_a = 0.0;
uniform float guide_strength_a : hint_range(0.0, 1.5) = 0.0;
uniform float guide_angle_b = 1.57;
uniform float guide_strength_b : hint_range(0.0, 1.5) = 0.0;
uniform float overall_intensity : hint_range(0.0, 2.5) = 1.05;

float eval_guide_beam(vec2 p, float angle, float strength, float t) {
	if (strength <= 0.001) {
		return 0.0;
	}
	vec2 dir = vec2(cos(angle), sin(angle));
	vec2 nrm = vec2(-dir.y, dir.x);
	float along = dot(p, dir);
	if (along <= 0.11) {
		return 0.0;
	}
	float perp = abs(dot(p, nrm));
	float beam_w = mix(0.006, 0.018, clamp((along - 0.12) / 0.36, 0.0, 1.0));
	float core = exp(-pow(perp / beam_w, 2.0) * 3.2);
	float halo = exp(-pow(perp / (beam_w * 3.0), 2.0) * 1.6);
	float start_fade = smoothstep(0.115, 0.18, along);
	float end_fade = 1.0 - smoothstep(0.32, 0.482, along);
	float pulse = 0.72 + 0.28 * sin(along * 46.0 - t * 3.4);
	return (core * 0.78 + halo * 0.30) * start_fade * end_fade * pulse * strength;
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	if (r >= 0.495) {
		discard;
	}

	float t = (global_time >= 0.0) ? global_time : TIME;
	float ang = atan(p.y, p.x);
	float outer_env = 1.0 - smoothstep(0.34, 0.490, r);

	// Anillos técnicos concéntricos contrarrotantes con ticks radiales limpios
	float ring_outer = exp(-pow((r - 0.146) / 0.009, 2.0));
	float ring_inner = exp(-pow((r - 0.112) / 0.007, 2.0));
	float seg_a = smoothstep(0.05, 0.85, sin(ang * 8.0 + t * 0.75 + seed_phase));
	float seg_b = smoothstep(0.15, 0.88, sin(ang * 24.0 - t * 1.15 - seed_phase));
	float tick_ring = exp(-pow((r - 0.172) / 0.005, 2.0)) * smoothstep(0.72, 0.96, sin(ang * 32.0 - t * 0.45));
	float tech_ring = ring_outer * (0.48 + 0.52 * seg_a) + ring_inner * (0.45 + 0.55 * seg_b) + tick_ring * 0.65;

	// 8 nodos energéticos circulares suaves sobre el anillo principal (sin aliasing ni bloques)
	float node_rot = ang + t * 0.28 + seed_phase;
	float sector_step = TAU / 8.0;
	float sector_ang = mod(node_rot + sector_step * 0.5, sector_step) - sector_step * 0.5;
	vec2 node_delta = vec2(r - 0.146, r * sector_ang);
	float node_dist = length(node_delta);
	float node_core = exp(-node_dist * 130.0) * 1.15;
	float node_halo = (quality_level >= 1) ? exp(-node_dist * 44.0) * 0.42 : 0.0;
	float rune_nodes = node_core + node_halo;

	// Iris energético interno en espiral
	float swirl_phase = ang * 5.0 - r * 38.0 - t * 1.65 + seed_phase;
	float iris_band = 0.5 + 0.5 * sin(swirl_phase);
	float iris_env = smoothstep(0.032, 0.085, r) * (1.0 - smoothstep(0.115, 0.175, r));
	float iris = iris_env * (0.30 + 0.70 * iris_band);

	// Pulso expansivo de navegación
	float pulse_r = 0.12 + 0.20 * fract(t * 0.24 + seed_phase * 0.159);
	float shock = exp(-pow((r - pulse_r) / 0.008, 2.0)) * (1.0 - smoothstep(0.16, 0.34, pulse_r));

	// Haces guía direccionales hacia estrellas vecinas
	float beam_a = eval_guide_beam(p, guide_angle_a, guide_strength_a, t);
	float beam_b = eval_guide_beam(p, guide_angle_b, guide_strength_b, t);

	vec3 c_prim = mix(primary_color.rgb, biome_tint_color.rgb, 0.16);
	vec3 c_acc = mix(accent_color.rgb, biome_tint_color.rgb, 0.20);
	vec3 core_hot = mix(c_prim, vec3(0.95, 0.99, 1.0), 0.58);

	vec3 col = vec3(0.0);
	col += core_hot * (tech_ring * 0.88 + rune_nodes * 0.85);
	col += mix(c_acc, c_prim, iris_band) * (iris * 0.65);
	col += c_acc * (shock * 0.44);
	col += mix(c_prim, vec3(0.92, 0.98, 1.0), 0.38) * ((beam_a + beam_b) * 0.62);

	col *= outer_env * overall_intensity;
	float alpha = clamp(max(col.r, max(col.g, col.b)), 0.0, 1.0);
	COLOR = vec4(col, alpha);
}
