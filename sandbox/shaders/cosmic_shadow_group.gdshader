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
uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	vec4 mask_sample = textureLod(screen_texture, SCREEN_UV, 0.0);
	float mask_val = clamp(mask_sample.r, 0.0, 1.0);

	if (mask_val <= 0.001) {
		COLOR = vec4(1.0, 1.0, 1.0, 1.0);
	} else {
		float shadow_factor = mask_val * shadow_opacity;
		// Mezcla multiplicativa hacia el tinte cósmico frío/neutro
		vec3 mult_color = mix(vec3(1.0), shadow_tint.rgb, shadow_factor);
		COLOR = vec4(mult_color, 1.0);
	}
}
