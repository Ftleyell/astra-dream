shader_type canvas_item;

uniform sampler2D mask_texture : hint_default_black, filter_nearest;

// Coletas
uniform float wind_speed : hint_range(0.0, 30.0) = 15.0;
uniform float wave_freq : hint_range(0.0, 40.0) = 16.0;
uniform float hair_amp : hint_range(0.0, 0.05) = 0.018;

// Curvatura de piernas
uniform float leg_bend : hint_range(-0.25, 0.25) = 0.0;

// Geometría del Soplete
uniform float thruster_length : hint_range(0.1, 0.8) = 0.44;    // Largo de la llama
uniform float thruster_width : hint_range(0.01, 0.15) = 0.045;   // Grosor total
uniform float thruster_speed : hint_range(10.0, 100.0) = 55.0;   // Velocidad del flujo de gas
uniform float thruster_angle : hint_range(0.0, 0.3) = 0.08;      // Apertura angular hacia afuera

// Colores Soplete de Gas
uniform vec4 gas_core_white : source_color = vec4(1.0, 1.0, 1.0, 1.0);       // Centro blanco puro incandescente
uniform vec4 gas_outer_blue : source_color = vec4(0.02, 0.35, 1.0, 0.95);    // Borde azul fuego eléctrico
uniform vec4 gas_deep_blue  : source_color = vec4(0.0, 0.12, 0.7, 0.5);      // Halo envolvente exterior profundo

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float get_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec4 mask = texture(mask_texture, uv);

	// 1. FLAMEO DE COLETAS
	float is_hair_r = step(0.4, mask.r) * step(mask.g, 0.2);
	float is_hair_l = step(0.4, mask.b) * step(mask.g, 0.2);
	float wave_r = sin((uv.y * wave_freq) + (TIME * wind_speed)) * hair_amp * is_hair_r;
	float wave_l = sin((uv.y * wave_freq) + (TIME * wind_speed) + 1.7) * hair_amp * is_hair_l;

	// 2. CURVATURA EN PIERNAS
	float leg_progress = clamp((uv.y - 0.45) / 0.50, 0.0, 1.0);
	float leg_curve = pow(leg_progress, 1.8) * leg_bend;

	vec2 final_uv = uv;
	final_uv.x -= leg_curve;
	final_uv.x += (wave_r + wave_l);

	vec4 sprite_col = texture(TEXTURE, final_uv);
	if (final_uv.x < 0.0 || final_uv.x > 1.0 || final_uv.y < 0.0 || final_uv.y > 1.0) {
		sprite_col = vec4(0.0);
	}

	// 3. TRAZADO DE LA LLAMA DEL SOPLETE
	vec4 flame_col = vec4(0.0);
	float found_dist = -1.0;
	float lateral_drift = 0.0;

	float side_sign = sign(uv.x - 0.5);

	const int STEPS = 24;
	for (int i = 0; i < STEPS; i++) {
		float step_norm = float(i) / float(STEPS);
		float dy = step_norm * thruster_length;
		float dx = -side_sign * step_norm * thruster_angle;
		
		vec2 check_uv = vec2(uv.x + dx, uv.y - dy);
		
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
		float dist_y = found_dist; // 0.0 en tobera, 1.0 en la punta
		
		// Perfil cónico afilado del dardo
		float taper = 1.0 - dist_y;
		float current_width = thruster_width * (0.35 + 0.9 * sin(dist_y * 3.14159));
		float dist_x_norm = abs(lateral_drift) / max(current_width, 0.001); // 0 en el centro del eje, >1 afuera

		// Turbulencia de alta velocidad y ondas de choque (Mach diamonds en el centro)
		float mach_rings = sin((uv.y * 130.0) - (TIME * thruster_speed)) * 0.15 + 0.85;
		vec2 n_uv = vec2(uv.x * 40.0, (uv.y - TIME * thruster_speed * 0.04) * 25.0);
		float gas_noise = get_noise(n_uv) * 0.3 + 0.7;

		// --- ENVOLVENTE EXTERIOR: FUEGO AZUL VIVO ---
		// Cono exterior que decae suavemente hacia los bordes
		float outer_mask = smoothstep(1.3, 0.0, dist_x_norm) * pow(taper, 0.8) * gas_noise;
		vec4 outer_flame = mix(gas_deep_blue, gas_outer_blue, smoothstep(0.2, 0.7, outer_mask));
		outer_flame.a = smoothstep(0.05, 0.4, outer_mask);

		// --- DARDO INTERNO: NÚCLEO BLANCO DEL SOPLETE ---
		// El dardo blanco es más corto (dura ~60% del largo total) y muy ceñido al centro (dist_x_norm < 0.45)
		float core_length_decay = smoothstep(0.65, 0.0, dist_y);
		float core_mask = smoothstep(0.5, 0.0, dist_x_norm) * core_length_decay * mach_rings;
		core_mask = clamp(core_mask, 0.0, 1.0);
		
		vec4 core_flame = gas_core_white;
		core_flame.a = smoothstep(0.1, 0.7, core_mask);

		// Combinamos: el azul envuelve todo y el núcleo blanco se monta nítido en el centro
		vec4 final_gas = outer_flame;
		final_gas = mix(final_gas, core_flame, core_flame.a);
		
		flame_col = final_gas;
	}

	// 4. COMPOSICIÓN FINAL
	// El soplete se dibuja por encima del sprite con opacidad y resplandor aditivo
	vec4 result = sprite_col;
	result = mix(result, flame_col, flame_col.a * 0.9);
	
	// Adición luminosa: intensifica el blanco central y el resplandor azul saturado
	result.rgb += flame_col.rgb * flame_col.a * 2.0;

	COLOR = result;
}