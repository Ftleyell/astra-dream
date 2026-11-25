shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// Holograma 3D Astral Pop-Ink para la Navegante Táctica sobre el Proyector de Compañía.
// Recorte circular suave con halo fresnel, scanlines finos animados y tinte holográfico limpio.

uniform sampler2D portrait_tex : source_color, filter_linear, repeat_disable;
uniform vec4 holo_tint : source_color = vec4(0.18, 0.92, 1.0, 1.0);
uniform vec4 ring_color : source_color = vec4(0.95, 0.78, 0.34, 1.0);
uniform float hdr_boost : hint_range(0.5, 2.5) = 1.25;

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - vec2(0.5)) * 2.0;
	float r = length(p);
	if (r > 0.98) {
		discard;
	}

	vec4 tex_col = texture(portrait_tex, uv);
	float circle_mask = 1.0 - smoothstep(0.76, 0.95, r);
	float rim_ring = (1.0 - smoothstep(0.0, 0.065, abs(r - 0.88)));
	float outer_ring = (1.0 - smoothstep(0.0, 0.035, abs(r - 0.94)));

	float scan = 0.84 + 0.16 * sin(uv.y * 120.0 - TIME * 5.0);
	float sweep = 1.0 - smoothstep(0.0, 0.18, abs(fract(uv.y - TIME * 0.32) - 0.5));

	vec3 tinted = mix(tex_col.rgb, tex_col.rgb * holo_tint.rgb * 1.15, 0.48);
	vec3 rgb = tinted * scan + holo_tint.rgb * (sweep * 0.16);
	rgb = mix(rgb, holo_tint.rgb * hdr_boost, rim_ring * 0.85);
	rgb = mix(rgb, ring_color.rgb * hdr_boost, outer_ring * 0.90);

	float tex_a = max(tex_col.a, 0.25) * circle_mask * 0.82;
	float alpha = clamp(max(tex_a, max(rim_ring * 0.9, outer_ring * 0.85)), 0.0, 0.96);

	ALBEDO = rgb;
	ALPHA = alpha;
}
