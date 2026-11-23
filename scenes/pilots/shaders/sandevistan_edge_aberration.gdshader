shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength_px : hint_range(0.0, 24.0) = 0.0;
uniform float inner_clear_radius : hint_range(0.2, 0.85) = 0.42;

void fragment() {
	if (strength_px <= 0.05) {
		COLOR = vec4(0.0);
	} else {
		vec2 centered = SCREEN_UV - vec2(0.5);
		float dist = length(centered) * 1.4142135;
		float edge_mask = smoothstep(inner_clear_radius, 1.05, dist);
		vec2 dir = dist > 0.0001 ? (centered / max(length(centered), 0.0001)) : vec2(1.0, 0.0);
		vec2 offset = dir * strength_px * edge_mask * SCREEN_PIXEL_SIZE;

		float r = textureLod(screen_texture, clamp(SCREEN_UV + offset, vec2(0.0), vec2(1.0)), 0.0).r;
		float g = textureLod(screen_texture, SCREEN_UV, 0.0).g;
		float b = textureLod(screen_texture, clamp(SCREEN_UV - offset, vec2(0.0), vec2(1.0)), 0.0).b;

		COLOR = vec4(r, g, b, edge_mask);
	}
}
