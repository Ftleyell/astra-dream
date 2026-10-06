shader_type canvas_item;

uniform sampler2D text_mask : hint_default_black, repeat_enable;
uniform vec4 tape_color : source_color = vec4(0.9, 0.12, 0.12, 1.0); // Rojo industrial base
uniform float scroll_speed : hint_range(-5.0, 5.0) = 0.8;
uniform float repetitions_x : hint_range(0.1, 100.0) = 6.0;

void fragment() {
	vec2 uv = UV;

	// Coordenadas perfectamente rectas y continuas sin distorsión
	vec2 tiled_uv;
	tiled_uv.x = fract((uv.x * repetitions_x) + (TIME * scroll_speed));
	tiled_uv.y = uv.y;

	// Leemos la forma de la letra (canal alfa)
	float letter_alpha = texture(text_mask, tiled_uv).a;

	// Recorte en negativo: transparente en las letras, sólido en la cinta
	float cutout_alpha = 1.0 - letter_alpha;

	COLOR = vec4(tape_color.rgb, cutout_alpha);
}
