shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform vec4 fill_color : source_color = vec4(0.0, 0.94, 1.0, 1.0);
uniform vec4 outline_color : source_color = vec4(0.65, 0.98, 1.0, 1.0);
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.55;
uniform float outline_alpha : hint_range(0.0, 1.0) = 0.88;
uniform float outline_width_px : hint_range(0.0, 8.0) = 2.6;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.42;
uniform float rim_width_px : hint_range(0.5, 6.0) = 2.2;
uniform float internal_ink_strength : hint_range(0.0, 1.0) = 1.0;
uniform float emissive_boost : hint_range(0.5, 3.0) = 1.15;

const vec2 DIRS_12[12] = vec2[12](
	vec2(1.0, 0.0),
	vec2(0.866025, 0.5),
	vec2(0.5, 0.866025),
	vec2(0.0, 1.0),
	vec2(-0.5, 0.866025),
	vec2(-0.866025, 0.5),
	vec2(-1.0, 0.0),
	vec2(-0.866025, -0.5),
	vec2(-0.5, -0.866025),
	vec2(0.0, -1.0),
	vec2(0.5, -0.866025),
	vec2(0.866025, -0.5)
);

void fragment() {
	vec4 center = textureLod(screen_texture, SCREEN_UV, 0.0);
	float core_a = smoothstep(0.08, 0.42, center.a);

	float max_out_a = 0.0;
	float min_in_a = 1.0;

	if (outline_width_px > 0.05 && outline_alpha > 0.005) {
		vec2 px = SCREEN_PIXEL_SIZE;
		for (int i = 0; i < 12; i++) {
			vec2 d = DIRS_12[i];
			float a_outer = textureLod(screen_texture, clamp(SCREEN_UV + d * outline_width_px * px, vec2(0.0), vec2(1.0)), 0.0).a;
			float a_mid = textureLod(screen_texture, clamp(SCREEN_UV + d * (outline_width_px * 0.5) * px, vec2(0.0), vec2(1.0)), 0.0).a;
			max_out_a = max(max_out_a, max(a_outer, a_mid));
		}
	}

	if (core_a > 0.05 && rim_strength > 0.01) {
		vec2 px = SCREEN_PIXEL_SIZE;
		for (int i = 0; i < 12; i += 2) {
			vec2 d = DIRS_12[i];
			float a_in = textureLod(screen_texture, clamp(SCREEN_UV + d * rim_width_px * px, vec2(0.0), vec2(1.0)), 0.0).a;
			min_in_a = min(min_in_a, a_in);
		}
	}

	float outer_edge = smoothstep(0.10, 0.48, max_out_a) * (1.0 - core_a);
	float inner_rim = core_a * (1.0 - smoothstep(0.15, 0.72, min_in_a));
	// Canal R premultiplicado del CanvasGroup contiene la máscara de tinta interna SDF (Pasada 1)
	float ink_mask = core_a > 0.05 ? clamp(center.r / max(center.a, 0.0001), 0.0, 1.0) * internal_ink_strength : 0.0;

	vec3 fill_rgb = fill_color.rgb * emissive_boost;
	// Outline exterior y tinta interna comparten exactamente el mismo color y propiedades
	vec3 outline_rgb = outline_color.rgb;

	float ink_mix = clamp(max(ink_mask, inner_rim * rim_strength), 0.0, 1.0);
	vec3 inside_rgb = mix(fill_rgb, outline_rgb, ink_mix);
	float fill_and_rim_a = clamp(fill_alpha + inner_rim * outline_alpha * 0.35, 0.0, 1.0);
	// La tinta interna conserva outline_alpha incluso cuando el relleno ya se desvaneció ("calco")
	float inside_a = max(fill_and_rim_a, ink_mask * outline_alpha) * core_a;

	// El outline exterior se mantiene nítido incluso cuando el relleno ya se desvaneció ("calco")
	float out_a = outer_edge * outline_alpha;

	float final_a = clamp(inside_a + out_a, 0.0, 1.0);
	vec3 final_rgb = mix(inside_rgb, outline_rgb, clamp(out_a / max(final_a, 0.0001), 0.0, 1.0));

	COLOR = vec4(final_rgb, final_a);
}
