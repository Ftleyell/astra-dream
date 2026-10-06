shader_type canvas_item;

uniform sampler2D mask_texture : hint_default_black, filter_nearest;
uniform bool has_mask = false;

// Coletas / Cabello
uniform vec2 hair_dir = vec2(1.0, 0.0); // (1, 0) horizontal, (0, 1) vertical
uniform float wind_speed : hint_range(0.0, 30.0) = 15.0;
uniform float wave_freq : hint_range(0.0, 40.0) = 16.0;
uniform float hair_amp : hint_range(0.0, 0.06) = 0.02;

// Inercia de piernas
uniform float leg_bend : hint_range(-0.25, 0.25) = 0.0;

// Propulsores
uniform bool enable_thrusters = true;
uniform float thruster_length : hint_range(0.1, 0.8) = 0.44;
uniform float thruster_width : hint_range(0.01, 0.15) = 0.045;
uniform float thruster_speed : hint_range(10.0, 100.0) = 55.0;
uniform float thruster_angle : hint_range(0.0, 0.3) = 0.08;

uniform vec4 gas_core_white : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 gas_outer_blue : source_color = vec4(0.02, 0.35, 1.0, 0.95);
uniform vec4 gas_deep_blue  : source_color = vec4(0.0, 0.12, 0.7, 0.5);

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
	
	if (!has_mask) {
		COLOR = texture(TEXTURE, uv);
	} else {
		vec4 mask = texture(mask_texture, uv);

		// 1. Cabello (R: Mechón 1, B: Mechón 2)
		float is_hair_r = step(0.4, mask.r) * step(mask.g, 0.2);
		float is_hair_l = step(0.4, mask.b) * step(mask.g, 0.2);
		float wave_r = sin((uv.y * wave_freq) + (TIME * wind_speed)) * hair_amp * is_hair_r;
		float wave_l = sin((uv.y * wave_freq) + (TIME * wind_speed) + 1.7) * hair_amp * is_hair_l;

		// 2. Curvatura de piernas (Inercia contraria)
		float leg_progress = clamp((uv.y - 0.45) / 0.50, 0.0, 1.0);
		float leg_curve = pow(leg_progress, 1.8) * leg_bend;

		// Desplazamiento compuesto
		vec2 final_uv = uv;
		final_uv.x -= leg_curve;
		final_uv += hair_dir * (wave_r + wave_l);

		vec4 sprite_col = texture(TEXTURE, final_uv);
		if (final_uv.x < 0.0 || final_uv.x > 1.0 || final_uv.y < 0.0 || final_uv.y > 1.0) {
			sprite_col = vec4(0.0);
		}

		// 3. Propulsores tipo soplete
		vec4 flame_col = vec4(0.0);
		if (enable_thrusters) {
			float found_dist = -1.0;
			float lateral_drift = 0.0;
			float side_sign = sign(uv.x - 0.5);

			const int STEPS = 20;
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
				float dist_y = found_dist;
				float taper = 1.0 - dist_y;
				float current_width = thruster_width * (0.35 + 0.9 * sin(dist_y * 3.14159));
				float dist_x_norm = abs(lateral_drift) / max(current_width, 0.001);

				float mach_rings = sin((uv.y * 130.0) - (TIME * thruster_speed)) * 0.15 + 0.85;
				vec2 n_uv = vec2(uv.x * 40.0, (uv.y - TIME * thruster_speed * 0.04) * 25.0);
				float gas_noise = get_noise(n_uv) * 0.3 + 0.7;

				float outer_mask = smoothstep(1.3, 0.0, dist_x_norm) * pow(taper, 0.8) * gas_noise;
				vec4 outer_flame = mix(gas_deep_blue, gas_outer_blue, smoothstep(0.2, 0.7, outer_mask));
				outer_flame.a = smoothstep(0.05, 0.4, outer_mask);

				float core_mask = smoothstep(0.5, 0.0, dist_x_norm) * smoothstep(0.65, 0.0, dist_y) * mach_rings;
				vec4 core_flame = gas_core_white;
				core_flame.a = smoothstep(0.1, 0.7, core_mask);

				vec4 final_gas = mix(outer_flame, core_flame, core_flame.a);
				flame_col = final_gas;
			}
		}

		vec4 result = mix(sprite_col, flame_col, flame_col.a * 0.9);
		result.rgb += flame_col.rgb * flame_col.a * 2.0;
		COLOR = result;
	}
}