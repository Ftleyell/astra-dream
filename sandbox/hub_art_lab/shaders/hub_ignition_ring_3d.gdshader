shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// Anillo de Ignición Orbital Norte en el suelo del Hub 3D.
// Consume el bundle RGBA empaquetado de build_orbital_ring_texture.py:
//   R = estructura plata, G = cheurones de energía, B = máscara radial (outer > 0.5, inner <= 0.5), A = recorte.

uniform sampler2D ring_packed_tex : filter_linear_mipmap, repeat_disable;
uniform vec4 ring_primary_color : source_color = vec4(0.91, 0.78, 0.44, 0.96);
uniform vec4 ring_accent_color : source_color = vec4(0.95, 0.16, 0.34, 1.0);
uniform float outer_rot_speed = 0.22;
uniform float inner_rot_speed = -0.38;
uniform float energy_hdr_boost : hint_range(0.5, 4.0) = 2.0;
uniform float ignition_charge : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_mult : hint_range(0.0, 1.5) = 0.96;

vec2 rotate_uv(vec2 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float speed_mult = 1.0 + ignition_charge * 5.5;
	vec2 uv_out = vec2(0.5) + rotate_uv(p, TIME * outer_rot_speed * speed_mult);
	vec2 uv_in = vec2(0.5) + rotate_uv(p, TIME * inner_rot_speed * speed_mult);

	vec4 s_out = vec4(0.0);
	if (uv_out.x >= 0.0 && uv_out.x <= 1.0 && uv_out.y >= 0.0 && uv_out.y <= 1.0) {
		s_out = texture(ring_packed_tex, uv_out);
	}
	vec4 s_in = vec4(0.0);
	if (uv_in.x >= 0.0 && uv_in.x <= 1.0 && uv_in.y >= 0.0 && uv_in.y <= 1.0) {
		s_in = texture(ring_packed_tex, uv_in);
	}

	float out_zone = smoothstep(0.42, 0.58, s_out.b);
	float in_zone = 1.0 - smoothstep(0.42, 0.58, s_in.b);

	float struct_m = max(s_out.r * out_zone, s_in.r * in_zone);
	float energy_m = max(s_out.g * out_zone, s_in.g * in_zone);
	float alpha_m = max(s_out.a * out_zone, s_in.a * in_zone);

	if (alpha_m < 0.02 && ignition_charge < 0.01) {
		discard;
	}

	float idle_breathe = 0.90 + 0.14 * sin(TIME * 2.4);
	float pulse = idle_breathe + ignition_charge * 1.45;
	vec3 struct_col = ring_primary_color.rgb * (0.95 + ignition_charge * 0.45);
	vec3 energy_col = ring_accent_color.rgb * (energy_hdr_boost * pulse);

	float total_w = max(struct_m + energy_m, 0.001);
	vec3 rgb = (struct_col * struct_m + energy_col * energy_m) / total_w;

	// Resplandor anular radial de núcleo durante la ignición
	float rad = length(p) * 2.0;
	float charge_halo = 0.0;
	if (ignition_charge > 0.01) {
		float core_ring = 1.0 - smoothstep(0.0, 0.18, abs(rad - 0.56));
		float inner_fill = (1.0 - smoothstep(0.0, 0.72, rad)) * 0.45;
		charge_halo = (core_ring + inner_fill) * ignition_charge;
		rgb += mix(ring_accent_color.rgb, ring_primary_color.rgb, 0.35) * (charge_halo * 1.8);
	}

	ALBEDO = rgb;
	ALPHA = clamp(max(alpha_m * alpha_mult, charge_halo * 0.72), 0.0, 1.0);
}
