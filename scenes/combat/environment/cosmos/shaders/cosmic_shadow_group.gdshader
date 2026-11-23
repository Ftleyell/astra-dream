shader_type canvas_item;
render_mode blend_mul, unshaded;

/**
 * cosmic_shadow_group.gdshader
 *
 * Shader unificado de composición para el nodo CanvasGroup de sombras planetarias.
 * Muestrea la máscara aditiva combinada de todos los conos de sombra hijos
 * y aplica un único pase de oscurecimiento multiplicativo (blend_mul) con clampeo
 * de opacidad máxima.
 *
 * Esto garantiza matemáticamente la regla Anti Double-Darkening:
 * Donde dos o más sombras se cruzan, el valor se satura a la misma opacidad
 * máxima, evitando manchas hiperoscuras o artefactos de multiplicación doble.
 */

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 shadow_tint : source_color = vec4(0.18, 0.18, 0.24, 1.0);
uniform vec4 penumbra_tint : source_color = vec4(0.32, 0.30, 0.46, 1.0);
uniform vec4 twilight_tint : source_color = vec4(0.76, 0.42, 0.36, 1.0);
uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	vec4 mask_sample = textureLod(screen_texture, SCREEN_UV, 0.0);
	float umbra = clamp(mask_sample.r, 0.0, 1.0);
	float penumbra = clamp(mask_sample.g, 0.0, 1.0);
	float twilight = clamp(mask_sample.b, 0.0, 1.0);
	float max_mask = max(umbra, max(penumbra, twilight));

	if (max_mask <= 0.001) {
		COLOR = vec4(1.0, 1.0, 1.0, 1.0);
	} else {
		vec3 mult_color = mix(vec3(1.0), penumbra_tint.rgb, penumbra * shadow_opacity * 0.58);
		mult_color = mix(mult_color, shadow_tint.rgb, umbra * shadow_opacity);
		mult_color = mix(
			mult_color,
			mult_color * mix(vec3(1.0), twilight_tint.rgb * 1.25, 0.65),
			twilight * 0.55 * (1.0 - umbra * 0.65)
		);
		COLOR = vec4(clamp(mult_color, vec3(0.0), vec3(1.0)), 1.0);
	}
}
