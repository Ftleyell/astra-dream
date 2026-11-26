shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 focus_uv = vec2(0.45, 0.45);
uniform float aspect_ratio = 1.7777778;
uniform vec2 ellipse_scale = vec2(1.0, 1.12);
uniform float inner_radius : hint_range(0.02, 0.8) = 0.17;
uniform float outer_radius : hint_range(0.05, 1.2) = 0.33;
uniform float blur_strength : hint_range(0.0, 6.0) = 2.4;
uniform float dim_strength : hint_range(0.0, 0.95) = 0.56;
uniform vec4 dim_color : source_color = vec4(0.035, 0.045, 0.11, 1.0);
uniform float effect_alpha : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	if (effect_alpha <= 0.001) {
		discard;
	}

	vec2 delta = SCREEN_UV - focus_uv;
	delta.x *= aspect_ratio;
	delta *= ellipse_scale;
	float dist = length(delta);

	float safe_outer = max(outer_radius, inner_radius + 0.01);
	float mask = smoothstep(inner_radius, safe_outer, dist) * effect_alpha;

	if (mask <= 0.001) {
		discard;
	}

	float lod = blur_strength * mask;
	vec2 px = SCREEN_PIXEL_SIZE * (1.2 + blur_strength * 2.2) * mask;
	vec2 diag = px * 0.70710678;

	vec3 col = textureLod(screen_tex, SCREEN_UV, lod).rgb * 0.24;
	col += textureLod(screen_tex, SCREEN_UV + vec2( px.x,  0.0), lod).rgb * 0.095;
	col += textureLod(screen_tex, SCREEN_UV + vec2(-px.x,  0.0), lod).rgb * 0.095;
	col += textureLod(screen_tex, SCREEN_UV + vec2( 0.0,  px.y), lod).rgb * 0.095;
	col += textureLod(screen_tex, SCREEN_UV + vec2( 0.0, -px.y), lod).rgb * 0.095;
	col += textureLod(screen_tex, SCREEN_UV + vec2( diag.x,  diag.y), lod).rgb * 0.095;
	col += textureLod(screen_tex, SCREEN_UV + vec2(-diag.x,  diag.y), lod).rgb * 0.095;
	col += textureLod(screen_tex, SCREEN_UV + vec2( diag.x, -diag.y), lod).rgb * 0.095;
	col += textureLod(screen_tex, SCREEN_UV + vec2(-diag.x, -diag.y), lod).rgb * 0.095;

	vec3 dimmed = mix(col, dim_color.rgb, clamp(dim_strength * mask, 0.0, 0.96));
	float edge_alpha = smoothstep(0.0, 0.035, mask);
	COLOR = vec4(dimmed, edge_alpha);
}
