shader_type canvas_item;
render_mode blend_add, unshaded;

// star_light_field.gdshader
// Proyecta el bioma estelar y la luz ambiental del sol en todo su dominio orbital y más allá.
// Incluye oclusión analítica de rayos solares ("catedral de luz"), aura etérea de heliopausa
// (bow-shock por firma estelar) y arcos de compás orbital diegéticos sutiles.

uniform vec4 light_color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float intensity : hint_range(0.0, 3.5) = 1.0;
uniform float core_cutoff_radius : hint_range(0.0, 0.2) = 0.04;
uniform float falloff_exponent : hint_range(0.5, 4.0) = 1.1;
uniform float pulse_speed : hint_range(0.1, 3.0) = 0.8;
uniform float heliosphere_noise_strength : hint_range(0.0, 1.0) = 0.45;
uniform float heliosphere_edge_feather : hint_range(0.02, 0.5) = 0.25;
uniform float noise_scale : hint_range(1.0, 30.0) = 6.0;
uniform float heliosphere_ring_strength : hint_range(0.0, 0.6) = 0.14;
uniform float god_rays_strength : hint_range(0.0, 1.0) = 0.28;

uniform int occluder_count : hint_range(0, 8) = 0;
uniform vec4 occluders[8];

uniform int star_signature_mode : hint_range(0, 4) = 0;
uniform vec4 domain_accent_color : source_color = vec4(1.0, 0.88, 0.55, 1.0);
uniform float heliopause_aura_strength : hint_range(0.0, 1.0) = 0.56;
uniform float astro_compass_strength : hint_range(0.0, 0.5) = 0.22;
uniform float ecliptic_tilt_rad = 0.0;
uniform float ecliptic_squash : hint_range(0.5, 1.0) = 1.0;
uniform float global_time = 0.0;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float gradient_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
		    dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
		mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
		    dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm_heliosphere(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 3; i++) {
		val += amp * (gradient_noise(p) * 0.5 + 0.5);
		p = rot * p * 2.02;
		amp *= 0.5;
	}
	return val;
}

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 d = UV - center;
	float dist = length(d);
	float norm_r = dist * 2.0;

	if (norm_r >= 1.0) {
		discard;
	}

	float t = (global_time > 0.001) ? global_time : TIME;

	float falloff = pow(1.0 - norm_r, falloff_exponent);
	float feather_span = max(heliosphere_edge_feather, 0.28);
	float edge_fade = pow(smoothstep(1.0, 1.0 - feather_span, norm_r), 1.35);

	vec2 noise_coords = (d * noise_scale) + vec2(sin(t * 0.05), cos(t * 0.04)) * 0.2;
	float gas = fbm_heliosphere(noise_coords);
	float gas_factor = mix(1.0, gas * 1.5, heliosphere_noise_strength);

	float pulse = 1.0 + sin(t * pulse_speed) * 0.04;
	float wave_ring = 1.0 + sin(norm_r * 18.0 - t * pulse_speed * 0.8) * 0.5 * heliosphere_ring_strength * smoothstep(0.25, 0.85, norm_r);

	float theta = atan(d.y, d.x);
	float ray_a = pow(0.5 + 0.5 * sin(theta * 9.0 + t * 0.09), 3.0);
	float ray_b = pow(0.5 + 0.5 * cos(theta * 15.0 - t * 0.06 + 1.2), 4.0);
	float ray_mask = (ray_a * 0.62 + ray_b * 0.38) * smoothstep(0.04, 0.22, norm_r) * (1.0 - smoothstep(0.58, 0.94, norm_r));
	float god_rays = 1.0 + ray_mask * god_rays_strength * 2.2;

	// Oclusión de rayos por planetas ("catedral de luz") + arcos orbitales diegéticos tenues en perspectiva eclíptica
	float ray_occlusion = 0.0;
	float shaft_boost = 0.0;
	float orbital_arcs = 0.0;
	vec2 d_unit = (dist > 0.0001) ? (d / dist) : vec2(1.0, 0.0);
	float ec_c = cos(ecliptic_tilt_rad);
	float ec_s = sin(ecliptic_tilt_rad);
	float ec_sq = clamp(ecliptic_squash, 0.5, 1.0);
	vec2 d_ec = vec2(d.x * ec_c + d.y * ec_s, (-d.x * ec_s + d.y * ec_c) / ec_sq);
	float norm_r_ec = length(d_ec) * 2.0;
	for (int i = 0; i < 8; i++) {
		if (i >= occluder_count) {
			break;
		}
		vec2 p_pos = occluders[i].xy;
		float p_rad = occluders[i].z;
		float p_dist = length(p_pos);
		if (p_dist > 0.001 && p_rad > 0.0005) {
			vec2 p_dir = p_pos / p_dist;
			float proj = dot(d, p_dir);
			if (proj > p_dist - p_rad * 0.35) {
				float perp = length(d - p_dir * proj);
				float cone_r = p_rad * (proj / max(p_dist, 0.001));
				float behind = smoothstep(p_dist - p_rad * 0.25, p_dist + p_rad * 0.35, proj);
				float occ = (1.0 - smoothstep(cone_r * 0.75, cone_r * 1.28, perp)) * behind;
				ray_occlusion = max(ray_occlusion, occ);
				float shaft = smoothstep(cone_r * 0.88, cone_r * 1.08, perp) * (1.0 - smoothstep(cone_r * 1.08, cone_r * 1.52, perp)) * behind;
				shaft_boost = max(shaft_boost, shaft);
			}
			if (astro_compass_strength > 0.005) {
				vec2 p_ec = vec2(p_pos.x * ec_c + p_pos.y * ec_s, (-p_pos.x * ec_s + p_pos.y * ec_c) / ec_sq);
				float p_orb_r = length(p_ec) * 2.0;
				float arc_line = exp(-pow((norm_r_ec - p_orb_r) / 0.0042, 2.0));
				float ang_mask = smoothstep(0.91, 0.995, dot(d_unit, p_dir));
				float planet_hole = smoothstep(p_rad * 1.25, p_rad * 1.80, length(d - p_pos));
				orbital_arcs = max(orbital_arcs, arc_line * ang_mask * planet_hole);
			}
		}
	}

	float combined_mask = falloff * edge_fade * gas_factor * pulse * wave_ring * god_rays;
	combined_mask *= (1.0 - ray_occlusion * 0.72);
	combined_mask += falloff * edge_fade * shaft_boost * god_rays_strength * 0.48;

	// Frontera etérea de Heliopausa / Bow-Shock + Aura Interna de Dominio con identidad por estrella
	float bow_wobble = 0.014 * sin(theta * 3.0 + t * 0.14) + 0.008 * cos(theta * 7.0 - t * 0.21) + (gas - 0.5) * 0.032;
	float r_bow = norm_r + bow_wobble;
	float outer_env = smoothstep(0.992, 0.925, norm_r) * edge_fade;
	float bow_ring = exp(-pow((r_bow - 0.88) / 0.036, 2.0));
	float inner_curtain = smoothstep(0.74, 0.88, r_bow) * (1.0 - smoothstep(0.89, 0.97, r_bow)) * 0.30;

	float r_inner = norm_r + bow_wobble * 0.55;
	float inner_ring = exp(-pow((r_inner - 0.27) / 0.040, 2.0));
	float inner_halo = smoothstep(0.16, 0.26, r_inner) * (1.0 - smoothstep(0.28, 0.38, r_inner)) * 0.24;

	float sig_wave = 0.85 + 0.15 * sin(r_bow * 28.0 - t * 0.65);
	float inner_sig = 0.85 + 0.15 * sin(theta * 3.0 - t * 0.45);
	if (star_signature_mode == 1) {
		sig_wave = 0.75 + 0.35 * pow(0.5 + 0.5 * sin(r_bow * 54.0 - t * 1.4), 2.0);
		inner_sig = 0.72 + 0.36 * pow(0.5 + 0.5 * cos(r_inner * 62.0 - t * 1.6), 2.0);
	} else if (star_signature_mode == 2) {
		sig_wave = 0.90 + 0.25 * exp(-pow((r_bow - 0.885) / 0.014, 2.0));
		inner_sig = 0.90 + 0.24 * exp(-pow((r_inner - 0.27) / 0.014, 2.0));
	} else if (star_signature_mode == 3) {
		bow_ring = exp(-pow((r_bow - 0.86) / 0.030, 2.0));
		sig_wave = 0.72 + 0.28 * sin(theta * 4.0 + r_bow * 22.0 + t * 0.55);
		inner_sig = 0.70 + 0.32 * sin(theta * 3.0 - r_inner * 24.0 + t * 0.85);
	} else if (star_signature_mode == 4) {
		sig_wave = 0.78 + 0.32 * pow(0.5 + 0.5 * sin(r_bow * 36.0 - t * 1.05 + theta * 2.0), 2.0);
		inner_sig = 0.78 + 0.30 * pow(0.5 + 0.5 * sin(r_inner * 40.0 - t * 1.2 + theta * 4.0), 2.0);
	}

	float heliopause_aura = (bow_ring + inner_curtain) * outer_env * sig_wave * heliopause_aura_strength * (1.0 - ray_occlusion * 0.42);
	float inner_domain_aura = (inner_ring + inner_halo) * inner_sig * heliopause_aura_strength * (1.0 - ray_occlusion * 0.44);
	float outer_dash = exp(-pow((norm_r - 0.88) / 0.0036, 2.0)) * smoothstep(0.15, 0.65, sin(theta * 24.0 + t * 0.04)) * 0.55 * outer_env;
	float compass_mask = clamp(max(outer_dash, orbital_arcs * edge_fade), 0.0, 1.0) * astro_compass_strength * (1.0 - ray_occlusion * 0.35);

	vec3 base_rgb = light_color.rgb * (intensity * combined_mask);
	vec3 domain_rgb = mix(light_color.rgb, domain_accent_color.rgb, 0.48) * ((heliopause_aura * 0.62 + inner_domain_aura * 0.44 + compass_mask) * max(intensity, 0.65));
	vec3 final_color = base_rgb + domain_rgb;
	float final_alpha = clamp((combined_mask + heliopause_aura * 0.50 + inner_domain_aura * 0.35 + compass_mask) * intensity * light_color.a, 0.0, 1.0);

	COLOR = vec4(final_color, final_alpha);
}
