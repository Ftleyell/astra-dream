shader_type canvas_item;

uniform sampler2D leading_edge_lut : filter_linear, repeat_disable;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float progress : hint_range(-0.5, 2.5) = 0.0;
uniform float ship_length_norm : hint_range(0.01, 1.0) = 0.12;

// Fade-out sutil de izquierda a derecha
uniform float fade_progress : hint_range(-0.5, 2.0) = -0.5;
uniform float fade_feather : hint_range(0.05, 1.0) = 0.38;

void fragment() {
	vec2 uv = UV;
	float v = clamp(uv.y, 0.0, 1.0);
	float offset = texture(leading_edge_lut, vec2(v, 0.5)).r;
	float front_x = progress - (offset * ship_length_norm);

	// Distancia respecto al frente de relieve de la silueta
	float dist_from_front = front_x - uv.x;
	float aa = fwidth(uv.x) * 1.5;
	float edge_alpha = smoothstep(-aa, aa, dist_from_front);

	float out_alpha = smoothstep(fade_progress - fade_feather, fade_progress, uv.x);
	COLOR = vec4(tint_color.rgb, tint_color.a * edge_alpha * out_alpha);
}