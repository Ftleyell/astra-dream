shader_type canvas_item;
render_mode blend_mix, unshaded;

/**
 * star_gravitational_lens.gdshader
 *
 * Lente gravitacional local (Agujero Negro / Anillo de Einstein) y espejismo térmico coronal.
 * Opera exclusivamente sobre un Sprite2D local detrás del núcleo de la estrella
 * para evitar copias innecesarias en todo el resto del viewport.
 */

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform int lens_mode : hint_range(0, 2) = 1; // 0=Off, 1=BlackHole Einstein Lens, 2=Solar Thermal Mirage
uniform float lens_strength : hint_range(0.0, 0.12) = 0.038;
uniform float horizon_radius : hint_range(0.04, 0.30) = 0.118;
uniform vec4 tint_color : source_color = vec4(0.85, 0.62, 1.0, 1.0);
uniform float global_time = 0.0;

void fragment() {
	if (lens_mode == 0 || lens_strength <= 0.0005) {
		discard;
	}

	vec2 p = UV - vec2(0.5);
	float r = length(p);
	if (r >= 0.492) {
		discard;
	}

	if (lens_mode == 1) {
		// Horizonte oscuro interior tras el disco de acreción
		if (r < horizon_radius * 0.92) {
			float inner_fade = 1.0 - smoothstep(horizon_radius * 0.78, horizon_radius * 0.92, r);
			COLOR = vec4(0.01, 0.01, 0.02, inner_fade);
		} else {
			vec2 dir = (r > 0.0001) ? (p / r) : vec2(1.0, 0.0);
			float env = 1.0 - smoothstep(0.30, 0.485, r);
			float warp_curve = lens_strength / max(r - horizon_radius * 0.68, 0.035);
			float ring_shimmer = 1.0 + 0.08 * sin(atan(p.y, p.x) * 6.0 + global_time * 1.6);
			vec2 warp_offset = dir * (warp_curve * env * ring_shimmer * 0.12);

			// Ligera aberración cromática R/B sobre el anillo de Einstein
			float einstein_band = exp(-pow((r - horizon_radius * 1.45) / 0.045, 2.0)) * env;
			float disp = 0.0035 * einstein_band;
			vec3 col_r = textureLod(screen_texture, clamp(SCREEN_UV - warp_offset * (1.0 + disp * 25.0), vec2(0.002), vec2(0.998)), 0.0).rgb;
			vec3 col_g = textureLod(screen_texture, clamp(SCREEN_UV - warp_offset, vec2(0.002), vec2(0.998)), 0.0).rgb;
			vec3 col_b = textureLod(screen_texture, clamp(SCREEN_UV - warp_offset * (1.0 - disp * 25.0), vec2(0.002), vec2(0.998)), 0.0).rgb;
			vec3 lensed = vec3(col_r.r, col_g.g, col_b.b);
			lensed += tint_color.rgb * (einstein_band * 0.24);
			COLOR = vec4(lensed, clamp(env * 1.15, 0.0, 1.0));
		}
	} else {
		// Espejismo térmico coronal ultra-sutil alrededor de estrellas y anomalías
		float band = smoothstep(0.19, 0.27, r) * (1.0 - smoothstep(0.35, 0.46, r));
		if (band <= 0.005) {
			discard;
		}
		float ang = atan(p.y, p.x);
		float wave = sin(r * 14.0 - global_time * 2.1 + sin(ang * 3.0 + global_time * 0.9) * 0.8);
		vec2 dir = (r > 0.0001) ? (p / r) : vec2(1.0, 0.0);
		vec2 tangent = vec2(-dir.y, dir.x);
		vec2 mirage_off = (dir * wave * 0.6 + tangent * cos(ang * 4.0 - global_time * 1.6) * 0.3) * (lens_strength * band);
		vec3 bg = textureLod(screen_texture, clamp(SCREEN_UV + mirage_off, vec2(0.002), vec2(0.998)), 0.0).rgb;
		COLOR = vec4(bg + tint_color.rgb * (band * 0.04), band * 0.70);
	}
}
