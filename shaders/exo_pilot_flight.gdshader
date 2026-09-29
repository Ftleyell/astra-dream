shader_type canvas_item;
render_mode blend_mix;

// =========================================================================
// GEOMETRÍA Y EXPANSIÓN DEL QUAD PERIMETRAL
// =========================================================================
uniform float margin_expansion : hint_range(0.0, 64.0, 1.0) = 22.0;

// =========================================================================
// PARÁMETROS DEL FLAMEO DE PLASMA Y COMBUSTIÓN SANDEVISTAN
// =========================================================================
uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform vec2 flame_direction = vec2(0.0, 1.0); // Vector de desprendimiento de llamas en espacio local (hacia la cola)
uniform float flame_speed : hint_range(0.1, 15.0) = 5.0;
uniform float flame_distortion_intensity : hint_range(0.0, 0.4) = 0.055;
uniform float flame_thickness : hint_range(0.0, 40.0) = 16.0;

// =========================================================================
// PALETA CROMÁTICA HDR Y ENERGÍA
// =========================================================================
uniform vec4 primary_color : source_color = vec4(0.2, 0.75, 1.0, 1.0);     // Núcleo de llama (color de la piloto)
uniform vec4 secondary_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);   // Borde exterior / llama secundaria
uniform float hdr_energy_multiplier : hint_range(1.0, 8.0) = 2.6;

// =========================================================================
// CINEMÁTICA Y REACTIVIDAD DE VUELO
// =========================================================================
uniform float thrust_intensity : hint_range(0.0, 3.5) = 1.0;
uniform float speed_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float bank_tilt : hint_range(-1.0, 1.0) = 0.0;
uniform float chromatic_offset : hint_range(0.0, 0.02) = 0.004;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;

// =========================================================================
// REACTOR / HITBOXCORE Y SILUETA SÓLIDA PARA AFTERIMAGES
// =========================================================================
uniform float core_gem_glow : hint_range(0.0, 3.5) = 1.2;
uniform vec2 core_gem_uv = vec2(0.5, 0.50);
uniform float silhouette_solidarity : hint_range(0.0, 1.0) = 0.0;

varying vec2 corrected_uv;
varying vec2 dynamic_pixel_ratio;

// Ruido procedural fallback de alta frecuencia
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float procedural_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	// Inclinación lateral (Banking tilt)
	VERTEX.x += bank_tilt * (VERTEX.y + 64.0) * 0.12;

	// Expansión cuádruple en las 4 esquinas del quad
	vec2 expansion_dir = sign(VERTEX);
	if (abs(expansion_dir.x) < 0.5) { expansion_dir.x = 1.0; }
	if (abs(expansion_dir.y) < 0.5) { expansion_dir.y = 1.0; }
	VERTEX += expansion_dir * margin_expansion;

	// Remapeo de UVs para que el sprite PNG mantenga escala exacta y no sufra distorsión
	vec2 original_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 expanded_size = original_size + vec2(margin_expansion * 2.0);
	dynamic_pixel_ratio = original_size / expanded_size;

	vec2 margin_uv_fraction = vec2(margin_expansion) / expanded_size;
	corrected_uv = (UV - margin_uv_fraction) / dynamic_pixel_ratio;
}

#define SAMPLE_ALPHA(c) (((c).x < 0.0 || (c).x > 1.0 || (c).y < 0.0 || (c).y > 1.0) ? 0.0 : texture(TEXTURE, (c)).a)

