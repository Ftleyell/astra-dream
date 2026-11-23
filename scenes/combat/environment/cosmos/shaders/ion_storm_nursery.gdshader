shader_type canvas_item;
render_mode blend_add, unshaded;

/**
 * ion_storm_nursery.gdshader
 * Vivero Protoestelar & Tormenta Iónica en estrato medio (Cosmos Engine v3.2).
 * Bolsa nebular FBM vibrante con crestas de ionización, capullos cálidos de protoestrellas
 * y relámpagos cósmicos ramificados visibles sin cortes cuadrados.
 */

uniform float global_time = -1.0;
uniform float seed_phase : hint_range(0.0, 6.2832) = 0.0;
uniform int quality_level : hint_range(0, 2) = 2;

uniform vec4 primary_color : source_color = vec4(0.26, 0.72, 1.0, 1.0);
uniform vec4 protostar_color : source_color = vec4(1.0, 0.76, 0.42, 1.0);
uniform vec4 arc_color : source_color = vec4(0.68, 0.92, 1.0, 1.0);
uniform vec4 biome_tint_color : source_color = vec4(0.18, 0.28, 0.55, 1.0);

uniform int protostar_count : hint_range(1, 3) = 2;
uniform vec2 protostar_pos_0 = vec2(-0.09, -0.05);
uniform vec2 protostar_pos_1 = vec2(0.11, 0.06);
uniform vec2 protostar_pos_2 = vec2(-0.02, 0.12);
uniform float lightning_intensity : hint_range(0.0, 2.5) = 1.35;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 41.9);
	return fract(p.x * p.y);
}

float vnoise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm_cloud(vec2 uv, int octaves) {
	float val = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	for (int i = 0; i < 4; i++) {
		if (i >= octaves) {
			break;
		}
		val += vnoise(uv) * amp;
		uv = rot * (uv * 2.03) + vec2(17.1, 31.7);
		amp *= 0.5;
	}
	return val;
}

float eval_protostar(vec2 p, vec2 center, float t, float phase) {
	vec2 d = p - center;
	float dist = length(d);
	if (dist > 0.28) {
		return 0.0;
	}
	float breathe = 0.88 + 0.12 * sin(t * 2.1 + phase);
	float core = exp(-dist * 46.0) * 1.55;
	float halo = exp(-dist * 12.5) * 0.58;
	float flare_h = exp(-abs(d.y) * 90.0) * exp(-abs(d.x) * 14.0);
	float flare_v = exp(-abs(d.x) * 90.0) * exp(-abs(d.y) * 14.0);
	return (core + halo + (flare_h + flare_v) * 0.62) * breathe;
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	if (r >= 0.495) {
		discard;
	}

	float t = (global_time >= 0.0) ? global_time : TIME;
	int octs = (quality_level >= 2) ? 4 : ((quality_level == 1) ? 3 : 2);

	vec2 q_uv = p * 5.0 + vec2(seed_phase * 1.3, -seed_phase * 0.9);
	float warp_x = vnoise(q_uv + vec2(t * 0.025, 0.0)) - 0.5;
	float warp_y = vnoise(q_uv + vec2(5.2, 1.3 - t * 0.02)) - 0.5;
	float cloud = fbm_cloud(q_uv + vec2(warp_x, warp_y) * 1.35 + vec2(t * 0.018, -t * 0.012), octs);
	float cloud_b = fbm_cloud(q_uv * 1.45 - vec2(warp_y, warp_x) * 1.15 - vec2(t * 0.014, t * 0.01), max(octs - 1, 2));

	float organic_r = r + (cloud - 0.5) * 0.14;
	float nebula_env = (1.0 - smoothstep(0.18, 0.44, organic_r)) * (1.0 - smoothstep(0.39, 0.488, r));

	// Filamentos de gas iónico + cresta de ionización estilo anime
	float filament = smoothstep(0.22, 0.80, cloud);
	float ion_ridge = smoothstep(0.06, 0.24, abs(cloud - cloud_b)) * filament;
	vec3 gas_col = mix(biome_tint_color.rgb, primary_color.rgb, 0.72);
	vec3 col = gas_col * (filament * nebula_env * 1.18) + arc_color.rgb * (ion_ridge * nebula_env * 0.65);

	// 2-3 Protoestrellas cálidas embebidas + scattering local dentro del gas
	float proto_total = eval_protostar(p, protostar_pos_0, t, seed_phase);
	float warm_scatter = exp(-length(p - protostar_pos_0) * 5.0);
	if (protostar_count >= 2) {
		proto_total += eval_protostar(p, protostar_pos_1, t, seed_phase + 2.1);
		warm_scatter += exp(-length(p - protostar_pos_1) * 5.0);
	}
	if (protostar_count >= 3) {
		proto_total += eval_protostar(p, protostar_pos_2, t, seed_phase + 4.3);
		warm_scatter += exp(-length(p - protostar_pos_2) * 5.0);
	}

	col += protostar_color.rgb * (warm_scatter * (0.35 + 0.80 * filament) * nebula_env * 0.64);
	col += mix(protostar_color.rgb, vec3(1.0, 0.97, 0.90), 0.55) * (proto_total * (1.0 - smoothstep(0.36, 0.488, r)));

	// 3 canales de relámpagos cósmicos en fase escalonada para actividad eléctrica continua
	if (lightning_intensity > 0.01) {
		float bolt_sum = 0.0;
		float hard_guard = 1.0 - smoothstep(0.34, 0.488, r);
		for (int b = 0; b < 3; b++) {
			float fb = float(b);
			float flash = pow(0.5 + 0.5 * sin(t * (1.8 + fb * 0.65) + seed_phase + fb * 2.09439), 4.0);
			vec2 b_uv = vec2(p.x * 0.82 + p.y * (0.57 - fb * 0.9), p.y * 0.82 - p.x * (0.57 + fb * 0.65)) * 7.2 + vec2(fb * 4.7, -fb * 3.1);
			float ridge = abs(vnoise(b_uv + vec2(t * 2.2, fb * 11.0)) - 0.5);
			float core_bolt = exp(-ridge * 46.0);
			float halo_bolt = exp(-ridge * 14.0) * 0.35;
			float gas_gate = smoothstep(0.24, 0.72, cloud);
			bolt_sum += (core_bolt + halo_bolt) * gas_gate * (0.24 + 0.76 * flash);
		}
		col += mix(arc_color.rgb, vec3(0.95, 0.99, 1.0), 0.50) * (bolt_sum * hard_guard * lightning_intensity * 0.88);
	}

	float alpha = clamp(max(col.r, max(col.g, col.b)), 0.0, 1.0);
	COLOR = vec4(col, alpha);
}
