shader_type canvas_item;
render_mode blend_premul_alpha;

uniform float fade_margin_left : hint_range(0.0, 0.35) = 0.12;
uniform float fade_margin_right : hint_range(0.0, 0.35) = 0.16;

void fragment() {
	vec4 text_buffer = texture(TEXTURE, UV);

	// Desvanecimiento óptico gradual en extremos izquierdo y derecho
	float left_falloff = smoothstep(0.0, fade_margin_left, UV.x);
	float right_falloff = smoothstep(1.0, 1.0 - fade_margin_right, UV.x);
	float alpha_vignette = left_falloff * right_falloff;

	COLOR = vec4(text_buffer.rgb, text_buffer.a * alpha_vignette);
}
