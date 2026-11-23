shader_type canvas_item;
// Shader de proyección elíptica 2.5D para Anillo Orbital con Textura IA Empaquetada.
// Canales de entrada en TEXTURE:
//   R = estructura plata/armadura
//   G = sectores y cheurones energéticos
//   B = máscara radial (1.0 = aro exterior blindado, 0.0 = aro interior contrarrotativo)
//   A = recorte de fondo limpio

uniform bool is_front_half = true;
uniform bool over_hug_pass = false;
uniform float main_rail_uv_radius = 0.3827;
uniform float outer_rot_rad = 0.0;
uniform float inner_rot_rad = 0.0;

uniform vec4 ring_primary_color : source_color = vec4(0.84, 0.90, 0.98, 0.90);
uniform vec4 ring_accent_color : source_color = vec4(0.95, 0.18, 0.36, 0.98);
uniform float alpha_mult : hint_range(0.0, 1.5) = 0.96;
uniform float energy_hdr_boost : hint_range(0.5, 3.0) = 1.48;

uniform int slot_count = 1;
uniform vec4 slot_angles = vec4(0.0);
uniform vec4 slot_pulses = vec4(0.0);

vec2 rotate_uv(vec2 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

void eval_slot_influence(
	vec2 p,
	float px_angle,
	float slot_angle,
	float slot_pulse,
	inout float prox,
	inout float fire_b,
	inout float over_w
) {
	float diff = abs(mod(px_angle - slot_angle + 3.14159265, 6.2831853) - 3.14159265);
	float local_w = exp(-pow(diff / 0.32, 2.0));
	prox = max(prox, local_w);
	float pulse_w = exp(-pow(diff / (0.28 + slot_pulse * 0.45), 2.0)) * slot_pulse;
	fire_b = max(fire_b, pulse_w);

	// Encastre vertical por profundidad real: abraza la mitad inferior/cercana del arma
	float ang_hug = 1.0 - smoothstep(0.18, 0.36, diff);
	float slot_py = sin(slot_angle) * main_rail_uv_radius;
	float lower_w = smoothstep(0.002, 0.020, p.y - slot_py);
	over_w = max(over_w, ang_hug * lower_w);
}

vec4 sample_clamped(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, uv);
}

void fragment() {
	if (is_front_half && UV.y < 0.5) {
		discard;
	}
	if (!is_front_half && UV.y >= 0.5) {
		discard;
	}

	vec2 p = UV - vec2(0.5);
	vec2 uv_out = vec2(0.5) + rotate_uv(p, outer_rot_rad);
	vec2 uv_in = vec2(0.5) + rotate_uv(p, inner_rot_rad);

	vec4 s_out = sample_clamped(TEXTURE, uv_out);
	vec4 s_in = sample_clamped(TEXTURE, uv_in);

	float out_zone = smoothstep(0.42, 0.58, s_out.b);
	float in_zone = 1.0 - smoothstep(0.42, 0.58, s_in.b);

	float struct_m = max(s_out.r * out_zone, s_in.r * in_zone);
	float energy_m = max(s_out.g * out_zone, s_in.g * in_zone);
	float alpha_m = max(s_out.a * out_zone, s_in.a * in_zone);

	if (alpha_m < 0.015) {
		discard;
	}

	float px_angle = atan(p.y, p.x);
	float prox = 0.0;
	float fire_b = 0.0;
	float over_w = 0.0;
	if (slot_count > 0) {
		eval_slot_influence(p, px_angle, slot_angles.x, slot_pulses.x, prox, fire_b, over_w);
	}
	if (slot_count > 1) {
		eval_slot_influence(p, px_angle, slot_angles.y, slot_pulses.y, prox, fire_b, over_w);
	}
	if (slot_count > 2) {
		eval_slot_influence(p, px_angle, slot_angles.z, slot_pulses.z, prox, fire_b, over_w);
	}
	if (slot_count > 3) {
		eval_slot_influence(p, px_angle, slot_angles.w, slot_pulses.w, prox, fire_b, over_w);
	}

	if (over_hug_pass && over_w < 0.01) {
		discard;
	}

	vec3 struct_col = ring_primary_color.rgb * (1.02 + prox * 0.32 + fire_b * 0.35);
	vec3 energy_col = ring_accent_color.rgb * (energy_hdr_boost + prox * 0.72 + fire_b * 1.45);

	float total_w = max(struct_m + energy_m, 0.001);
	vec3 rgb = (struct_col * struct_m + energy_col * energy_m) / total_w;

	// Atenuación atmosférica sutil en la mitad trasera (detrás del piloto)
	if (!is_front_half) {
		rgb = mix(rgb, rgb * vec3(0.55, 0.62, 0.88), 0.30);
	}

	float final_a = clamp(alpha_m * mix(ring_primary_color.a, ring_accent_color.a, clamp(energy_m / total_w, 0.0, 1.0)) * alpha_mult, 0.0, 1.0);
	final_a *= over_hug_pass ? over_w : (1.0 - over_w);
	if (final_a < 0.005) {
		discard;
	}
	COLOR = vec4(rgb, final_a);
}
