shader_type canvas_item;

uniform float fade_progress : hint_range(-0.5, 2.0) = -0.5;
uniform float fade_feather : hint_range(0.05, 1.0) = 0.38;

void fragment() {
	float out_alpha = smoothstep(fade_progress - fade_feather, fade_progress, SCREEN_UV.x);
	COLOR.a *= out_alpha;
}
