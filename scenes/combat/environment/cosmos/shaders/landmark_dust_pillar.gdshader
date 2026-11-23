shader_type canvas_item;
render_mode blend_mix, unshaded;

/**
 * landmark_dust_pillar.gdshader (v3.3)
 *
 * Renderizador atmosférico para Pilares de Polvo Cósmico (Pillars of Creation):
 * - Usa v_modulate desde vertex() en lugar de `* COLOR` para evitar multiplicar por el sprite estático.
 * - Advección gaseosa ascendente dual-phase en el eje real del pilar (-72.85 deg).
 * - Disolución del contorno negro exterior mediante muestreo de 4 vecinos + suavizado de base.
 * - Perspectiva aérea de bioma + protoestrellas nacientes en las crestas fotoionizadas.
 */

uniform float overall_brightness : hint_range(0.1, 2.5) = 1.02;
uniform vec4 tint_color : source_color = vec4(0.95, 0.92, 1.0, 1.0);
uniform vec4 biome_tint_color : source_color = vec4(0.24, 0.45, 0.85, 1.0);
uniform float biome_harmony_mix : hint_range(0.0, 0.85) = 0.52;
uniform float rim_pulse_strength : hint_range(0.0, 0.8) = 0.36;
uniform float radial_fade_start : hint_range(0.1, 0.5) = 0.40;
uniform float radial_fade_end : hint_range(0.2, 0.6) = 0.495;
uniform float global_time = 0.0;
uniform float global_time_override = -1.0;
uniform float phase_offset = 0.0;
uniform float anim_speed : hint_range(0.0, 4.0) = 1.0;
uniform float tilt_x : hint_range(-1.15, 1.15) = 0.0;
uniform float tilt_y : hint_range(-1.15, 1.15) = 0.0;
uniform float perspective_fov : hint_range(0.0, 1.1) = 0.56;
uniform float depth_fade_strength : hint_range(0.0, 0.6) = 0.34;

varying vec4 v_modulate;