void fragment() {
	// 1. Ruido procedural (con fallback si no se asigna sampler)
	vec2 flow_dir = length(flame_direction) > 0.01 ? normalize(flame_direction) : vec2(0.0, 1.0);
	vec2 noise_coords = (corrected_uv * 7.0) + (flow_dir * TIME * flame_speed);
	vec4 noise_sample = texture(noise_texture, noise_coords * 0.15);
	float n = noise_sample.a > 0.01 ? (noise_sample.r - 0.5) * 2.0 : (procedural_noise(noise_coords) - 0.5) * 2.0;

	float dynamic_distort = flame_distortion_intensity * clamp(thrust_intensity, 0.35, 2.5);
	vec2 distorted_uv = corrected_uv + (flow_dir * n * dynamic_distort);

	// 2. Núcleo del sprite: Aberración cromática y canal alfa base
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec2 ca_shift = flow_dir * (chromatic_offset * (0.8 + 0.5 * thrust_intensity));
	
	float base_alpha = SAMPLE_ALPHA(corrected_uv);
	float r = (corrected_uv.x >= 0.0 && corrected_uv.x <= 1.0 && corrected_uv.y >= 0.0 && corrected_uv.y <= 1.0) 
		? texture(TEXTURE, clamp(corrected_uv - ca_shift, vec2(0.0), vec2(1.0))).r : 0.0;
	float g = (corrected_uv.x >= 0.0 && corrected_uv.x <= 1.0 && corrected_uv.y >= 0.0 && corrected_uv.y <= 1.0)
		? texture(TEXTURE, clamp(corrected_uv, vec2(0.0), vec2(1.0))).g : 0.0;
	float b = (corrected_uv.x >= 0.0 && corrected_uv.x <= 1.0 && corrected_uv.y >= 0.0 && corrected_uv.y <= 1.0)
		? texture(TEXTURE, clamp(corrected_uv + ca_shift, vec2(0.0), vec2(1.0))).b : 0.0;

	vec4 base_color = vec4(r, g, b, base_alpha);

	// 3. Muestreo multi-anillo concéntrico suave (sin artefactos de 8 puntos aislados)
	float effective_radius = flame_thickness * clamp(thrust_intensity, 0.25, 2.5);
	float r_inner = effective_radius * 0.45;
	float r_outer = effective_radius * 0.95;

	// Anillo interior (8 muestras densas)
	float accum_inner = 0.0;
	accum_inner += SAMPLE_ALPHA(distorted_uv + vec2( r_inner, 0.0) * texel);
	accum_inner += SAMPLE_ALPHA(distorted_uv + vec2(-r_inner, 0.0) * texel);
	accum_inner += SAMPLE_ALPHA(distorted_uv + vec2(0.0,  r_inner) * texel);
	accum_inner += SAMPLE_ALPHA(distorted_uv + vec2(0.0, -r_inner) * texel);
	accum_inner += SAMPLE_ALPHA(distorted_uv + vec2( r_inner * 0.707,  r_inner * 0.707) * texel);
	accum_inner += SAMPLE_ALPHA(distorted_uv + vec2(-r_inner * 0.707,  r_inner * 0.707) * texel);
	accum_inner += SAMPLE_ALPHA(distorted_uv + vec2( r_inner * 0.707, -r_inner * 0.707) * texel);
	accum_inner += SAMPLE_ALPHA(distorted_uv + vec2(-r_inner * 0.707, -r_inner * 0.707) * texel);
	accum_inner /= 8.0;

	// Anillo exterior con sesgo hacia la estela de flujo
	float accum_outer = 0.0;
	vec2 trail_bias = -flow_dir * (effective_radius * 0.4);
	accum_outer += SAMPLE_ALPHA(distorted_uv + (trail_bias + vec2( r_outer, 0.0)) * texel);
	accum_outer += SAMPLE_ALPHA(distorted_uv + (trail_bias + vec2(-r_outer, 0.0)) * texel);
	accum_outer += SAMPLE_ALPHA(distorted_uv + (trail_bias + vec2(0.0,  r_outer)) * texel);
	accum_outer += SAMPLE_ALPHA(distorted_uv + (trail_bias + vec2(0.0, -r_outer)) * texel);
	accum_outer += SAMPLE_ALPHA(distorted_uv + (trail_bias + vec2( r_outer * 0.707,  r_outer * 0.707)) * texel);
	accum_outer += SAMPLE_ALPHA(distorted_uv + (trail_bias + vec2(-r_outer * 0.707,  r_outer * 0.707)) * texel);
	accum_outer += SAMPLE_ALPHA(distorted_uv + (trail_bias + vec2( r_outer * 0.707, -r_outer * 0.707)) * texel);
	accum_outer += SAMPLE_ALPHA(distorted_uv + (trail_bias + vec2(-r_outer * 0.707, -r_outer * 0.707)) * texel);
	accum_outer /= 8.0;

	// Densidad compuesta suave
	float total_density = (accum_inner * 0.65) + (accum_outer * 0.35);

	// 4. Máscara de flameo exterior (sólo en zonas transparentes fuera del sprite)
	float flame_mask = smoothstep(0.03, 0.75, total_density) * (1.0 - base_alpha);
	// Añadir ondulación viva con el ruido
	flame_mask *= clamp(0.55 + 0.45 * sin(n * 3.1415 + TIME * 8.0), 0.0, 1.0);

	// Degradado bicolor HDR: secundario en la punta disipada, primario cerca del cuerpo
	vec4 flame_color = mix(secondary_color, primary_color, smoothstep(0.1, 0.6, total_density));
	flame_color.rgb *= (hdr_energy_multiplier * clamp(thrust_intensity, 0.5, 2.2));
	flame_color.a *= flame_mask;

	// 5. Núcleo nítido de la figura PNG
	vec3 rgb = base_color.rgb;
	if (base_alpha > 0.01) {
		// Rim-light holográfico ultra-fino en el contorno interno
		float inner_edge = (1.0 - accum_inner) * smoothstep(0.1, 0.9, total_density);
		rgb += primary_color.rgb * (inner_edge * 1.5 * clamp(thrust_intensity, 0.4, 2.0));

		// Destello por impacto
		if (hit_flash > 0.0) {
			rgb = mix(rgb, vec3(1.0, 0.25, 0.25), hit_flash);
		}

		// Reactor / Gema de HitboxCore en el pecho
		float dist_gem = length((corrected_uv - core_gem_uv) * vec2(1.0, 1.25));
		if (dist_gem < 0.08) {
			float gem_core = smoothstep(0.038, 0.005, dist_gem);
			float gem_halo = smoothstep(0.075, 0.025, dist_gem);
			float gem_pulse = 0.85 + 0.3 * sin(TIME * 6.0);
			vec3 gem_color = mix(primary_color.rgb * 1.8, secondary_color.rgb * 2.2, gem_core);
			rgb = mix(rgb, gem_color, gem_halo * core_gem_glow * gem_pulse);
			base_alpha = max(base_alpha, gem_halo * 0.95);
		}

		// Silueta monocromática neón para afterimages
		if (silhouette_solidarity > 0.0) {
			vec3 solid_tint = primary_color.rgb * hdr_energy_multiplier;
			rgb = mix(rgb, solid_tint, silhouette_solidarity);
		}
	}

	// 6. Fusión limpia: arte nítido donde base_alpha > 0, flameo vibrante donde base_alpha == 0
	vec4 final_color = mix(flame_color, vec4(rgb, base_alpha), base_alpha);
	COLOR = final_color;
}
