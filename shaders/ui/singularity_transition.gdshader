shader_type canvas_item;

// Transición cinemática Singularidad en 3 fases:
// phase = 0: BIG CRUNCH (colapso gravitacional de snapshot_tex a un punto blanco)
// phase = 1: SINGULARITY_HOLD (vacío negro + punto blanco vivo + partículas radiales sin texto)
// phase = 2: BIG_BANG (onda expansiva refractiva que revela la nueva escena desde el centro)

uniform sampler2D snapshot_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool has_snapshot = false;

uniform int phase = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float aspect_ratio = 1.7777;

uniform float swirl_strength : hint_range(0.0, 8.0) = 2.4;
uniform float chromatic_aberration : hint_range(0.0, 0.12) = 0.036;
uniform float singularity_core_radius : hint_range(0.004, 0.05) = 0.015;
uniform float anamorphic_flare_intensity : hint_range(0.0, 3.0) = 1.35;
uniform float shockwave_refraction : hint_range(0.0, 0.25) = 0.085;
uniform float particle_density : hint_range(0.0, 2.0) = 1.0;

uniform vec4 core_tint : source_color = vec4(0.86, 0.95, 1.0, 1.0);
uniform vec4 shockwave_tint : source_color = vec4(0.32, 0.88, 1.0, 1.0);

float _hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 _render_singularity_core(vec2 p_aspect, float pulse_scale, float flare_scale) {
	float r = length(p_aspect);
	float core_r = max(singularity_core_radius * pulse_scale, 0.003);
	float core = exp(-pow(r / core_r, 1.65)) * 2.2;
	float halo = exp(-r / (core_r * 4.6)) * 0.65;

	// Flare anamórfico horizontal + cruz estelar sutil
	float h_flare = exp(-abs(p_aspect.y) * 95.0) * exp(-abs(p_aspect.x) * 4.5) * anamorphic_flare_intensity * flare_scale;
	float v_flare = exp(-abs(p_aspect.x) * 140.0) * exp(-abs(p_aspect.y) * 14.0) * anamorphic_flare_intensity * 0.45 * flare_scale;

	return vec3(1.0) * core + core_tint.rgb * (halo + h_flare + v_flare);
}

vec3 _render_infall_particles(vec2 p_aspect, float density) {
	if (density <= 0.01) {
		return vec3(0.0);
	}
	float r = length(p_aspect);
	if (r < 0.012 || r > 0.95) {
		return vec3(0.0);
	}
	float ang = atan(p_aspect.y, p_aspect.x);
	float acc = 0.0;
	int sector_count = 28;
	float f_sectors = float(sector_count);

	// 2 capas de partículas cayendo radialmente en espiral hacia el punto blanco
	for (int layer = 0; layer < 2; layer++) {
		float l_f = float(layer);
		float twist = ang + (0.28 / max(r, 0.08)) * (0.4 + 0.3 * l_f);
		float s_idx = floor((twist / 6.2831853 + 0.5) * f_sectors);
		float s_frac = fract((twist / 6.2831853 + 0.5) * f_sectors) - 0.5;
		float rnd = _hash12(vec2(s_idx + l_f * 37.0, 11.7 + l_f * 5.3));
		float speed = 0.55 + rnd * 0.75;
		float radial_phase = fract(-r * (1.8 + l_f * 0.8) + TIME * speed + rnd);
		float mote_r = smoothstep(0.84, 0.97, radial_phase) * (1.0 - smoothstep(0.97, 1.0, radial_phase));
		float mote_a = 1.0 - smoothstep(0.0, 0.16, abs(s_frac));
		float fade_center = smoothstep(0.02, 0.14, r) * (1.0 - smoothstep(0.55, 0.95, r));
		acc += mote_r * mote_a * fade_center * (0.55 + 0.45 * rnd);
	}
	return mix(shockwave_tint.rgb, vec3(1.0), 0.55) * acc * 1.15 * density;
}

