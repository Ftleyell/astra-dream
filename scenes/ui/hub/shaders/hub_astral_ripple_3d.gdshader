shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// Doble onda astral luminosa + destello central de impulso para el rebote contra el suelo en el Hub 3D.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ripple_color : source_color = vec4(0.55, 0.88, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 1.15;
uniform float inner_ratio : hint_range(0.25, 0.85) = 0.54;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);

	float edge_fade = 1.0 - smoothstep(0.86, 0.99, r);
	float t = clamp(progress, 0.0, 1.0);
	float ease_out = 1.0 - pow(1.0 - t, 2.35);
	float ease_inner = 1.0 - pow(1.0 - t, 1.85);

	// 1. Onda exterior astral expansiva con sutil modulación armónica de 6 lóbulos
	float outer_rad = mix(0.14, 0.92, ease_out);
	float outer_w = mix(0.085, 0.032, t);
	float outer_d = abs(r - outer_rad);
	float outer_ring = (1.0 - smoothstep(0.0, outer_w, outer_d));
	float astral_lobes = 0.88 + 0.12 * cos(ang * 6.0 + t * 3.2);
	float outer_alpha = outer_ring * astral_lobes * (1.0 - smoothstep(0.35, 1.0, t));

	// 2. Anillo interior nítido con núcleo blanco-luminoso
	float inner_rad = mix(0.08, inner_ratio * 0.95, ease_inner);
	float inner_w = mix(0.060, 0.022, t);
	float inner_d = abs(r - inner_rad);
	float inner_ring = 1.0 - smoothstep(0.0, inner_w, inner_d);
	float inner_alpha = inner_ring * (1.0 - smoothstep(0.18, 0.88, t));

	// 3. Destello suave bajo las botas en el instante del rebote
	float flash_t = 1.0 - smoothstep(0.0, 0.38, t);
	float center_flash = exp(-r * r * 14.0) * flash_t * 0.85;

	float total_light = (outer_alpha * 0.78 + inner_alpha * 1.05 + center_flash) * edge_fade * intensity;
	vec3 col = mix(ripple_color.rgb, core_color.rgb, clamp(inner_alpha * 0.75 + center_flash * 0.9, 0.0, 1.0));

	ALBEDO = col * total_light;
	ALPHA = clamp(total_light * ripple_color.a, 0.0, 1.0);
}
