shader_type canvas_item;
render_mode blend_mix;

// --- Parámetros de Propulsión y Vuelo ---
uniform vec4 primary_color : source_color = vec4(0.2, 0.75, 1.0, 1.0);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float thrust_intensity : hint_range(0.0, 3.5) = 1.0;
uniform float speed_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float bank_tilt : hint_range(-1.0, 1.0) = 0.0;

// --- Parámetros de Realce Estético ---
uniform float holo_glow_power : hint_range(0.0, 2.5) = 0.7;
uniform float chromatic_offset : hint_range(0.0, 0.025) = 0.005;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;

// --- Reactor / Gema de HitboxCore ---
uniform float core_gem_glow : hint_range(0.0, 3.0) = 1.2;
uniform vec2 core_gem_uv = vec2(0.5, 0.50);

varying vec2 v_custom_uv;
varying float v_extra_y_ratio;

// Función de ruido pseudo-aleatorio para plasma procedural
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float plasma_noise(vec2 uv, float time) {
	vec2 p = uv * 8.0 + vec2(0.0, -time * 16.0);
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	// 1. Inclinación lateral (Banking tilt)
	VERTEX.x += bank_tilt * (VERTEX.y + 128.0) * 0.15;

	// 2. Expansión vertical inferior para la pluma de propulsión
	// Para un sprite estándar de 256x256 centrado en (0,0):
	// VERTEX.y va de -128 a +128.
	float extra_pixels = 72.0 * clamp(thrust_intensity, 0.35, 2.6);
	if (VERTEX.y > 0.0) {
		VERTEX.y += extra_pixels;
	}

	// 3. Remapeo de UV para mantener el sprite pixel-perfect
	float total_height = 256.0 + extra_pixels;
	float max_mapped_y = total_height / 256.0;
	v_extra_y_ratio = max_mapped_y;

	if (VERTEX.y <= 0.0) {
		v_custom_uv = UV;
	} else {
		v_custom_uv = vec2(UV.x, max_mapped_y);
	}
}

void fragment() {
	vec2 uv = v_custom_uv;
	
	// =========================================================================
	// REGIÓN 1: SPRITE DE LA PILOTA (uv.y <= 1.0)
	// =========================================================================
	if (uv.y <= 1.0) {
		// Aberración cromática sutil en los bordes
		float chrom_dist = chromatic_offset * (0.6 + 0.4 * thrust_intensity);
		float r = texture(TEXTURE, uv + vec2(-chrom_dist, 0.0)).r;
		vec4 g_color = texture(TEXTURE, uv);
		float b = texture(TEXTURE, uv + vec2(chrom_dist, 0.0)).b;
		
		vec4 base_color = vec4(r, g_color.g, b, g_color.a);
		
		// Detección de contorno para Rim-Light Holográfico
		vec2 px = TEXTURE_PIXEL_SIZE * 2.0;
		float a_up = texture(TEXTURE, uv + vec2(0.0, -px.y)).a;
		float a_down = texture(TEXTURE, uv + vec2(0.0, px.y)).a;
		float a_left = texture(TEXTURE, uv + vec2(-px.x, 0.0)).a;
		float a_right = texture(TEXTURE, uv + vec2(px.x, 0.0)).a;
		float edge = clamp((a_up + a_down + a_left + a_right) - (base_color.a * 3.8), 0.0, 1.0);
		
		// Pulso holográfico en los bordes
		float holo_pulse = 0.75 + 0.25 * sin(TIME * 4.0 + uv.y * 10.0);
		vec3 rgb = base_color.rgb;
		
		if (base_color.a > 0.01) {
			// Resplandor de contorno / Rim Light con el color de la piloto
			rgb += primary_color.rgb * (edge * holo_pulse * holo_glow_power);
			
			// Brillo especular cibernético sutil según empuje
			rgb += secondary_color.rgb * (0.08 * thrust_intensity * (1.0 - uv.y));
			
			// Flash de impacto (daño recibido)
			if (hit_flash > 0.0) {
				rgb = mix(rgb, vec3(1.0, 0.2, 0.2), hit_flash);
			}
		}
		
		// Reactor / Gema de HitboxCore en el pecho
		float dist_gem = length((uv - core_gem_uv) * vec2(1.0, 1.25));
		if (dist_gem < 0.08) {
			float gem_core = smoothstep(0.040, 0.005, dist_gem);
			float gem_halo = smoothstep(0.075, 0.025, dist_gem);
			float gem_pulse = 0.85 + 0.3 * sin(TIME * 6.0);
			
			vec3 gem_color = mix(primary_color.rgb * 1.5, secondary_color.rgb * 2.0, gem_core);
			rgb = mix(rgb, gem_color, gem_halo * core_gem_glow * gem_pulse);
			base_color.a = max(base_color.a, gem_halo * 0.95);
		}
		
		COLOR = vec4(rgb, base_color.a);
	}
	// =========================================================================
	// REGIÓN 2: PLUMA DE PROPULSIÓN DE PLASMA PROCEDURAL (uv.y > 1.0)
	// =========================================================================
	else {
		float plume_y = (uv.y - 1.0) / max(0.001, (v_extra_y_ratio - 1.0)); // 0.0 a 1.0 a lo largo de la pluma
		
		// Toberas dobles en las botas/mochila: tobera izquierda en x=0.42, derecha en x=0.58
		// Más un núcleo central en x=0.50
		float x_left = abs(uv.x - 0.42);
		float x_right = abs(uv.x - 0.58);
		float x_center = abs(uv.x - 0.50);
		
		// Ancho dinámico de los chorros según intensidad
		float jet_width = 0.075 * (0.8 + 0.3 * thrust_intensity);
		float cone_left = smoothstep(jet_width, 0.005, x_left + plume_y * 0.06);
		float cone_right = smoothstep(jet_width, 0.005, x_right + plume_y * 0.06);
		float cone_center = smoothstep(jet_width * 1.3, 0.01, x_center + plume_y * 0.09) * 0.8;
		
		float plume_mask = max(max(cone_left, cone_right), cone_center);
		
		// Ruido de plasma en movimiento vertical
		float n = plasma_noise(vec2(uv.x * 2.0, plume_y), TIME * (1.2 + thrust_intensity * 0.8));
		
		// Caída longitudinal de la llama
		float falloff = pow(1.0 - plume_y, 1.4 - clamp(thrust_intensity * 0.25, 0.0, 0.8));
		
		// Modulación según estado (Idle vs Vuelo vs Dash)
		float flame_power = plume_mask * falloff * (0.35 + 0.65 * n);
		flame_power *= clamp(thrust_intensity, 0.15, 3.0);
		
		// Color: núcleo ardiente (blanco/secundario) a color característico (primario)
		vec3 plasma_rgb = mix(primary_color.rgb, secondary_color.rgb * 1.6, pow(flame_power, 1.8));
		
		// En dash/sobrecarga, añadir un destello extra
		if (thrust_intensity > 1.6) {
			plasma_rgb += primary_color.rgb * (sin(TIME * 25.0) * 0.3 + 0.3);
		}
		
		float final_alpha = clamp(flame_power * 1.4, 0.0, 1.0);
		COLOR = vec4(plasma_rgb, final_alpha);
	}
}
