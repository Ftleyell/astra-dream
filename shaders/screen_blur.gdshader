shader_type canvas_item;

// Shader de desenfoque de pantalla optimizado para interfaces de usuario y modales (Godot 4).
// Utiliza textureLod sobre hint_screen_texture con filtro mipmap para alto rendimiento.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.8;
uniform vec4 tint_color : source_color = vec4(0.015, 0.02, 0.05, 0.85);

void fragment() {
	vec4 blurred = textureLod(screen_texture, SCREEN_UV, blur_amount);
	COLOR = mix(blurred, tint_color, tint_color.a);
}
