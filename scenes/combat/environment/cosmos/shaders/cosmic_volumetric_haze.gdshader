shader_type canvas_item;
render_mode blend_mix, unshaded;

/**
 * cosmic_volumetric_haze.gdshader
 *
 * Capa intermedia de neblina espacial volumétrica (paralaje ~0.72).
 * Se sitúa por encima de planetas/soles y por debajo de Valentina y proyectiles,
 * recogiendo forward scattering solar, recortándose tras los planetas e iluminándose
 * sutilmente alrededor del aura local de Valentina (especialmente dentro de eclipses).
 */

uniform sampler2D dust_texture : repeat_enable, filter_linear_mipmap;
uniform vec2 camera_world_position = vec2(0.0);
uniform vec2 viewport_resolution = vec2(1920.0, 1080.0);
uniform float camera_zoom = 1.0;
uniform float global_time = 0.0;
uniform float parallax_factor : hint_range(0.1, 1.2) = 0.72;

uniform vec4 biome_primary : source_color = vec4(0.28, 0.06, 0.52, 1.0);
uniform vec4 biome_secondary : source_color = vec4(0.03, 0.38, 0.62, 1.0);
uniform vec2 star_screen_uv = vec2(0.5, 0.5);
uniform vec4 star_color : source_color = vec4(1.0, 0.88, 0.55, 1.0);
uniform float star_influence : hint_range(0.0, 1.0) = 0.0;
uniform float star_heliopause_uv_r : hint_range(0.15, 6.0) = 1.2;
uniform float opacity_scale : hint_range(0.0, 0.35) = 0.17;

uniform float viewport_aspect = 1.7778;
uniform int planet_occluder_count : hint_range(0, 6) = 0;
uniform vec4 planet_occluders[6];

