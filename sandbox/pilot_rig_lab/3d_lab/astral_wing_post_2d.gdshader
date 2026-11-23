shader_type canvas_item;
render_mode blend_mix;

// Pasada 2D Post-Process unificada para los SubViewports 3D (3D Lab — Valentina v2).
// Replica el lenguaje visual de pilot_rig_pass2.gdshader sobre la textura 3D:
// 1) CAS Sharpen adaptativo (elimina el ablandamiento bilineal sin romper valores HDR > 1.0)
// 2) Contorno exterior caligráfico pixel-perfect en píxeles de pantalla (índigo ↔ ciruela)
// 3) Micro-Rim de silueta (blanco-hielo en luz + contra-rim carmesí)

uniform bool enable_post_pass = true;
uniform float cas_sharpen_strength : hint_range(0.0, 1.0) = 0.52;

uniform float post_outline_strength : hint_range(0.0, 1.0) = 0.88;
uniform float post_outline_width_px : hint_range(0.0, 4.0) = 1.35;
uniform float outline_calligraphy_amount : hint_range(0.0, 1.0) = 0.65;
uniform vec2 light_dir_2d = vec2(-0.58, -0.81);
uniform vec4 outline_shadow_color : source_color = vec4(0.045, 0.040, 0.095, 1.0);
uniform vec4 outline_lit_color : source_color = vec4(0.11, 0.035, 0.07, 1.0);

uniform float post_rim_strength : hint_range(0.0, 1.5) = 0.48;
uniform vec4 rim_key_color : source_color = vec4(0.94, 0.97, 1.0, 1.0);
uniform vec4 rim_counter_color : source_color = vec4(0.98, 0.16, 0.34, 1.0);

vec3 sample_cas(sampler2D tex, vec2 uv, vec2 px, vec3 center_rgb, float strength) {
	vec3 n = texture(tex, uv + vec2(0.0, -px.y)).rgb;
	vec3 s = texture(tex, uv + vec2(0.0, px.y)).rgb;
	vec3 e = texture(tex, uv + vec2(px.x, 0.0)).rgb;
	vec3 w = texture(tex, uv + vec2(-px.x, 0.0)).rgb;

	vec3 mn = min(center_rgb, min(min(n, s), min(e, w)));
	vec3 mx = max(center_rgb, max(max(n, s), max(e, w)));
	vec3 lap = center_rgb * 4.0 - (n + s + e + w);

	// Preservar picos HDR (> 1.0) sin halo oscuro alrededor de venas emisivas
	float max_lum = max(center_rgb.r, max(center_rgb.g, center_rgb.b));
	float hdr_guard = 1.0 - smoothstep(1.1, 2.2, max_lum) * 0.55;
	vec3 sharp = center_rgb + lap * (0.28 * strength * hdr_guard);
	return clamp(sharp, mn * 0.85, max(mx * 1.18, center_rgb));
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (!enable_post_pass) {
		COLOR = base * COLOR;
	} else {
		vec2 px = TEXTURE_PIXEL_SIZE;
		vec2 l2d = normalize(light_dir_2d);

		// 1. Muestreo 8-dir para contorno exterior pixel-perfect y gradiente de silueta
		float rad = max(post_outline_width_px, 0.5);
		vec2 dirs[8] = vec2[8](
			vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
			vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071), vec2(0.7071, -0.7071), vec2(-0.7071, -0.7071)
		);

		float max_neighbor_a = 0.0;
		float min_neighbor_a = 1.0;
		vec2 alpha_grad = vec2(0.0);

		for (int i = 0; i < 8; i++) {
			vec2 d = dirs[i];
			// Caligrafía 2D: extiende ligeramente más en el lado opuesto a la luz
			float side_lit = dot(d, -l2d);
			float r_dir = rad * mix(1.0, mix(1.25, 0.72, side_lit * 0.5 + 0.5), outline_calligraphy_amount);
			float a_s = texture(TEXTURE, UV + d * px * r_dir).a;
			max_neighbor_a = max(max_neighbor_a, a_s);
			min_neighbor_a = min(min_neighbor_a, a_s);
			alpha_grad += d * a_s;
		}

		// Normal 2D exterior de la silueta
		vec2 out_n = (length(alpha_grad) > 0.001) ? normalize(-alpha_grad) : vec2(0.0, -1.0);
		float lit_side = smoothstep(-0.35, 0.45, dot(out_n, l2d));

		if (base.a < 0.08) {
			// Píxel fuera de la malla: dibujar contorno exterior nítido pixel-perfect
			float edge_mask = smoothstep(0.18, 0.72, max_neighbor_a) * post_outline_strength;
			if (edge_mask > 0.005) {
				vec3 ink_col = mix(outline_shadow_color.rgb, outline_lit_color.rgb, lit_side * 0.68);
				COLOR = vec4(ink_col, edge_mask) * COLOR;
			} else {
				COLOR = vec4(0.0);
			}
		} else {
			// Píxel dentro de la malla: CAS Sharpen + Micro-Rim de silueta
			vec3 rgb = base.rgb;
			if (cas_sharpen_strength > 0.001) {
				rgb = sample_cas(TEXTURE, UV, px, rgb, cas_sharpen_strength);
			}

			// Micro-rim en el borde interior de la silueta (igual que pilot_rig_pass2)
			if (post_rim_strength > 0.001) {
				float inner_edge = (1.0 - smoothstep(0.25, 0.92, min_neighbor_a)) * base.a;
				vec3 rim_tint = mix(rim_counter_color.rgb * 0.72, rim_key_color.rgb, lit_side);
				rgb += rim_tint * inner_edge * post_rim_strength * 0.55;
			}

			COLOR = vec4(rgb, base.a) * COLOR;
		}
	}
}