float protostar_dot(vec2 uv, vec2 pos, float t, float freq, float phase) {
	float d = length(uv - pos);
	float tw = 0.62 + 0.38 * sin(t * freq + phase);
	float pin = exp(-d * d * 2400.0);
	float cross_glint = (exp(-abs(uv.y - pos.y) * 260.0) * exp(-abs(uv.x - pos.x) * 48.0)
		+ exp(-abs(uv.x - pos.x) * 260.0) * exp(-abs(uv.y - pos.y) * 48.0)) * 0.55;
	return (pin + cross_glint) * tw;
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
	vec2 delta = p_uv - vec2(0.5);
	float dist = length(delta);
	float fade = 1.0 - smoothstep(radial_fade_start, radial_fade_end, dist);
	if (fade <= 0.01 || v_modulate.a <= 0.001) {
		discard;
	}

	// Eje real medido en landmark_dust_pillars.png (~ -72.85 deg apuntando arriba-derecha)
	const vec2 PILLAR_AXIS = vec2(0.2949, -0.9555);
	const vec2 PILLAR_PERP = vec2(0.9555, 0.2949);
	float along = dot(delta, PILLAR_AXIS);
	float across = dot(delta, PILLAR_PERP);

	// Disolver suavemente el borde inferior recortado para fundir la base con la nebulosa
	float base_fade = smoothstep(-0.42, -0.14, along);

	// Deriva gaseosa ascendente dual-phase (evaporación fotoionizada continua sin saltos)
	float evap_env = smoothstep(-0.26, 0.22, along) * smoothstep(0.05, 0.20, dist);
	float flow_rate = 0.085 * anim_speed;
	float p0 = fract(t * flow_rate);
	float p1 = fract(p0 + 0.5);
	float w_blend = abs(2.0 * p0 - 1.0);

	float lateral_wave = sin(along * 16.0 - t * 0.85 * anim_speed) * 0.0045
		+ cos(across * 14.0 + t * 0.62 * anim_speed) * 0.0035;
	vec2 adv_vec = PILLAR_AXIS * (0.026 * evap_env) + PILLAR_PERP * (lateral_wave * evap_env);
	vec2 uv0 = clamp(p_uv - adv_vec * (p0 - 0.5), vec2(0.001), vec2(0.999));
	vec2 uv1 = clamp(p_uv - adv_vec * (p1 - 0.5), vec2(0.001), vec2(0.999));
	vec4 tex = mix(texture(TEXTURE, uv0), texture(TEXTURE, uv1), w_blend);

	// Filtro fino de 4 vecinos (~3.5px) solo en el perímetro exterior para quitar el borde negro de recorte
	const float EDGE_STEP = 0.0035;
	vec2 uv_mid = clamp(mix(uv0, uv1, w_blend), vec2(0.006), vec2(0.994));
	float a1 = texture(TEXTURE, uv_mid + vec2(EDGE_STEP, 0.0)).a;
	float a2 = texture(TEXTURE, uv_mid - vec2(EDGE_STEP, 0.0)).a;
	float a3 = texture(TEXTURE, uv_mid + vec2(0.0, EDGE_STEP)).a;
	float a4 = texture(TEXTURE, uv_mid - vec2(0.0, EDGE_STEP)).a;
	float neighbor_min_a = min(min(a1, a2), min(a3, a4));

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float max_c = max(tex.r, max(tex.g, tex.b));
	float min_c = min(tex.r, min(tex.g, tex.b));
	float chroma = max_c - min_c;

	// Solo disolver el reborde negro mate pegado al alpha=0 exterior sin vaciar las columnas interiores
	float rim_or_glow = smoothstep(0.10, 0.28, luma + chroma * 0.35);
	float is_outer_rim = smoothstep(0.15, 0.85, neighbor_min_a);
	float border_mask = mix(rim_or_glow, 1.0, is_outer_rim);

	float alpha = tex.a * border_mask * fade * base_fade * tint_color.a;
	if (alpha <= 0.01) {
		discard;
	}

	float rim_mask = smoothstep(0.24, 0.75, luma);
	float shimmer = 1.0 + sin(t * 1.65 * anim_speed + along * 20.0 - across * 12.0) * 0.54 * max(rim_pulse_strength, 0.36) * rim_mask;
	float gas_pulse = 0.5 + 0.5 * sin(along * 12.0 - t * 1.15 * anim_speed + across * 9.0);

	// Profundidad atmosférica armonizada con el bioma: disuelve pilares oscuros en el gas del bioma
	vec3 shadow_scatter = biome_tint_color.rgb * mix(0.42, 0.32, biome_harmony_mix) + vec3(0.018, 0.024, 0.045);
	vec3 lifted = max(tex.rgb * mix(vec3(1.12), biome_tint_color.rgb * 0.90 + vec3(0.48), (1.0 - rim_mask) * biome_harmony_mix * 0.62), shadow_scatter);
	float outer_veil = (1.0 - smoothstep(0.25, 0.90, neighbor_min_a)) * 0.30;
	vec3 veiled = mix(
		lifted * tint_color.rgb,
		biome_tint_color.rgb * 0.48 + lifted * 0.56,
		clamp(biome_harmony_mix * 0.92 + outer_veil, 0.0, 0.78) * (1.0 - rim_mask * 0.65)
	);
	veiled += biome_tint_color.rgb * (gas_pulse * smoothstep(0.14, 0.55, tex.a) * (1.0 - rim_mask) * 0.055);
	float veil_p = smoothstep(0.18, 0.82, 0.5 + 0.28 * sin(along * 8.5 + across * 5.2 - t * 0.42 * anim_speed) + 0.22 * cos(across * 11.0 - along * 6.5 + t * 0.31 * anim_speed));
	veiled = mix(veiled, biome_tint_color.rgb * 0.36, veil_p * clamp(biome_harmony_mix * 0.45, 0.12, 0.36));

	// 4 protoestrellas nacientes centelleando suavemente dentro de las cabezas de los pilares
	float inner_gate = smoothstep(0.42, 0.82, tex.a) * smoothstep(0.35, 0.85, neighbor_min_a);
	float proto = (
		protostar_dot(uv_mid, vec2(0.67, 0.16), t * anim_speed, 2.1, 0.4)
		+ protostar_dot(uv_mid, vec2(0.76, 0.36), t * anim_speed, 2.7, 2.1)
		+ protostar_dot(uv_mid, vec2(0.52, 0.38), t * anim_speed, 1.8, 3.9)
		+ protostar_dot(uv_mid, vec2(0.76, 0.54), t * anim_speed, 2.4, 5.2)
	) * inner_gate;
	vec3 proto_col = mix(vec3(0.65, 0.94, 1.0), vec3(1.0, 0.90, 0.74), 0.55);

	float near_boost = 1.0 - depth_rel * depth_fade_strength * 0.45;
	float far_mix = clamp(depth_rel, 0.0, 0.55) * depth_fade_strength;
	veiled = mix(veiled * near_boost, biome_tint_color.rgb * 0.35, far_mix);

	veiled = veiled / (vec3(1.0) + max(veiled - vec3(0.82), vec3(0.0)) * 0.50);
	vec3 final_rgb = veiled * min(overall_brightness, 1.12) * shimmer + proto_col * (proto * 0.85);

	float final_alpha = clamp(alpha * 0.66, 0.0, 0.68) * v_modulate.a;
	COLOR = vec4(final_rgb, final_alpha);
}

