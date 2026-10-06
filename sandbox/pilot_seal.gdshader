shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fade_progress : hint_range(-0.5, 2.0) = -0.5;
uniform float fade_feather : hint_range(0.05, 1.0) = 0.38;

void fragment() {
	vec4 base_tex = texture(TEXTURE, UV);
	float out_alpha = smoothstep(fade_progress - fade_feather, fade_progress, SCREEN_UV.x);
	COLOR = vec4(tint_color.rgb, base_tex.a * tint_color.a * out_alpha);
}
