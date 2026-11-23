shader_type canvas_item;
render_mode blend_add, unshaded;

/**
 * cosmic_foreground_atmosphere.gdshader
 *
 * Capa atmosférica frontal sutil (CosmosForegroundAtmosphere, parallax ~1.12).
 * Renderiza micro-motas rápidas de velocidad espacial y un velo óptico solar muy tenue
 * encima del plano de vuelo (y muy por debajo del HUD), escalable según calidad GPU.
 */

uniform vec2 camera_world_position = vec2(0.0);
uniform vec2 viewport_resolution = vec2(1920.0, 1080.0);
uniform float global_time = 0.0;
uniform float parallax_factor : hint_range(0.8, 1.6) = 1.12;

uniform bool enable_solar_veil = true;
uniform bool enable_anamorphic_glare = true;
uniform vec2 star_screen_pos = vec2(960.0, 540.0);
uniform vec4 star_color : source_color = vec4(1.0, 0.88, 0.55, 1.0);
uniform vec4 biome_secondary : source_color = vec4(0.10, 0.45, 0.75, 1.0);
uniform float star_influence : hint_range(0.0, 1.0) = 0.0;
uniform float star_screen_visibility : hint_range(0.0, 1.0) = 1.0;
uniform bool is_black_hole_star = false;
uniform float motes_intensity : hint_range(0.0, 1.0) = 0.34;
uniform float veil_intensity : hint_range(0.0, 0.35) = 0.09;
uniform float anamorphic_intensity : hint_range(0.0, 0.5) = 0.24;
uniform float halation_strength : hint_range(0.0, 0.35) = 0.14;
uniform vec2 player_velocity_screen = vec2(0.0, 0.0);
uniform float domain_entry_pulse : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 screen_coord = SCREEN_UV * viewport_resolution;
	vec2 wp = camera_world_position * parallax_factor + (screen_coord - viewport_resolution * 0.5);

	vec3 accum = vec3(0.0);
	float alpha_out = 0.0;

	// Viento solar radial dentro del dominio + estiramiento direccional por velocidad de Valentina
	vec2 radial_dir = normalize(screen_coord - star_screen_pos + vec2(0.0001));
	float wind_sign = is_black_hole_star ? 1.0 : -1.0;
	vec2 solar_wind = (star_influence > 0.12) ? (radial_dir * (wind_sign * global_time * 36.0 * star_influence)) : vec2(0.0);

	float speed_mag = clamp(length(player_velocity_screen), 0.0, 1.4);
	bool stretch_motes = speed_mag > 0.08;
	vec2 vel_dir = stretch_motes ? (player_velocity_screen / speed_mag) : vec2(1.0, 0.0);
	vec2 vel_perp = vec2(-vel_dir.y, vel_dir.x);
	float streak_stretch = 1.0 + speed_mag * 4.2;
	float speed_boost = stretch_motes ? (1.0 + speed_mag * 0.65) : 1.0;

	// Dos estratos muy dispersos de micro-motas espaciales rápidas (no confunden con proyectiles)
	for (int layer_i = 0; layer_i < 2; layer_i++) {
		float cell_sz = (layer_i == 0) ? 165.0 : 255.0;
		float wind_w = (layer_i == 0) ? 0.75 : 1.15;
		vec2 drift = wp * (layer_i == 0 ? 1.0 : 1.18) + vec2(global_time * (layer_i == 0 ? 18.0 : -14.0), global_time * 9.0) + solar_wind * wind_w;
		vec2 grid = floor(drift / cell_sz);
		vec2 local = fract(drift / cell_sz) - vec2(0.5);

		float h1 = hash21(grid + vec2(float(layer_i) * 37.0, 11.0));
		if (h1 > 0.72) {
			float h2 = hash21(grid * 1.37 + vec2(5.1, 19.3));
			vec2 offset = vec2(h1 - 0.86, h2 - 0.5) * 0.68;
			vec2 dm = (local - offset) * cell_sz;
			float d = stretch_motes
				? length(vec2(dot(dm, vel_dir) / streak_stretch, dot(dm, vel_perp)))
				: length(dm * vec2(0.85, 1.15));
			float speck = exp(-d * d * 0.24) * (0.55 + 0.45 * sin(global_time * (1.8 + h2 * 2.5) + h1 * 40.0));
			vec3 speck_col = mix(biome_secondary.rgb * 1.4, mix(vec3(0.95, 0.98, 1.0), star_color.rgb, clamp(star_influence * 0.85, 0.0, 1.0)), mix(h2, 1.0, star_influence * 0.35));
			float w = speck * motes_intensity * (layer_i == 0 ? 0.65 : 0.90) * speed_boost;
			accum += speck_col * w;
			alpha_out = max(alpha_out, w * 0.75);
		}
	}

	// Velo óptico direccional suave hacia la estrella activa cercana (con respiro al cruzar heliopausa)
	if (enable_solar_veil && star_influence > 0.05 && star_screen_visibility > 0.02) {
		float d_star = length(screen_coord - star_screen_pos) / max(length(viewport_resolution) * 0.75, 1.0);
		float eff_veil = veil_intensity + domain_entry_pulse * 0.09;
		float glow = pow(max(0.0, 1.0 - clamp(d_star, 0.0, 1.0)), 2.4) * star_influence * star_screen_visibility * eff_veil;
		accum += star_color.rgb * glow;
		alpha_out = max(alpha_out, glow * 0.85);
	}

	// Destello anamórfico horizontal + halación celuloide + iris fantasma (solo calidad alta)
	if (enable_anamorphic_glare && star_influence > 0.06 && star_screen_visibility > 0.02) {
		float bh_scale = is_black_hole_star ? 0.55 : 1.0;
		float res_h = max(viewport_resolution.y, 1.0);
		float res_w = max(viewport_resolution.x, 1.0);
		vec2 d_px = screen_coord - star_screen_pos;
		float dx = d_px.x / res_w;
		float dy = d_px.y / res_h;
		float r_star = length(vec2(d_px.x / res_h, dy));

		float core_streak = exp(-abs(dy) * 95.0) * exp(-abs(dx) * 2.2);
		float wide_wing = exp(-abs(dy) * 28.0) * exp(-abs(dx) * 1.1) * 0.35;
		vec3 streak_col = mix(vec3(0.45, 0.72, 1.0), star_color.rgb, 0.62);
		float s_w = (core_streak + wide_wing) * anamorphic_intensity * star_influence * star_screen_visibility * bh_scale;
		accum += streak_col * s_w;

		float halation = exp(-r_star * 4.5) * halation_strength * star_influence * star_screen_visibility * bh_scale;
		vec3 halo_col = mix(star_color.rgb, vec3(1.0, 0.82, 0.68), 0.35);
		accum += halo_col * halation;

		// Sutil iris fantasma en cuadrante opuesto al sol
		vec2 sun_uv = star_screen_pos / vec2(res_w, res_h);
		vec2 ghost_uv = vec2(1.0) - sun_uv;
		vec2 d_ghost = (SCREEN_UV - ghost_uv) * vec2(res_w / res_h, 1.0);
		float r_ghost = length(d_ghost);
		float ghost_ring = exp(-pow((r_ghost - 0.048) / 0.014, 2.0)) * 0.45 + exp(-pow(r_ghost / 0.026, 2.0)) * 0.55;
		float ghost_w = ghost_ring * 0.055 * star_influence * star_screen_visibility * bh_scale;
		vec3 ghost_col = mix(biome_secondary.rgb * 1.25, star_color.rgb, 0.45);
		accum += ghost_col * ghost_w;

		alpha_out = max(alpha_out, clamp(s_w + halation * 0.8 + ghost_w, 0.0, 0.35));
	}

	if (alpha_out <= 0.003) {
		discard;
	}
	COLOR = vec4(accum, clamp(alpha_out, 0.0, 0.35));
}
