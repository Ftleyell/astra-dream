shader_type canvas_item;
render_mode blend_mix, unshaded;

/**
 * cosmic_post_grade.gdshader
 *
 * Post-grade atmosférico unificado ligero (sin hint_screen_texture para cero coste de copia en Vulkan Mobile):
 * - Viñeta orgánica profunda de bioma en el perímetro de cámara (deja limpio el centro para combate).
 * - Baño direccional solar suave y franja cromática perimetral hacia el sol dominante.
 */

uniform vec2 viewport_resolution = vec2(1920.0, 1080.0);
uniform float global_time = 0.0;
uniform bool enable_optical_wash = true;

uniform vec2 star_screen_pos = vec2(960.0, 540.0);
uniform vec4 star_color : source_color = vec4(1.0, 0.88, 0.55, 1.0);
uniform vec4 biome_primary : source_color = vec4(0.24, 0.06, 0.42, 1.0);
uniform vec4 biome_secondary : source_color = vec4(0.04, 0.32, 0.56, 1.0);
uniform float star_influence : hint_range(0.0, 1.0) = 0.0;

uniform float vignette_strength : hint_range(0.0, 0.6) = 0.24;
uniform float directional_wash_strength : hint_range(0.0, 0.35) = 0.11;
uniform float film_grain_strength : hint_range(0.0, 0.04) = 0.012;
uniform float domain_entry_pulse : hint_range(0.0, 1.0) = 0.0;

float hash_grain(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 centered = (SCREEN_UV - vec2(0.5)) * vec2(viewport_resolution.x / max(viewport_resolution.y, 1.0), 1.0);
	float edge_r = length(centered) * 1.18;

	// Viñeta perimetral oscura teñida del bioma; zona central de combate 100% libre
	float vig_mask = smoothstep(0.58, 1.38, edge_r) * vignette_strength;
	vec3 vig_col = mix(vec3(0.008, 0.010, 0.028), biome_primary.rgb * 0.28, 0.42);

	vec3 out_col = vig_col;
	float out_alpha = vig_mask;

	// Halo y gradiente óptico hacia la estrella dominante (solo calidad alta)
	if (enable_optical_wash && star_influence > 0.03) {
		vec2 sun_uv = star_screen_pos / max(viewport_resolution, vec2(1.0));
		vec2 to_sun = sun_uv - vec2(0.5);
		float to_sun_len = length(to_sun);
		vec2 sun_dir = (to_sun_len > 0.001) ? (to_sun / to_sun_len) : vec2(0.85, -0.52);

		float dir_align = clamp(dot(SCREEN_UV - vec2(0.5), sun_dir) * 0.85 + 0.35, 0.0, 1.0);
		float edge_rim = smoothstep(0.32, 1.15, edge_r);
		float wash_w = dir_align * edge_rim * star_influence * directional_wash_strength;

		// Ligero tinte cálido en el cuadrante solar y acento frío secundario en esquinas opuestas
		float anti_align = clamp(dot(SCREEN_UV - vec2(0.5), -sun_dir) * 0.8 + 0.25, 0.0, 1.0);
		vec3 optical_col = mix(biome_secondary.rgb * 0.55, star_color.rgb, clamp(dir_align * 1.15, 0.0, 1.0));
		float fringe_w = anti_align * smoothstep(0.68, 1.38, edge_r) * 0.07 * star_influence;

		float total_tint_w = wash_w + fringe_w;
		float denom = max(out_alpha + total_tint_w, 0.0001);
		out_col = (vig_col * out_alpha + optical_col * total_tint_w) / denom;
		out_alpha = clamp(max(out_alpha, total_tint_w) + wash_w * 0.35, 0.0, 0.42);
	}

	// Pulso perimetral sutil al cruzar la frontera de un dominio estelar (centro libre)
	if (enable_optical_wash && domain_entry_pulse > 0.005) {
		float pulse_rim = smoothstep(0.45, 1.28, edge_r) * domain_entry_pulse * 0.14;
		out_col = mix(out_col, star_color.rgb, clamp(pulse_rim * 2.2, 0.0, 0.65));
		out_alpha = clamp(max(out_alpha, pulse_rim) + pulse_rim * 0.35, 0.0, 0.45);
	}

	// Micro-grano celuloide anime anti-banding (solo calidad alta)
	if (enable_optical_wash && film_grain_strength > 0.0005) {
		float g = hash_grain(floor(SCREEN_UV * viewport_resolution) + vec2(fract(global_time * 13.7) * 97.0)) - 0.5;
		out_col = clamp(out_col + vec3(g * film_grain_strength), vec3(0.0), vec3(1.0));
		out_alpha = max(out_alpha, film_grain_strength * 0.35);
	}

	if (out_alpha <= 0.003) {
		discard;
	}
	COLOR = vec4(out_col, out_alpha);
}