void fragment() {
	vec2 uv = UV;
	vec2 delta = uv - vec2(0.5);
	vec2 p_aspect = vec2(delta.x * aspect_ratio, delta.y);
	float r = length(p_aspect);

	if (phase == 0) {
		// BIG CRUNCH: succionar la pantalla al centro (0.5, 0.5)
		float t = clamp(progress, 0.0, 1.0);
		float ease = t * t * (3.0 - 2.0 * t);
		float inv = 1.0 - ease;

		float pull = mix(1.0, 14.0, ease * ease);
		float twist_ang = swirl_strength * ease * ease * (1.0 / (0.18 + r));
		float cs = cos(twist_ang);
		float sn = sin(twist_ang);
		vec2 rot_delta = vec2(delta.x * cs - delta.y * sn, delta.x * sn + delta.y * cs);

		// Expandir coordenadas inversas hacia fuera conforme colapsa hacia adentro
		vec2 sample_uv = vec2(0.5) + rot_delta * pull;
		vec3 scene_col = vec3(0.0);
		if (has_snapshot && sample_uv.x >= 0.0 && sample_uv.x <= 1.0 && sample_uv.y >= 0.0 && sample_uv.y <= 1.0) {
			float ab = chromatic_aberration * ease * (0.4 + r);
			vec2 dir_n = (r > 0.001) ? (delta / max(length(delta), 0.001)) : vec2(0.0);
			float cr = texture(snapshot_tex, clamp(sample_uv + dir_n * ab, vec2(0.0), vec2(1.0))).r;
			float cg = texture(snapshot_tex, sample_uv).g;
			float cb = texture(snapshot_tex, clamp(sample_uv - dir_n * ab, vec2(0.0), vec2(1.0))).b;
			scene_col = vec3(cr, cg, cb);
			// Viñeta negra gravitacional avanzando hacia el núcleo
			float horizon_r = mix(1.45, 0.01, ease);
			float horizon_mask = 1.0 - smoothstep(max(0.0, horizon_r - 0.22), horizon_r, r);
			scene_col *= horizon_mask * (0.35 + 0.65 * inv);
		}

		float core_grow = smoothstep(0.15, 1.0, ease);
		vec3 sing_col = _render_singularity_core(p_aspect, 0.55 + 0.55 * core_grow, core_grow);
		vec3 final_col = scene_col + sing_col;
		float out_a = clamp(smoothstep(0.0, 0.20, ease) + length(sing_col) * 0.5, 0.0, 1.0);
		if (!has_snapshot) {
			out_a = 1.0;
		}
		COLOR = vec4(final_col, out_a);
	} else if (phase == 1) {
		// SINGULARITY HOLD: punto blanco incandescente vivo + micro-partículas absorbidas
		float pulse = 0.90 + 0.14 * sin(TIME * 5.2) + 0.06 * sin(TIME * 13.0);
		float flare_pulse = 0.88 + 0.18 * sin(TIME * 4.1);
		vec3 sing_col = _render_singularity_core(p_aspect, pulse, flare_pulse);
		vec3 motes = _render_infall_particles(p_aspect, particle_density);
		COLOR = vec4(sing_col + motes, 1.0);
	} else {
		// BIG BANG: onda expansiva luminosa que abre el vacío negro revelando el nuevo Cosmos
		float t = clamp(progress, 0.0, 1.0);
		float ease = 1.0 - pow(1.0 - t, 2.35);
		float wave_r = mix(0.0, 1.38 * max(aspect_ratio * 0.5625, 1.0), ease);
		float ring_w = mix(0.03, 0.16, t);

		// Destello inicial del punto blanco antes de expandirse
		float flash = exp(-t * 9.5);
		vec3 init_core = _render_singularity_core(p_aspect, 1.0 + t * 2.5, 1.0 - t) * flash;

		// Máscara: dentro de wave_r es transparente (se ve el Cosmos), fuera es vacío negro
		float outside_black = smoothstep(max(0.0, wave_r - ring_w * 0.45), wave_r + ring_w * 0.15, r);
		float ring_band = exp(-pow((r - wave_r) / max(ring_w * 0.42, 0.01), 2.0)) * (1.0 - smoothstep(0.75, 1.0, t));

		// Aberración cromática sutil en la cresta de la onda de choque
		float ca_band_r = exp(-pow((r - (wave_r + shockwave_refraction * 0.35)) / max(ring_w * 0.35, 0.01), 2.0));
		float ca_band_b = exp(-pow((r - (wave_r - shockwave_refraction * 0.35)) / max(ring_w * 0.35, 0.01), 2.0));
		vec3 wave_col = shockwave_tint.rgb * ring_band * 1.45
			+ vec3(1.0, 0.85, 0.55) * ca_band_r * 0.45 * (1.0 - t)
			+ vec3(0.35, 0.90, 1.0) * ca_band_b * 0.55 * (1.0 - t)
			+ vec3(1.0) * ring_band * 0.65;

		vec3 final_col = init_core + wave_col;
		float out_a = clamp(max(outside_black * (1.0 - smoothstep(0.86, 1.0, t)), clamp(length(final_col) * 0.85, 0.0, 1.0)), 0.0, 1.0);
		COLOR = vec4(final_col, out_a);
	}
}
