// Módulo de iluminación estilizada, normales cilíndricas RNM, sombras analíticas ILM,
// cuñas Mignola, Open Anime Ink, SSS cálido, Nylon Fresnel y SDF de cabeza.

float compute_halftone_pattern(vec2 frag_coord, float scale, int pat_type, float angle_deg) {
	float rad = radians(angle_deg);
	float c = cos(rad);
	float s = sin(rad);
	vec2 rot_uv = vec2(
		frag_coord.x * c - frag_coord.y * s,
		frag_coord.x * s + frag_coord.y * c
	) / (1080.0 / max(scale, 10.0));

	if (pat_type == 0) {
		vec2 cell = fract(rot_uv) - vec2(0.5);
		return 1.0 - smoothstep(0.28, 0.38, length(cell));
	} else if (pat_type == 1) {
		float wave = abs(fract(rot_uv.x * 1.15) - 0.5);
		return 1.0 - smoothstep(0.17, 0.27, wave);
	} else if (pat_type == 2) {
		vec2 cell = abs(fract(rot_uv) - vec2(0.5));
		float line_a = 1.0 - smoothstep(0.14, 0.22, cell.x);
		float line_b = 1.0 - smoothstep(0.14, 0.22, cell.y);
		return max(line_a, line_b);
	} else if (pat_type == 3) {
		vec2 grid = rot_uv * 1.35;
		grid.x += 0.5 * step(0.5, fract(grid.y * 0.5));
		vec2 cell = fract(grid) - vec2(0.5);
		return 1.0 - smoothstep(0.24, 0.34, length(cell));
	} else if (pat_type == 4) {
		vec2 q = vec2(rot_uv.x * 1.1547, rot_uv.y + rot_uv.x * 0.57735);
		vec2 cell = abs(fract(q) - vec2(0.5));
		float hex_d = max(cell.x, cell.y);
		return smoothstep(0.32, 0.44, hex_d);
	} else {
		float scan = abs(fract(frag_coord.y / (1080.0 / max(scale, 20.0))) - 0.5);
		return 1.0 - smoothstep(0.16, 0.28, scan);
	}
}

// Reoriented Normal Mapping (RNM)
vec3 blend_rnm(vec3 n1, vec3 n2) {
	n1 += vec3(0.0, 0.0, 1.0);
	n2 *= vec3(-1.0, -1.0, 1.0);
	return normalize(n1 * dot(n1, n2) / max(n1.z, 0.0001) - n2);
}

// SDF de cápsula 2D en espacio rig
float sd_capsule_2d(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

// SDF de elipse aproximada para proyección de cabeza
float sd_ellipse_approx(vec2 p, vec2 c, vec2 r) {
	vec2 d = (p - c) / max(r, vec2(0.0001));
	return (length(d) - 1.0) * min(r.x, r.y);
}

// Portador cilíndrico transversal (Ny = 0) + soldadura de costura + RNM + rotación por bone_chain_angles
vec3 compute_cylindrical_rnm_normal(
	vec2 uv,
	vec3 n_tex_raw,
	float cyl_roundness,
	bool weld_top,
	bool weld_bottom,
	vec2 chain_angles,
	float flip_x
) {
	float seam_env = 1.0;
	if (weld_top) {
		seam_env *= smoothstep(0.0, 0.20, uv.y);
	}
	if (weld_bottom) {
		seam_env *= smoothstep(1.0, 0.80, uv.y);
	}
	float xc = (uv.x * 2.0 - 1.0) * cyl_roundness * seam_env;
	vec3 n_cyl = normalize(vec3(xc, 0.0, sqrt(max(1.0 - xc * xc, 0.06))));

	vec3 n_tex = n_tex_raw * 2.0 - vec3(1.0);
	n_tex.x *= flip_x;
	n_tex.y *= seam_env;
	n_tex = normalize(mix(vec3(0.0, 0.0, 1.0), n_tex, 0.35 + 0.65 * seam_env));

	vec3 n_local = blend_rnm(n_cyl, n_tex);
	float bone_angle = mix(chain_angles.x, chain_angles.y, smoothstep(0.35, 0.65, uv.y));
	float ca = cos(bone_angle);
	float sa = sin(bone_angle);
	vec2 rot_xy = mat2(vec2(ca, sa), vec2(-sa, ca)) * n_local.xy;
	return normalize(vec3(rot_xy, n_local.z));
}

// Filtrado SDF analítico de cabeza libre de escalones de 8 bits (Motomura zoom curve)
// heads/*_outline_sdf.png almacena distancia exterior sin signo: dist_px / 32.0 (0.0 dentro, >0.0 fuera)
float compute_head_sdf_ink(
	sampler2D sdf_tex,
	vec2 uv,
	float base_alpha,
	float px_in_tex,
	float pad_px,
	float base_width_px,
	float z_scale
) {
	if (base_alpha >= 0.92) {
		return 0.0;
	}
	float dist_tex = textureLod(sdf_tex, uv, 0.0).r * max(pad_px, 1.0);
	float dist_scr = dist_tex / max(px_in_tex, 0.25);
	float z_clamped = clamp(z_scale, 0.5, 3.0);
	float target_px = clamp(1.45 * pow(z_clamped, 0.60) * (base_width_px / 4.0), 1.15, 3.6);
	return 1.0 - smoothstep(max(target_px - 0.85, 0.0), target_px + 0.85, dist_scr);
}
