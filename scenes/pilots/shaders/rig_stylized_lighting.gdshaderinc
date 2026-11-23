// Módulo de iluminación estilizada, normales cilíndricas RNM, sombras analíticas ILM,
// sombreado perceptual ArcSys, cuñas Mignola y SDF de cabeza.

// Sombra perceptual ArcSys en espacio sRGB: evita aplastar el traje oscuro a negro
// mientras da un hue-shift frío rico (o cálido en piel) y compensa sombra pre-horneada.
vec3 compute_arcsys_shadow_srgb(vec3 base_srgb, vec3 tint_srgb, float de_shade, float orig_luma, bool is_skin) {
	float not_ink = smoothstep(0.08, 0.20, orig_luma);
	vec3 comp = mix(base_srgb, pow(max(base_srgb, vec3(0.001)), vec3(0.76)), de_shade * not_ink);
	float max_c = max(max(tint_srgb.r, tint_srgb.g), max(tint_srgb.b, 0.001));
	vec3 tint_chroma = tint_srgb / max_c;
	if (is_skin) {
		vec3 skin_mul = mix(tint_srgb, tint_chroma * 0.88, 0.35);
		return clamp(comp * skin_mul + tint_srgb * 0.06 * not_ink, vec3(0.0), vec3(1.0));
	}
	vec3 mul_col = mix(tint_srgb, tint_chroma * 0.72, 0.65);
	return clamp(comp * mul_col + tint_srgb * 0.14 * not_ink, vec3(0.0), vec3(1.0));
}

// Color grading cinematográfico suave en espacio sRGB (contraste S + vibrancia rec.709).
vec3 apply_cinematic_grade_srgb(vec3 srgb, float contrast, float sat) {
	vec3 c = clamp((srgb - vec3(0.5)) * contrast + vec3(0.5), vec3(0.0), vec3(1.0));
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	return clamp(mix(vec3(l), c, sat), vec3(0.0), vec3(1.0));
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
	n_tex.y = -n_tex.y * seam_env;
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
