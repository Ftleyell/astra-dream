shader_type canvas_item;
render_mode blend_mix;

// =========================================================================
// GEOMETRÍA Y EXPANSIÓN DEL QUAD PERIMETRAL
// =========================================================================
uniform float margin_expansion : hint_range(0.0, 64.0, 1.0) = 22.0;

// =========================================================================
// MÁSCARA RGBA Y ANIMACIÓN PROCEDIMENTAL DE PILOTOS
// =========================================================================
uniform sampler2D mask_texture : hint_default_black, filter_nearest;
uniform bool has_mask = false;

// Coletas / Cabello (R = Mechón derecho, B = Mechón izquierdo)
uniform vec2 hair_dir = vec2(1.0, 0.0);
uniform float wind_speed : hint_range(0.0, 30.0) = 15.0;
uniform float wave_freq : hint_range(0.0, 40.0) = 16.0;
uniform float hair_amp : hint_range(0.0, 0.06) = 0.02;

// Inercia y curvatura centrífuga de piernas (G)
uniform float leg_bend : hint_range(-0.25, 0.25) = 0.0;

// Toberas de plasma soplete (Raymarching sobre píxeles blancos #FFFFFF)
uniform bool enable_thrusters = true;
uniform float thruster_length : hint_range(0.1, 0.8) = 0.44;
uniform float thruster_width : hint_range(0.01, 0.15) = 0.045;
uniform float thruster_speed : hint_range(10.0, 100.0) = 55.0;
uniform float thruster_angle : hint_range(0.0, 0.3) = 0.08;
uniform vec4 thruster_core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

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
uniform vec4 primary_color : source_color = vec4(0.2, 0.75, 1.0, 1.0);     // Núcleo de llama (color temático de la piloto)
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
	vec2 base_uv = corrected_uv;
	vec2 pilot_uv = base_uv;

	// 1. Deformación procedimental por máscara RGBA (Cabello y Piernas)
	if (has_mask && base_uv.x >= 0.0 && base_uv.x <= 1.0 && base_uv.y >= 0.0 && base_uv.y <= 1.0) {
		vec4 mask = texture(mask_texture, base_uv);

		// Mechón R y Mechón B desfasados rítmicamente
		float is_hair_r = step(0.4, mask.r) * step(mask.g, 0.2);
		float is_hair_l = step(0.4, mask.b) * step(mask.g, 0.2);
		float wave_r = sin((base_uv.y * wave_freq) + (TIME * wind_speed)) * hair_amp * is_hair_r;
		float wave_l = sin((base_uv.y * wave_freq) + (TIME * wind_speed) + 1.7) * hair_amp * is_hair_l;

		// Curvatura de arco cuadrática de piernas
		float leg_progress = clamp((base_uv.y - 0.45) / 0.50, 0.0, 1.0);
		float leg_curve = pow(leg_progress, 1.8) * leg_bend;

		pilot_uv.x -= leg_curve;
		pilot_uv += hair_dir * (wave_r + wave_l);
	}

	// 2. Ruido procedural de flujo y combustión Sandevistan
	vec2 flow_dir = length(flame_direction) > 0.01 ? normalize(flame_direction) : vec2(0.0, 1.0);
	vec2 noise_coords = (pilot_uv * 7.0) + (flow_dir * TIME * flame_speed);
	vec4 noise_sample = texture(noise_texture, noise_coords * 0.15);
	float n = noise_sample.a > 0.01 ? (noise_sample.r - 0.5) * 2.0 : (procedural_noise(noise_coords) - 0.5) * 2.0;

	float dynamic_distort = flame_distortion_intensity * clamp(thrust_intensity, 0.35, 2.5);
	vec2 distorted_uv = pilot_uv + (flow_dir * n * dynamic_distort);

	// 3. Núcleo del sprite con deformación y aberración cromática
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec2 ca_shift = flow_dir * (chromatic_offset * (0.8 + 0.5 * thrust_intensity));
	
	float base_alpha = SAMPLE_ALPHA(pilot_uv);
	float r = (pilot_uv.x >= 0.0 && pilot_uv.x <= 1.0 && pilot_uv.y >= 0.0 && pilot_uv.y <= 1.0) 
		? texture(TEXTURE, clamp(pilot_uv - ca_shift, vec2(0.0), vec2(1.0))).r : 0.0;
	float g = (pilot_uv.x >= 0.0 && pilot_uv.x <= 1.0 && pilot_uv.y >= 0.0 && pilot_uv.y <= 1.0) 
		? texture(TEXTURE, clamp(pilot_uv, vec2(0.0), vec2(1.0))).g : 0.0;
	float b = (pilot_uv.x >= 0.0 && pilot_uv.x <= 1.0 && pilot_uv.y >= 0.0 && pilot_uv.y <= 1.0) 
		? texture(TEXTURE, clamp(pilot_uv + ca_shift, vec2(0.0), vec2(1.0))).b : 0.0;

	vec4 base_color = vec4(r, g, b, base_alpha);

	// 4. Muestreo multi-anillo concéntrico suave de estela Sandevistan
	float effective_radius = flame_thickness * clamp(thrust_intensity, 0.25, 2.5);
	float r_inner = effective_radius * 0.45;
	float r_outer = effective_radius * 0.95;

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

	float total_density = (accum_inner * 0.65) + (accum_outer * 0.35);

	// Máscara de flameo exterior Sandevistan
	float flame_mask = smoothstep(0.03, 0.75, total_density) * (1.0 - base_alpha);
	flame_mask *= clamp(0.55 + 0.45 * sin(n * 3.1415 + TIME * 8.0), 0.0, 1.0);

	vec4 flame_color = mix(secondary_color, primary_color, smoothstep(0.1, 0.6, total_density));
	flame_color.rgb *= (hdr_energy_multiplier * clamp(thrust_intensity, 0.5, 2.2));
	flame_color.a *= flame_mask;

	// 5. Núcleo nítido de la figura con Rim-light y Gema
	vec3 rgb = base_color.rgb;
	if (base_alpha > 0.01) {
		float inner_edge = (1.0 - accum_inner) * smoothstep(0.1, 0.9, total_density);
		rgb += primary_color.rgb * (inner_edge * 1.5 * clamp(thrust_intensity, 0.4, 2.0));

		if (hit_flash > 0.0) {
			rgb = mix(rgb, vec3(1.0, 0.25, 0.25), hit_flash);
		}

		float dist_gem = length((pilot_uv - core_gem_uv) * vec2(1.0, 1.25));
		if (dist_gem < 0.08) {
			float gem_core = smoothstep(0.038, 0.005, dist_gem);
			float gem_halo = smoothstep(0.075, 0.025, dist_gem);
			float gem_pulse = 0.85 + 0.3 * sin(TIME * 6.0);
			vec3 gem_color = mix(primary_color.rgb * 1.8, secondary_color.rgb * 2.2, gem_core);
			rgb = mix(rgb, gem_color, gem_halo * core_gem_glow * gem_pulse);
			base_alpha = max(base_alpha, gem_halo * 0.95);
		}

		if (silhouette_solidarity > 0.0) {
			vec3 solid_tint = primary_color.rgb * hdr_energy_multiplier;
			rgb = mix(rgb, solid_tint, silhouette_solidarity);
		}
	}

	vec4 result = mix(flame_color, vec4(rgb, base_alpha), base_alpha);

	// 6. Toberas de plasma soplete con anillos Mach (Raymarching sobre máscara en base_uv)
	if (enable_thrusters && has_mask) {
		float found_dist = -1.0;
		float lateral_drift = 0.0;
		float side_sign = sign(base_uv.x - 0.5);

		const int STEPS = 20;
		for (int i = 0; i < STEPS; i++) {
			float step_norm = float(i) / float(STEPS);
			float dy = step_norm * thruster_length;
			float dx = -side_sign * step_norm * thruster_angle;
			vec2 check_uv = vec2(base_uv.x + dx, base_uv.y - dy);
			
			if (check_uv.y >= 0.0 && check_uv.y <= 1.0 && check_uv.x >= 0.0 && check_uv.x <= 1.0) {
				vec4 sm = texture(mask_texture, check_uv);
				if (sm.r > 0.8 && sm.g > 0.8 && sm.b > 0.8) {
					found_dist = step_norm;
					lateral_drift = dx;
					break;
				}
			}
		}

		if (found_dist >= 0.0) {
			float dist_y = found_dist;
			float taper = 1.0 - dist_y;
			float current_width = thruster_width * (0.35 + 0.9 * sin(dist_y * 3.14159));
			float dist_x_norm = abs(lateral_drift) / max(current_width, 0.001);

			float mach_rings = sin((base_uv.y * 130.0) - (TIME * thruster_speed)) * 0.15 + 0.85;
			vec2 n_uv = vec2(base_uv.x * 40.0, (base_uv.y - TIME * thruster_speed * 0.04) * 25.0);
			float gas_noise = procedural_noise(n_uv) * 0.3 + 0.7;

			float outer_mask = smoothstep(1.3, 0.0, dist_x_norm) * pow(taper, 0.8) * gas_noise;
			vec4 gas_outer_theme = primary_color;
			vec4 gas_deep_theme = vec4(primary_color.rgb * 0.35, 0.5);
			vec4 outer_flame = mix(gas_deep_theme, gas_outer_theme, smoothstep(0.2, 0.7, outer_mask));
			outer_flame.a = smoothstep(0.05, 0.4, outer_mask);

			float core_mask = smoothstep(0.5, 0.0, dist_x_norm) * smoothstep(0.65, 0.0, dist_y) * mach_rings;
			vec4 core_flame = thruster_core_color;
			core_flame.a = smoothstep(0.1, 0.7, core_mask);

			vec4 final_gas = mix(outer_flame, core_flame, core_flame.a);
			if (final_gas.a > 0.0) {
				result = mix(result, final_gas, final_gas.a * 0.9);
				result.rgb += final_gas.rgb * final_gas.a * 2.0;
			}
		}
	}

	COLOR = result;
}
