shader_type canvas_item;
render_mode blend_mix;

uniform float ss_scale : hint_range(1.0, 2.5) = 2.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * (0.21 * ss_scale);
	vec4 c = textureLod(TEXTURE, UV, 0.0);
	vec4 t0 = textureLod(TEXTURE, clamp(UV + vec2(-px.x, -px.y), vec2(0.0), vec2(1.0)), 0.0);
	vec4 t1 = textureLod(TEXTURE, clamp(UV + vec2( px.x, -px.y), vec2(0.0), vec2(1.0)), 0.0);
	vec4 t2 = textureLod(TEXTURE, clamp(UV + vec2(-px.x,  px.y), vec2(0.0), vec2(1.0)), 0.0);
	vec4 t3 = textureLod(TEXTURE, clamp(UV + vec2( px.x,  px.y), vec2(0.0), vec2(1.0)), 0.0);
	vec4 avg = c * 0.44 + (t0 + t1 + t2 + t3) * 0.14;
	COLOR = max(avg, vec4(0.0));
}
