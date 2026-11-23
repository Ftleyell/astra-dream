shader_type canvas_item;
render_mode blend_add, unshaded;

/**
 * galaxy_deep.gdshader (v3.3)
 *
 * Renderizador aditivo animado e integrado al bioma para landmarks cósmicos lejanos:
 * - Usa v_modulate desde vertex() en lugar de `* COLOR` para no multiplicar por
 *   la textura estática sin animar ni oscurecer la escena con halos de sticker.
 * - landmark_mode = 0: Galaxia espiral inclinada (rotación diferencial dual-phase en plano 3D + cúmulos estelares orbitales).
 * - landmark_mode = 1: Remanente de supernova (expansión radial dual-phase + ondas de choque + haz pulsar rotatorio).
 * - landmark_mode = 3: Galaxia de canto (flujo orbital bidireccional limpio sin manchas grises + núcleos y cúmulos).
 */

uniform float spin_speed : hint_range(-0.1, 0.1) = 0.015;
uniform vec2 galaxy_center = vec2(0.5, 0.5);
uniform float core_pulse_speed : hint_range(0.1, 5.0) = 1.2;
uniform float core_pulse_intensity : hint_range(0.0, 1.0) = 0.36;
uniform float overall_brightness : hint_range(0.1, 3.0) = 0.96;
uniform float radial_fade_start : hint_range(0.1, 0.5) = 0.36;
uniform float radial_fade_end : hint_range(0.2, 0.6) = 0.492;
uniform vec4 tint_color : source_color = vec4(0.95, 0.92, 1.0, 1.0);
uniform vec4 biome_tint_color : source_color = vec4(0.24, 0.45, 0.85, 1.0);
uniform float biome_harmony_mix : hint_range(0.0, 0.75) = 0.44;

uniform int landmark_mode : hint_range(0, 3) = 0;
uniform float anim_speed : hint_range(0.0, 4.0) = 1.0;
uniform float depth_haze_strength : hint_range(0.0, 0.9) = 0.52;
uniform float dark_edge_dissolve : hint_range(0.0, 1.0) = 0.94;
uniform float max_opacity : hint_range(0.1, 1.0) = 0.64;
uniform float halo_glow_strength : hint_range(0.0, 1.0) = 0.44;
uniform float global_time = 0.0;
uniform float global_time_override = -1.0;
uniform float phase_offset = 0.0;
uniform float tilt_x : hint_range(-1.15, 1.15) = 0.0;
uniform float tilt_y : hint_range(-1.15, 1.15) = 0.0;
uniform float perspective_fov : hint_range(0.0, 1.1) = 0.56;
uniform float depth_fade_strength : hint_range(0.0, 0.6) = 0.34;

