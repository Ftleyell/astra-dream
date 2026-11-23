shader_type canvas_item;
render_mode blend_mix, unshaded;

/**
 * cosmic_dust_mid.gdshader
 *
 * Cortinas atmosféricas de polvo interestelar anime (ParallaxDustMid, scroll ~0.38).
 * Se sitúa entre macro-galaxias y sistemas solares, con teñido de bioma y silver-lining
 * hacia la estrella activa más cercana, manteniendo opacidad sutil para lectura danmaku.
 */

uniform sampler2D dust_texture : repeat_enable, filter_linear_mipmap;
uniform vec2 camera_world_position = vec2(0.0);
uniform vec2 viewport_resolution = vec2(1920.0, 1080.0);
uniform float camera_zoom = 1.0;
uniform float global_time = 0.0;
uniform float parallax_factor : hint_range(0.05, 1.0) = 0.38;

uniform vec4 biome_primary : source_color = vec4(0.24, 0.06, 0.40, 1.0);
uniform vec4 biome_secondary : source_color = vec4(0.04, 0.30, 0.50, 1.0);
uniform vec2 star_screen_pos = vec2(960.0, 540.0);
uniform vec4 star_color : source_color = vec4(1.0, 0.85, 0.50, 1.0);
uniform float star_influence : hint_range(0.0, 1.0) = 0.0;
uniform float opacity_scale : hint_range(0.0, 0.45) = 0.24;

void fragment() {
	vec2 screen_coord = SCREEN_UV * viewport_resolution;
	float eff_zoom = max(camera_zoom, 0.05);
	vec2 world_span = viewport_resolution / eff_zoom;
	vec2 wp = camera_world_position * parallax_factor + (SCREEN_UV - vec2(0.5)) * world_span;

	float t = global_time;
	mat2 rot = mat2(vec2(0.82, -0.57), vec2(0.57, 0.82));
	float d1 = texture(dust_texture, wp * 0.00046 + vec2(t * 0.014, -t * 0.007)).r;
	float d2 = texture(dust_texture, (rot * wp) * 0.00088 - vec2(t * 0.009, t * 0.011)).r;
	float d3 = texture(dust_texture, wp * 0.00024 + vec2(-t * 0.006, t * 0.005)).r;

	float wisp = smoothstep(0.18, 0.78, d1 * 0.68 + d2 * 0.44);
	float dark_cloud = smoothstep(0.36, 0.82, d3 * 0.72 + d1 * 0.35) * (1.0 - wisp * 0.65);
	if (wisp <= 0.005 && dark_cloud <= 0.005) {
		discard;
	}

	float d_star = length(screen_coord - star_screen_pos) / max(length(viewport_resolution) * 0.65, 1.0);
	float solar_rim = pow(max(0.0, 1.0 - clamp(d_star, 0.0, 1.0)), 1.55) * star_influence;

	vec3 base_col = mix(biome_primary.rgb, biome_secondary.rgb, clamp(d2 * 1.15, 0.0, 1.0)) * 1.25;
	vec3 wisp_col = mix(base_col, star_color.rgb * 1.38, clamp(solar_rim * 0.72, 0.0, 0.82));
	float edge_rim = clamp(wisp * (1.0 - wisp) * 4.0, 0.0, 1.0);
	wisp_col += star_color.rgb * (edge_rim * solar_rim * 0.55);

	vec3 dark_col = biome_primary.rgb * 0.16 + vec3(0.004, 0.006, 0.015);
	float wisp_alpha = wisp * opacity_scale * (0.72 + solar_rim * 0.48);
	float dark_alpha = dark_cloud * opacity_scale * 0.85 * (1.0 - solar_rim * 0.42);
	float alpha = clamp(max(wisp_alpha, dark_alpha), 0.0, 0.36);
	vec3 col = mix(dark_col, wisp_col, smoothstep(0.05, 0.45, wisp));
	COLOR = vec4(col, alpha);
}
