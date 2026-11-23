shader_type canvas_item;
render_mode blend_add, unshaded;

// Capa aditiva HDR para pulso energético tipo escáner cibernético en las vetas rojas de las alas.
// Vive fuera de UnifiedCharacterGroup para atravesar el Bloom HDR del WorldEnvironment.
uniform sampler2D ilm_mask_tex : filter_linear_mipmap;
uniform vec4 glow_color : source_color = vec4(1.0, 0.08, 0.22, 1.0);
uniform vec4 core_hot_color : source_color = vec4(1.0, 0.88, 0.92, 1.0);
uniform float glow_intensity : hint_range(0.0, 4.0) = 1.2;

uniform float pulse_time = 0.0;
uniform vec2 blade_pivot_uv = vec2(0.05, 0.95);
uniform vec2 blade_tip_uv = vec2(0.95, 0.05);
uniform float pulse_phase_offset = 0.0;
uniform float pulse_speed = 4.6;
uniform float pulse_freq = 3.2;
uniform float pulse_strength = 0.85;
uniform float ignition_flash : hint_range(0.0, 3.0) = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float em = smoothstep(0.18, 0.82, texture(ilm_mask_tex, UV).a);
	float mask = base.a * em;

	vec2 axis = blade_tip_uv - blade_pivot_uv;
	float denom = max(dot(axis, axis), 0.0001);
	float t_along = clamp(dot(UV - blade_pivot_uv, axis) / denom, 0.0, 1.0);

	float scan_phase = fract(t_along * pulse_freq - pulse_time * pulse_speed + pulse_phase_offset);
	float band_sharp = pow(1.0 - abs(scan_phase * 2.0 - 1.0), 6.0);
	float fine_ripple = pow(0.5 + 0.5 * sin((t_along * 18.0 - pulse_time * pulse_speed * 3.2) + pulse_phase_offset * 6.283185), 4.0);
	float tip_hot = smoothstep(0.62, 1.0, t_along) * 0.45;

	float energy_mod = 0.38 + (band_sharp * 0.95 + fine_ripple * 0.35) * pulse_strength + tip_hot + ignition_flash * 1.4;
	float hot_mix = clamp(band_sharp * 0.55 + ignition_flash * 0.35, 0.0, 0.85);
	vec3 pulse_col = mix(glow_color.rgb, core_hot_color.rgb, hot_mix);

	COLOR = vec4(pulse_col * glow_intensity * energy_mod * mask, mask);
}