// Integración local dinámica con las alas de la piloto
uniform vec2 player_screen_uv = vec2(0.5, 0.5);
uniform vec4 player_aura_color : source_color = vec4(0.98, 0.16, 0.34, 1.0);
uniform float player_aura_radius_v : hint_range(0.04, 0.6) = 0.20;
uniform float player_aura_strength : hint_range(0.0, 1.0) = 0.85;
uniform float player_aura_energy : hint_range(0.0, 2.5) = 1.0;
uniform vec2 player_wing_axis = vec2(1.0, 0.0);
uniform float player_eclipse_factor : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float eff_zoom = max(camera_zoom, 0.05);
	vec2 world_span = viewport_resolution / eff_zoom;
	vec2 wp = camera_world_position * parallax_factor + (SCREEN_UV - vec2(0.5)) * world_span;

	float t = global_time;
	mat2 rot = mat2(vec2(0.86, -0.51), vec2(0.51, 0.86));
	float w1 = texture(dust_texture, wp * 0.00028 + vec2(t * 0.009, -t * 0.004)).r;
	float w2 = texture(dust_texture, (rot * wp) * 0.00056 - vec2(t * 0.006, t * 0.008)).r;

	float mist = smoothstep(0.22, 0.82, w1 * 0.64 + w2 * 0.46);

	vec2 aspect_scale = vec2(viewport_aspect, 1.0);
	vec2 frag_a = SCREEN_UV * aspect_scale;

	vec2 dp_a = frag_a - player_screen_uv * aspect_scale;
	vec2 w_dir = normalize(player_wing_axis + vec2(0.0001, 0.0));
	vec2 w_perp = vec2(-w_dir.y, w_dir.x);
	float wing_along = dot(dp_a, w_dir) / 1.38;
	float wing_cross = dot(dp_a, w_perp) / 0.88;
	float d_wing = length(vec2(wing_along, wing_cross));

	float p_rad = max(player_aura_radius_v, 0.045);
	float p_core = exp(-pow(d_wing / max(p_rad * 0.34, 0.022), 2.0) * 2.4);
	float p_glow = exp(-pow(d_wing / p_rad, 2.0) * 1.85);
	float p_scatter_env = clamp(p_core * 0.82 + p_glow * 0.68, 0.0, 1.35);
	if (mist <= 0.005 && (player_aura_strength * player_aura_energy * p_scatter_env) <= 0.015) {
		discard;
	}

	// Forward scattering solar
	vec2 star_a = star_screen_uv * aspect_scale;
	float star_dist = length(frag_a - star_a);
	float solar_scatter = pow(max(0.0, 1.0 - clamp(star_dist * 0.72, 0.0, 1.0)), 1.65) * star_influence;

	// Corredores de sombra volumétrica cortando la neblina tras los planetas (alineados con heliopausa real)
	float mist_shadow = 0.0;
	float edge_glow = 0.0;
	vec2 to_frag = frag_a - star_a;
	float frag_sun_d = length(to_frag);
	vec2 sun_ray_dir = (frag_sun_d > 0.0005) ? (to_frag / frag_sun_d) : vec2(1.0, 0.0);

	for (int i = 0; i < 6; i++) {
		if (i >= planet_occluder_count) {
			break;
		}
		vec2 p_a = planet_occluders[i].xy * aspect_scale;
		float p_r = planet_occluders[i].z;
		float p_exp = max(planet_occluders[i].w, 1.25);
		if (p_r <= 0.001) {
			continue;
		}
		vec2 to_p = p_a - star_a;
		float p_sun_d = length(to_p);
		if (p_sun_d <= 0.002 || p_sun_d >= star_heliopause_uv_r) {
			continue;
		}
		vec2 p_dir = to_p / p_sun_d;
		float align_check = dot(sun_ray_dir, p_dir);
		if (align_check > 0.0) {
			float proj = dot(frag_a - star_a, p_dir);
			if (proj > p_sun_d && proj < star_heliopause_uv_r) {
				float frag_from_p = length(frag_a - p_a);
				float sphere_clear = smoothstep(p_r * 0.96, p_r * 1.18, frag_from_p);
				float perp = length((frag_a - star_a) - p_dir * proj);
				float max_cone = max(star_heliopause_uv_r - p_sun_d, 0.25);
				float progress = clamp((proj - p_sun_d) / max_cone, 0.0, 1.0);
				float cone_r = p_r * mix(0.95, p_exp, pow(progress, 0.85));
				float helio_fade = smoothstep(star_heliopause_uv_r, star_heliopause_uv_r * 0.78, proj);
				float behind = smoothstep(p_sun_d + p_r * 0.35, p_sun_d + p_r * 0.85, proj) * sphere_clear * helio_fade;
				float sh = (1.0 - smoothstep(cone_r * 0.55, cone_r * 1.15, perp)) * behind;
				mist_shadow = max(mist_shadow, sh);
				float rim = smoothstep(cone_r * 0.90, cone_r * 1.08, perp) * (1.0 - smoothstep(cone_r * 1.08, cone_r * 1.48, perp)) * behind;
				edge_glow = max(edge_glow, rim);
			}
		}
	}

	vec3 base_mist = mix(biome_primary.rgb, biome_secondary.rgb, clamp(w2 * 1.1, 0.0, 1.0)) * 1.18;
	vec3 col = mix(base_mist, star_color.rgb * 1.32, clamp(solar_scatter * 0.68, 0.0, 0.80));
	col *= mix(1.0, 0.22, mist_shadow * 0.88);
	col += star_color.rgb * (edge_glow * star_influence * 0.36);

	float alpha = clamp(mist * opacity_scale * (0.76 + solar_scatter * 0.45) * (1.0 - mist_shadow * 0.45), 0.0, 0.20);

	// Emisión cromática real de las alas sobre polvo cercano, neblina y corredores de sombra/eclipse
	float dust_and_shadow = 0.24 + mist * 1.45 + max(mist_shadow, player_eclipse_factor) * 0.92;
	float wing_aura_w = (p_core * 0.92 + p_glow * dust_and_shadow) * player_aura_strength * player_aura_energy;
	col += player_aura_color.rgb * (wing_aura_w * 0.82);
	alpha = clamp(max(alpha, wing_aura_w * 0.24 * (0.48 + max(mist_shadow, player_eclipse_factor) * 0.82)), 0.0, 0.30);

	if (alpha <= 0.003) {
		discard;
	}
	COLOR = vec4(col, alpha);
}
