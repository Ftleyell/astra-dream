shader_type canvas_item;
render_mode blend_add;

/**
 * galaxy_deep.gdshader
 *
 * Renderizador de galaxia espiral profunda en el vacío estelar.
 * - Modo aditivo suave (blend_add) para fundirse orgánicamente con el universo.
 * - Rotación suave y continua de sus brazos espirales.
 * - Núcleo estelar activo con destellos sutiles procedimentales.
 * - Decaimiento radial suave hacia los bordes para eliminar cualquier línea de corte cuadrada.
 */

uniform float spin_speed : hint_range(-0.1, 0.1) = 0.004;
uniform vec2 galaxy_center = vec2(0.5, 0.5);
uniform float core_pulse_speed : hint_range(0.1, 5.0) = 1.2;
uniform float core_pulse_intensity : hint_range(0.0, 1.0) = 0.22;
uniform float overall_brightness : hint_range(0.1, 2.5) = 0.85;
uniform float radial_fade_start : hint_range(0.1, 0.5) = 0.35;
uniform float radial_fade_end : hint_range(0.2, 0.6) = 0.49;
uniform vec4 tint_color : source_color = vec4(0.95, 0.90, 1.0, 1.0);


void fragment() {
	vec2 delta = UV - galaxy_center;
	float dist = length(delta);

	vec4 tex = texture(TEXTURE, UV);


	// 2. Destellos sutiles y armónicos en el núcleo galáctico
	float core_dist = dist / max(radial_fade_start, 0.001);
	float core_mask = exp(-core_dist * core_dist * 4.0);
	float twinkle = sin(TIME * core_pulse_speed) * 0.5 + sin(TIME * (core_pulse_speed * 1.63) + 1.4) * 0.5;
	float core_sparkle = 1.0 + twinkle * core_pulse_intensity * core_mask;

	// 3. Decaimiento radial elíptico / esférico suave para eliminar bordes del archivo JPG
	float fade = 1.0 - smoothstep(radial_fade_start, radial_fade_end, dist);

	vec3 final_rgb = tex.rgb * tint_color.rgb * overall_brightness * core_sparkle;
	float final_alpha = tex.a * fade * tint_color.a;

	COLOR = vec4(final_rgb, final_alpha);
}