varying vec4 v_modulate;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec2 rotate2d(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec2 p_uv = UV;
	float depth_rel = 0.0;
	if (perspective_fov > 0.001 && (abs(tilt_x) + abs(tilt_y)) > 0.001) {
		float persp_d = 1.0 / clamp(perspective_fov, 0.05, 1.1);
		float cx = cos(tilt_x);
		float sx = sin(tilt_x);
		float cy = cos(tilt_y);
		float sy = sin(tilt_y);
		vec3 pl_n = normalize(vec3(sy * cx, sx, cy * cx));
		vec3 pl_t = normalize(vec3(cy, 0.0, -sy));
		vec3 pl_b = normalize(cross(pl_n, pl_t));
		vec2 scr_p = UV - vec2(0.5);
		vec3 ray = vec3(scr_p.x, scr_p.y, persp_d);
		float denom = dot(ray, pl_n);
		if (denom <= 0.10) {
			discard;
		}
		float t_hit = (persp_d * pl_n.z) / denom;
		if (t_hit <= 0.05 || t_hit > 6.0) {
			discard;
		}
		vec3 hit_p = ray * t_hit - vec3(0.0, 0.0, persp_d);
		p_uv = vec2(dot(hit_p, pl_t), dot(hit_p, pl_b)) * 1.08 + vec2(0.5);
		if (p_uv.x <= 0.004 || p_uv.x >= 0.996 || p_uv.y <= 0.004 || p_uv.y >= 0.996) {
			discard;
		}
		depth_rel = clamp((t_hit - 1.0) * 1.65, -0.55, 0.55);
	}

	float t = ((global_time_override >= 0.0) ? global_time_override : ((global_time > 0.001) ? global_time : TIME)) + phase_offset;
	vec2 radial_delta = p_uv - galaxy_center;
	float dist = length(radial_delta);
	float fade = 1.0 - smoothstep(radial_fade_start, radial_fade_end, dist);
	if (fade <= 0.001 || v_modulate.a <= 0.001) {
		discard;
	}

	vec4 tex = vec4(0.0);
	float mode_glow = 0.0;
	vec3 mode_glow_col = biome_tint_color.rgb;
	float halo_mask = 0.0;
	float silhouette_mask = 1.0;
	float dust_veil_depth = 1.0;

	if (landmark_mode == 3) {
		// Galaxia de canto (~ -33.11 deg medida sobre PNG 1024x1024, núcleo en 0.497, 0.492)
		const vec2 EDGE_CENTER = vec2(0.497, 0.492);
		const float C_E = 0.8376;
		const float S_E = -0.5463;
		vec2 d_e = p_uv - EDGE_CENTER;
		float u_axis = d_e.x * C_E + d_e.y * S_E;
		float v_perp = -d_e.x * S_E + d_e.y * C_E;

		// Silueta limpia elíptica + bulbo para eliminar completamente halos grises y manchas de puntas
		float disc_env = exp(-pow(u_axis / 0.328, 2.0) * 1.10) * exp(-pow(v_perp / 0.052, 2.0));
		float bulge_env = exp(-pow(u_axis / 0.155, 2.0) - pow(v_perp / 0.095, 2.0));
		float clean_env = smoothstep(0.05, 0.38, max(disc_env, bulge_env * 1.10));
		float tip_fade = 1.0 - smoothstep(0.27, 0.41, abs(u_axis));
		silhouette_mask = clean_env * tip_fade;

		// Corriente orbital dual-phase bidireccional: borde cercano y lejano fluyen en sentidos opuestos
		float lane_dir = mix(-1.0, 1.0, smoothstep(-0.018, 0.018, v_perp));
		float flow_env = smoothstep(0.025, 0.14, abs(u_axis))
			* (1.0 - smoothstep(0.27, 0.40, abs(u_axis)))
			* exp(-pow(v_perp / 0.062, 2.0));

		float flow_rate = 0.18 * anim_speed;
		float p0 = fract(t * flow_rate);
		float p1 = fract(p0 + 0.5);
		float w_blend = abs(2.0 * p0 - 1.0);
		vec2 flow_vec = vec2(C_E, S_E) * (0.072 * flow_env * lane_dir);
		vec2 uv0 = clamp(p_uv - flow_vec * (p0 - 0.5), vec2(0.001), vec2(0.999));
		vec2 uv1 = clamp(p_uv - flow_vec * (p1 - 0.5), vec2(0.001), vec2(0.999));
		tex = mix(texture(TEXTURE, uv0), texture(TEXTURE, uv1), w_blend);

		// Preservar corte oscuro ecuatorial natural (sin brillo añadido sobre el carril de polvo v_perp ≈ 0)
		float dust_lane_mask = mix(0.22, 1.0, smoothstep(0.004, 0.021, abs(v_perp)));
		float rim_band = exp(-pow((abs(v_perp) - 0.023) / 0.023, 2.0)) * exp(-pow(u_axis / 0.315, 2.0)) * tip_fade;
		float stream_wave = pow(0.5 + 0.5 * sin(u_axis * 19.0 - t * 2.55 * anim_speed * lane_dir + abs(v_perp) * 16.0), 2.1);
		float stream_knots = pow(max(0.0, sin(u_axis * 36.0 - t * 3.15 * anim_speed * lane_dir) * cos((v_perp - 0.012 * lane_dir) * 50.0)), 3.2);
		float agn_core = exp(-pow(u_axis / 0.125, 2.0) - pow(v_perp / 0.058, 2.0)) * (0.74 + 0.26 * sin(t * 2.05 * anim_speed));

		// Cúmulos globulares sutiles orbitando en el halo vertical del bulbo
		float halo_field = exp(-pow(u_axis / 0.22, 2.0) - pow(v_perp / 0.16, 2.0)) * smoothstep(0.055, 0.11, abs(v_perp));
		vec2 cluster_cell = vec2(u_axis * 26.0, v_perp * 30.0 + sin(t * 0.35 + u_axis * 8.0) * 0.15);
		vec2 cl_id = floor(cluster_cell);
		vec2 cl_f = fract(cluster_cell) - vec2(0.5);
		float cl_rnd = hash21(cl_id + vec2(17.0, 9.0));
		float cl_dot = (cl_rnd > 0.87) ? smoothstep(0.24, 0.0, length(cl_f)) * (0.55 + 0.45 * sin(t * (2.2 + cl_rnd * 3.0) + cl_rnd * 12.0)) * halo_field : 0.0;

		mode_glow = rim_band * (stream_wave * 0.78 + stream_knots * 0.92) * dust_lane_mask + agn_core * 0.52 + cl_dot * 0.58;
		float core_blend = clamp(exp(-u_axis * u_axis * 16.0) + agn_core * 0.58, 0.0, 1.0);
		mode_glow_col = mix(vec3(0.42, 0.92, 1.0), vec3(1.0, 0.91, 0.72), core_blend);

		// Halo estelar limpio ortogonal reemplazando la mancha gris del asset
		float disc_halo = exp(-(u_axis * u_axis * 9.0 + v_perp * v_perp * 62.0)) * tip_fade;
		float bipolar_halo = exp(-(u_axis * u_axis * 22.0 + v_perp * v_perp * 20.0));
		halo_mask = clamp(max(disc_halo, bipolar_halo * 0.68), 0.0, 1.0);
	} else if (landmark_mode == 1) {
		// Remanente de supernova: expansión radial dual-phase + ondas expansivas + pulsar rotatorio
		const vec2 SNR_CENTER = vec2(0.499, 0.497);
		vec2 d_s = p_uv - SNR_CENTER;
		float dist_s = length(d_s);
		vec2 dir_uv = (dist_s > 0.0005) ? (d_s / dist_s) : vec2(1.0, 0.0);
		vec2 perp_uv = vec2(-dir_uv.y, dir_uv.x);
		float ang_s = atan(d_s.y, d_s.x);

		float blast_rate = 0.145 * anim_speed;
		float p0 = fract(t * blast_rate);
		float p1 = fract(p0 + 0.5);
		float w_blend = abs(2.0 * p0 - 1.0);
		float exp_env = smoothstep(0.030, 0.22, dist_s) * (1.0 - smoothstep(0.34, 0.48, dist_s));
		float swirl_curl = sin(ang_s * 4.0 + dist_s * 14.0) * 0.014;
		vec2 adv0 = dir_uv * ((p0 - 0.5) * 0.068 * exp_env) + perp_uv * ((p0 - 0.5) * swirl_curl * exp_env);
		vec2 adv1 = dir_uv * ((p1 - 0.5) * 0.068 * exp_env) + perp_uv * ((p1 - 0.5) * swirl_curl * exp_env);
		tex = mix(
			texture(TEXTURE, clamp(p_uv - adv0, vec2(0.001), vec2(0.999))),
			texture(TEXTURE, clamp(p_uv - adv1, vec2(0.001), vec2(0.999))),
			w_blend
		);

		// Dos ondas de choque escalonadas iluminando los filamentos de la nebulosa
		float s_t1 = fract(t * 0.24 * anim_speed);
		float s_t2 = fract(s_t1 + 0.5);
		float sh1 = exp(-pow((dist_s - (0.060 + s_t1 * 0.35)) / 0.036, 2.0)) * sin(s_t1 * 3.14159);
		float sh2 = exp(-pow((dist_s - (0.060 + s_t2 * 0.35)) / 0.036, 2.0)) * sin(s_t2 * 3.14159);
		float shock_waves = (sh1 + sh2) * 0.92;

		// Haces de faro rotatorios del pulsar central + destello cruzado
		float jet_a = t * 0.62 * anim_speed;
		vec2 jet_dir = vec2(cos(jet_a), sin(jet_a));
		float cone_align = pow(abs(dot(dir_uv, jet_dir)), 9.0);
		float jet_beam = cone_align * smoothstep(0.012, 0.08, dist_s) * exp(-dist_s * 6.4) * (0.72 + 0.28 * sin(t * 3.2 * anim_speed));

		float p_breath = 0.72 + 0.28 * sin(t * 2.4 * anim_speed);
		float cross_h = exp(-abs(d_s.y) * 84.0) * exp(-abs(d_s.x) * 14.0);
		float cross_v = exp(-abs(d_s.x) * 84.0) * exp(-abs(d_s.y) * 14.0);
		float center_star = (cross_h + cross_v + exp(-dist_s * dist_s * 135.0)) * p_breath;

		float tex_fil_luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		mode_glow = shock_waves * mix(0.32, 1.48, smoothstep(0.08, 0.52, tex_fil_luma)) + jet_beam * 0.82 + center_star * 0.74;
		mode_glow_col = mix(vec3(0.42, 0.92, 1.0), vec3(1.0, 0.82, 0.94), clamp(center_star + jet_beam * 0.6, 0.0, 1.0));
		halo_mask = exp(-dist_s * dist_s * 9.5);
		silhouette_mask = 1.0 - smoothstep(0.36, 0.48, dist_s);
	} else {
		// Galaxia espiral inclinada (~ -35.86 deg medida sobre PNG 1024x1024, núcleo en 0.506, 0.492)
		const vec2 SPIRAL_CENTER = vec2(0.506, 0.492);
		const float C_S = 0.8105;
		const float S_S = -0.5858;
		const float DISC_ASPECT = 1.72;

		vec2 d_sp = p_uv - SPIRAL_CENTER;
		float ex = d_sp.x * C_S + d_sp.y * S_S;
		float ey = (-d_sp.x * S_S + d_sp.y * C_S) * DISC_ASPECT;
		vec2 disc_p = vec2(ex, ey);
		float r_disc = length(disc_p);
		float ang_disc = atan(ey, ex);

		// Flujo rotacional diferencial 3D dual-phase (mantiene inclinación elíptica intacta)
		float spin_boost = 1.0 + abs(spin_speed) * 12.0;
		float flow_rate = 0.095 * anim_speed * spin_boost;
		float p0 = fract(t * flow_rate);
		float p1 = fract(p0 + 0.5);
		float w_blend = abs(2.0 * p0 - 1.0);

		float radial_rate = mix(1.25, 0.48, smoothstep(0.05, 0.38, r_disc))
			* smoothstep(0.015, 0.065, r_disc)
			* (1.0 - smoothstep(0.32, 0.45, r_disc));
		float flow_arc = 0.46 * ((spin_speed < 0.0) ? -1.0 : 1.0);

		vec2 dp0 = rotate2d(disc_p, -(p0 - 0.5) * flow_arc * radial_rate);
		vec2 dp1 = rotate2d(disc_p, -(p1 - 0.5) * flow_arc * radial_rate);
		dp0.y /= DISC_ASPECT;
		dp1.y /= DISC_ASPECT;
		vec2 uv0 = clamp(SPIRAL_CENTER + vec2(dp0.x * C_S - dp0.y * S_S, dp0.x * S_S + dp0.y * C_S), vec2(0.001), vec2(0.999));
		vec2 uv1 = clamp(SPIRAL_CENTER + vec2(dp1.x * C_S - dp1.y * S_S, dp1.x * S_S + dp1.y * C_S), vec2(0.001), vec2(0.999));
		tex = mix(texture(TEXTURE, uv0), texture(TEXTURE, uv1), w_blend);

		// Ondas de densidad espiral recorriendo brazos reales
		float dir_s = (spin_speed < 0.0) ? -1.0 : 1.0;
		float arm_wave = pow(0.5 + 0.5 * sin(ang_disc * 2.0 - log(max(r_disc, 0.04)) * 4.8 - t * 1.35 * anim_speed * dir_s), 2.2);
		float arm_wave2 = pow(0.5 + 0.5 * cos(ang_disc * 3.0 - r_disc * 14.0 - t * 0.95 * anim_speed * dir_s), 3.0);
		float arm_band = smoothstep(0.045, 0.15, r_disc) * (1.0 - smoothstep(0.30, 0.44, r_disc));
		float bulge_glow = exp(-r_disc * r_disc * 26.0) * (0.28 + 0.08 * sin(t * 1.6 * anim_speed));

		// Cúmulos estelares luminosos orbitando dentro del plano inclinado (wrap entero sin costura en atan)
		float omega_cluster = mix(0.24, 0.10, smoothstep(0.06, 0.35, r_disc)) * anim_speed * dir_s;
		float a_rot = mod(ang_disc - t * omega_cluster, 6.2831853);
		const float SEG_A = 24.0;
		vec2 polar_grid = vec2(r_disc * 22.0, (a_rot / 6.2831853) * SEG_A);
		vec2 p_id = floor(polar_grid);
		p_id.y = mod(p_id.y, SEG_A);
		vec2 p_f = fract(polar_grid) - vec2(0.5);
		float kn_rnd = hash21(p_id + vec2(3.1, 7.7));
		float cluster_knot = (kn_rnd > 0.80) ? smoothstep(0.26, 0.0, length(p_f)) * (0.55 + 0.45 * sin(t * (2.0 + kn_rnd * 2.6) + kn_rnd * 10.0)) * arm_band : 0.0;

		float spiral_luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		mode_glow = (arm_wave * 0.42 + arm_wave2 * 0.26) * arm_band * mix(0.22, 1.15, smoothstep(0.12, 0.55, spiral_luma)) + cluster_knot * 0.64 * smoothstep(0.08, 0.35, spiral_luma) + bulge_glow;
		mode_glow_col = mix(mix(vec3(0.42, 0.88, 1.0), vec3(1.0, 0.64, 0.92), arm_wave2), vec3(1.0, 0.92, 0.78), clamp(bulge_glow * 2.5, 0.0, 1.0));
		halo_mask = exp(-r_disc * r_disc * 8.8);
		silhouette_mask = smoothstep(0.06, 0.35, halo_mask);
	}

	float tex_luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float max_c = max(tex.r, max(tex.g, tex.b));
	float min_c = min(tex.r, min(tex.g, tex.b));
	float chroma = max_c - min_c;

	// Disolución limpia de trazos oscuros/grises exteriores en el sprite original
	float luma_thresh = (landmark_mode == 3) ? 0.48 : 0.40;
	float luma_gate = smoothstep(0.10, luma_thresh, tex_luma + chroma * 0.42);
	float effective_tex_alpha = tex.a * mix(1.0, luma_gate, dark_edge_dissolve) * silhouette_mask;

	// Respiración armónica del núcleo galáctico
	float core_dist = dist / max(radial_fade_start, 0.001);
	float core_mask = exp(-core_dist * core_dist * 4.5);
	float twinkle = sin(t * core_pulse_speed * anim_speed) * 0.5 + sin(t * (core_pulse_speed * 1.61 * anim_speed) + 1.4) * 0.5;
	float core_sparkle = 1.0 + twinkle * core_pulse_intensity * core_mask;

	// Armonización cromática con el bioma activo y profundidad atmosférica cósmica
	vec3 harmonized_tint = mix(tint_color.rgb, mix(tint_color.rgb, biome_tint_color.rgb * 1.42, 0.72), biome_harmony_mix);
	vec3 galaxy_rad = tex.rgb * harmonized_tint * overall_brightness * core_sparkle * effective_tex_alpha;

	// Velo profundo de polvo interestelar pasando por delante del landmark (2 octavas rotadas)
	float vn1 = vnoise(p_uv * 5.2 + vec2(t * 0.015 * anim_speed, -t * 0.010 * anim_speed));
	float vn2 = vnoise(rotate2d(p_uv * 10.5, 0.75) + vec2(-t * 0.009 * anim_speed, t * 0.013 * anim_speed));
	float veil_n = vn1 * 0.65 + vn2 * 0.35;
	dust_veil_depth = mix(1.0, 0.42 + 0.58 * smoothstep(0.18, 0.85, veil_n), depth_haze_strength * 0.88);

	float halo_contrib = halo_mask * halo_glow_strength * silhouette_mask;
	vec3 halo_col = mix(biome_tint_color.rgb * 1.25, mode_glow_col, 0.52);

	vec3 add_rgb = galaxy_rad
		+ mode_glow_col * (mode_glow * silhouette_mask * max(effective_tex_alpha, halo_mask * 0.55) * 0.85)
		+ halo_col * (halo_contrib * 0.38);
	add_rgb *= dust_veil_depth;

	// Perspectiva aérea 3D según profundidad relativa del plano inclinado
	float near_boost = 1.0 - depth_rel * depth_fade_strength * 0.55;
	add_rgb *= near_boost;
	float luma_add = dot(add_rgb, vec3(0.299, 0.587, 0.114));
	float far_mix = clamp(depth_rel, 0.0, 0.55) * depth_fade_strength;
	add_rgb = mix(add_rgb, biome_tint_color.rgb * luma_add, far_mix);

	// Compresión suave de altas luces para evitar quemado blanco y proteger lectura danmaku
	add_rgb = add_rgb / (vec3(1.0) + max(add_rgb - vec3(0.70), vec3(0.0)) * 0.75);
	add_rgb *= fade * max_opacity * tint_color.a * v_modulate.a;

	if (max(add_rgb.r, max(add_rgb.g, add_rgb.b)) <= 0.002) {
		discard;
	}
	COLOR = vec4(add_rgb, 1.0);
}

