shader_type canvas_item;
render_mode blend_add, unshaded;

// deep_starfield.gdshader
// Renderizado óptico multi-estrato para buffer estelar 8K (3 profundidades paralácticas):
// 0. Lecho abismal de micro-estrellas tipo Vía Láctea (0.25x scroll_scale)
// 1. Estrato espectral principal (1.0x scroll_scale)
// 2. Estrellas cercanas heroicas en cruz + estrellas fugaces y destellos de horizonte (4.5x scroll_scale)

uniform sampler2D starfield_texture : repeat_enable, filter_linear;
uniform float star_intensity : hint_range(0.1, 10.0) = 4.0;
uniform float threshold_cutoff : hint_range(0.005, 0.20) = 0.02;

uniform float window_scale : hint_range(0.1, 10.0) = 1.35;
uniform vec2 window_offset = vec2(0.0);

uniform float twinkle_amount : hint_range(0.0, 1.0) = 0.35;
uniform float twinkle_speed : hint_range(0.1, 10.0) = 2.2;

uniform float lens_flare_intensity : hint_range(0.0, 5.0) = 2.5;
uniform float lens_flare_length : hint_range(0.1, 5.0) = 2.0;
uniform float hero_sparkle_intensity : hint_range(0.0, 2.0) = 0.85;

uniform float abyss_stars_intensity : hint_range(0.0, 2.0) = 0.62;
uniform float shooting_star_intensity : hint_range(0.0, 2.0) = 0.72;
uniform float distant_nova_intensity : hint_range(0.0, 2.0) = 0.55;

uniform vec4 tint_red_star : source_color = vec4(1.80, 0.40, 0.20, 1.0);
uniform vec4 tint_yellow_star : source_color = vec4(1.70, 1.40, 0.35, 1.0);
uniform vec4 tint_blue_star : source_color = vec4(0.50, 1.10, 2.10, 1.0);

uniform float global_time = 0.0;
uniform vec2 camera_world_position = vec2(0.0);
uniform vec2 viewport_resolution = vec2(1920.0, 1080.0);
uniform vec2 scroll_scale = vec2(0.0015);

