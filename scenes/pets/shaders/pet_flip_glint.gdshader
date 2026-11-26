shader_type canvas_item;

uniform float flash_progress : hint_range(0.0, 1.0) = 0.0;
uniform float flash_intensity : hint_range(0.0, 2.5) = 1.15;
uniform vec4 rim_color : source_color = vec4(1.0, 0.90, 0.55, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform float spin_angle = 0.0;

vec2 rot2d(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

void fragment() {
	if (flash_progress <= 0.001 || flash_progress >= 0.999) {
		discard;
	}

	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}

	float peak = pow(sin(flash_progress * PI), 1.4);

	vec2 ps = rot2d(p, spin_angle + flash_progress * 1.4);
	float arm_x = exp(-abs(ps.y) * 14.0) * exp(-abs(ps.x) * 2.4);
	float arm_y = exp(-abs(ps.x) * 14.0) * exp(-abs(ps.y) * 2.4);
	float star_main = clamp(arm_x + arm_y, 0.0, 1.4);

	vec2 pd = rot2d(p, spin_angle * -0.7 + 0.785398);
	float diag_x = exp(-abs(pd.y) * 18.0) * exp(-abs(pd.x) * 4.2);
	float diag_y = exp(-abs(pd.x) * 18.0) * exp(-abs(pd.y) * 4.2);
	float star_diag = clamp(diag_x + diag_y, 0.0, 1.0) * 0.55;

	float core_glow = exp(-r * r * 6.2) * 1.15;

	float ring_r = mix(0.18, 0.88, flash_progress);
	float ring = smoothstep(0.08, 0.0, abs(r - ring_r)) * (1.0 - flash_progress * 0.45) * 0.85;

	float total = (star_main + star_diag + core_glow + ring) * peak * flash_intensity;
	vec3 col = mix(rim_color.rgb, core_color.rgb, clamp(core_glow * 0.8 + star_main * 0.35, 0.0, 1.0));
	float alpha = clamp(total, 0.0, 0.96) * (1.0 - smoothstep(0.86, 1.0, r));

	COLOR = vec4(col * 1.25, alpha);
}