float hash_star(vec2 p) {
	vec2 i = floor(p);
	return fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	const float BUFFER_SIZE = 8192.0;
	vec2 screen_coord = FRAGCOORD.xy;
	vec2 centered_sc = screen_coord - viewport_resolution * 0.5;

	// Estrato 0: polvo estelar abismal casi inmóvil (0.25x scroll)
	vec3 abyss_star_col = vec3(0.0);
	float ab_luma = 0.0;
	if (abyss_stars_intensity > 0.01) {
		mat2 rot28 = mat2(vec2(0.883, -0.469), vec2(0.469, 0.883));
		vec2 abyss_pos = camera_world_position * (scroll_scale * 0.25) + rot28 * centered_sc;
		vec2 abyss_uv = (abyss_pos * (window_scale * 2.35) + vec2(2113.0, 4871.0)) / BUFFER_SIZE;
		vec3 ab_raw = textureLod(starfield_texture, abyss_uv, 0.0).rgb;
		ab_luma = max(ab_raw.r, max(ab_raw.g, ab_raw.b));
		if (ab_luma >= threshold_cutoff * 1.4) {
			float ab_norm = smoothstep(threshold_cutoff * 1.4, 0.78, ab_luma);
			float ab_seed = hash_star(floor(abyss_uv * 2048.0));
			vec3 ab_tint = mix(vec3(0.55, 0.72, 1.0), vec3(1.0, 0.90, 0.74), ab_seed);
			float ab_twinkle = 0.85 + 0.15 * sin(global_time * (twinkle_speed * 0.55) + ab_seed * 6.2831853);
			abyss_star_col = ab_tint * (pow(ab_norm, 1.65) * abyss_stars_intensity * 0.42 * star_intensity * 0.65 * ab_twinkle);
		}
	}

	// Estrato 1: buffer estelar espectral principal (1.0x scroll)
	vec2 star_world_pos = camera_world_position * scroll_scale + centered_sc;
	vec2 base_uv = (star_world_pos * window_scale + window_offset) / BUFFER_SIZE;
	vec3 star_raw = textureLod(starfield_texture, base_uv, 0.0).rgb;
	float star_luma = max(star_raw.r, max(star_raw.g, star_raw.b));

	// Estrato 2: estrellas heroicas en cruz con mayor paralaje (4.5x scroll)
	vec3 hero_cross = vec3(0.0);
	if (hero_sparkle_intensity > 0.01) {
		float cell_sz = 260.0;
		vec2 near_pos = camera_world_position * (scroll_scale * 4.5) + centered_sc;
		vec2 cell_id = floor(near_pos / cell_sz);
		float h_spawn = hash_star(cell_id * 1.17 + vec2(9.3, 4.7));
		if (h_spawn > 0.80) {
			float hx = hash_star(cell_id + vec2(31.7, 17.3));
			float hy = hash_star(cell_id + vec2(61.1, 89.9));
			float hcol = hash_star(cell_id + vec2(12.5, 43.1));
			vec2 local_p = (fract(near_pos / cell_sz) - vec2(0.18 + hx * 0.64, 0.18 + hy * 0.64)) * cell_sz;
			float flare_r = mix(10.0, 22.0, hx) * clamp(lens_flare_length * 0.55, 0.4, 2.0);
			vec2 lp = local_p / max(flare_r, 1.0);
			float arm_x = exp(-abs(lp.x) * 1.8) * exp(-abs(lp.y) * 18.0);
			float arm_y = exp(-abs(lp.y) * 1.8) * exp(-abs(lp.x) * 18.0);
			float core_dot = exp(-dot(lp, lp) * 18.0);
			float twinkle_h = 0.55 + 0.45 * sin(global_time * (twinkle_speed * 0.85 + hcol * 1.4) + h_spawn * 31.4);
			float cross_val = (arm_x + arm_y + core_dot * 1.4) * hero_sparkle_intensity * twinkle_h;
			vec3 hc_tint = mix(vec3(0.65, 0.90, 1.0), mix(vec3(1.0, 0.82, 0.45), vec3(1.0, 0.55, 0.90), hcol), hx);
			hero_cross = hc_tint * cross_val * 0.95;
		}
	}

	// Eventos vivos de cielo profundo: estrellas fugaces lejanas
	vec3 shooting_star = vec3(0.0);
	if (shooting_star_intensity > 0.01) {
		float sc_sz = 560.0;
		vec2 sc_world = camera_world_position * (scroll_scale * 3.0) + centered_sc;
		vec2 sc_cell = floor(sc_world / sc_sz);
		float h_en = hash_star(sc_cell * 2.71 + vec2(17.1, 83.4));
		float h_ph = hash_star(sc_cell * 5.13 + vec2(41.9, 13.7));
		float t_cyc = fract((global_time + h_ph * 11.0) / 11.0);
		if (h_en > 0.68 && t_cyc < 0.11) {
			float prog = t_cyc / 0.11;
			float ang = mix(-0.75, 0.75, hash_star(sc_cell + vec2(9.1, 21.3))) + (h_ph > 0.5 ? 0.35 : 2.79);
			vec2 dir = vec2(cos(ang), sin(ang));
			vec2 p0 = vec2(0.5) - dir * 0.24;
			vec2 head = p0 + dir * (prog * 0.48);
			vec2 sc_loc = fract(sc_world / sc_sz);
			vec2 tail_vec = sc_loc - head;
			float along = dot(tail_vec, -dir) * sc_sz;
			float perp = abs(dot(tail_vec, vec2(-dir.y, dir.x))) * sc_sz;
			float streak_env = sin(prog * 3.1415926);
			float len_px = 85.0 * streak_env;
			if (along >= 0.0 && along <= max(len_px, 1.0)) {
				float head_glow = exp(-along * 0.065) * exp(-(perp * perp) / 1.8);
				vec3 streak_col = mix(vec3(0.45, 0.82, 1.0), vec3(0.95, 0.99, 1.0), exp(-along * 0.14));
				shooting_star = clamp(streak_col * (head_glow * streak_env * shooting_star_intensity * 0.65), vec3(0.0), vec3(0.65));
			}
		}
	}

	// Micro-destellos distantes (pulsares/novas en horizonte abismal)
	vec3 distant_nova = vec3(0.0);
	if (distant_nova_intensity > 0.01) {
		float nv_sz = 340.0;
		vec2 nv_world = camera_world_position * (scroll_scale * 0.45) + centered_sc;
		vec2 nv_cell = floor(nv_world / nv_sz);
		float nv_h = hash_star(nv_cell * 3.37 + vec2(57.2, 19.8));
		if (nv_h > 0.88) {
			vec2 nv_off = vec2(hash_star(nv_cell + vec2(4.1, 8.7)), hash_star(nv_cell + vec2(9.2, 3.6))) * 0.6 + 0.2;
			vec2 nv_p = (fract(nv_world / nv_sz) - nv_off) * nv_sz;
			float pulse_nv = pow(max(0.0, sin(global_time * 0.48 + nv_h * 40.0)), 8.0);
			float diam = exp(-(abs(nv_p.x) + abs(nv_p.y)) * 0.28) + exp(-dot(nv_p, nv_p) * 0.12) * 0.6;
			vec3 nv_col = mix(vec3(0.75, 0.55, 1.0), vec3(0.45, 0.95, 1.0), fract(nv_h * 19.3));
			distant_nova = nv_col * (diam * pulse_nv * distant_nova_intensity * 0.65);
		}
	}

	if (star_luma < threshold_cutoff && ab_luma < threshold_cutoff * 1.4 && length(hero_cross) < 0.008 && length(shooting_star) < 0.008 && length(distant_nova) < 0.008) {
		discard;
	}

	vec3 final_star_base = vec3(0.0);
	if (star_luma >= threshold_cutoff) {
		float normalized_luma = smoothstep(threshold_cutoff, 0.85, star_luma);
		float radial_curve = pow(normalized_luma, 1.25);

		vec2 star_uv_block = floor(base_uv * 2048.0);
		float star_seed = hash_star(star_uv_block);
		float star_seed2 = hash_star(star_uv_block + vec2(73.1, 151.7));

		vec3 spectral_tint;
		if (star_seed < 0.35) {
			spectral_tint = mix(vec3(1.95, 0.55, 0.20), vec3(1.85, 0.85, 0.30), star_seed2);
		} else if (star_seed < 0.65) {
			spectral_tint = mix(vec3(1.75, 1.50, 0.50), vec3(1.30, 1.35, 1.05), star_seed2);
		} else if (star_seed < 0.90) {
			spectral_tint = mix(vec3(0.50, 1.15, 2.25), vec3(0.70, 1.50, 2.10), star_seed2);
		} else {
			spectral_tint = mix(vec3(1.40, 0.60, 2.10), vec3(0.40, 1.85, 1.20), star_seed2);
		}

		float star_magnitude = 0.55 + star_seed2 * 0.90;
		float current_time = global_time;
		float time_seed = current_time * twinkle_speed + star_seed * 6.2831853;
		float wave_a = sin(time_seed);
		float wave_b = sin(time_seed * 2.73 + star_seed * 3.14);
		float composite_twinkle = wave_a * 0.65 + wave_b * 0.35;

		float spike_climax = pow(max(0.0, composite_twinkle), 4.5);
		float twinkle = 0.70 + 0.30 * composite_twinkle + (spike_climax * twinkle_amount * 2.0);

		vec3 colored_body = spectral_tint * radial_curve * 2.6;
		float core_intensity = pow(normalized_luma, 2.8);
		vec3 core_glow = (spectral_tint * 1.8 + vec3(0.25)) * (core_intensity * 0.65);

		float center_peak = smoothstep(0.40, 0.95, star_luma);
		float cross_sparkle = pow(center_peak, 2.2) * (0.35 + spike_climax * 1.6) * lens_flare_intensity;
		vec3 cross_glint = (spectral_tint * 1.5 + vec3(0.30)) * (cross_sparkle * 0.40);

		vec3 star_disc = (colored_body + core_glow + cross_glint) * star_magnitude;
		final_star_base = star_disc * twinkle * star_intensity;
	}

	COLOR = vec4(abyss_star_col + final_star_base + hero_cross + shooting_star + distant_nova, 1.0);
}
