shader_type canvas_item;
render_mode blend_add, unshaded;

/**
 * hyperspace_corridor_particle.gdshader
 * Shader GPU unificado para el MultiMeshInstance2D aditivo de corredores interestelares (Cosmos Engine v3.2c).
 * Modos vía INSTANCE_CUSTOM.r:
 *   < 0.5 : Baliza de navegación hiperespacial en cascada (phase = g)
 *   < 1.5 : Micro-convoy en tránsito con cabeza y estela cónica (+X = adelante)
 *   >=1.5 : Micro-meteoro / estrella fugaz local (+X = adelante, fade = b)
 */

uniform float global_time = -1.0;
uniform int quality_level : hint_range(0, 2) = 2;

varying vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
}

void fragment() {
	float t = (global_time >= 0.0) ? global_time : TIME;
	float mode = v_custom.r;
	float phase = v_custom.g;
	float life_alpha = clamp(v_custom.b, 0.0, 1.5);

	vec3 base_col = COLOR.rgb;
	vec3 col = vec3(0.0);

	if (mode < 0.5) {
		// 1. Baliza guía hiperespacial
		vec2 p = UV - vec2(0.5);
		float r = length(p);
		if (r >= 0.49) {
			discard;
		}
		float env = 1.0 - smoothstep(0.32, 0.488, r);
		float pulse = 0.58 + 0.42 * sin(t * 2.5 - phase);
		float core = exp(-r * 15.0) * 1.15;
		float halo = exp(-r * 6.0) * 0.34;
		float ring = exp(-pow((r - 0.24) / 0.032, 2.0)) * 0.28;
		float flare = (quality_level >= 1)
			? (exp(-abs(p.y) * 34.0) * exp(-abs(p.x) * 9.0) + exp(-abs(p.x) * 34.0) * exp(-abs(p.y) * 9.0)) * 0.38
			: 0.0;
		col = mix(base_col, vec3(0.96, 0.99, 1.0), 0.35) * ((core + halo + flare + ring) * pulse * env);
	} else if (mode < 1.5) {
		// 2. Micro-convoy interestelar (+X = frente en UV.x = 0.84)
		float box_env = smoothstep(0.02, 0.14, UV.x) * (1.0 - smoothstep(0.84, 0.98, UV.x))
			* smoothstep(0.04, 0.24, UV.y) * (1.0 - smoothstep(0.76, 0.96, UV.y));
		if (box_env <= 0.002) {
			discard;
		}
		float head_x = 0.84;
		float rel_y = abs(UV.y - 0.5);
		float d_head = length(vec2((UV.x - head_x) * 1.4, rel_y * 2.0));
		float head = exp(-d_head * 20.0) * 1.25;

		float back = clamp((head_x - UV.x) / 0.74, 0.0, 1.0);
		float in_wake = step(UV.x, head_x + 0.04);
		float wake_w = mix(0.032, 0.12, back);
		float wake_core = exp(-pow(rel_y / wake_w, 2.0)) * pow(1.0 - back, 1.35) * in_wake;
		float ripple = 0.82 + 0.18 * sin(UV.x * 28.0 - t * 6.5 + phase);
		col = mix(base_col, vec3(1.0, 0.97, 0.92), 0.55) * (head + wake_core * 0.72 * ripple) * box_env;
	} else {
		// 3. Micro-meteoro / estrella fugaz local (+X = frente en UV.x = 0.88)
		if (life_alpha <= 0.01) {
			discard;
		}
		float box_env = smoothstep(0.02, 0.12, UV.x) * (1.0 - smoothstep(0.86, 0.98, UV.x))
			* smoothstep(0.08, 0.28, UV.y) * (1.0 - smoothstep(0.72, 0.92, UV.y));
		if (box_env <= 0.002) {
			discard;
		}
		float head_x = 0.88;
		float rel_y = abs(UV.y - 0.5);
		float back = clamp((head_x - UV.x) / 0.78, 0.0, 1.0);
		float in_streak = step(UV.x, head_x + 0.02);
		float line_w = mix(0.028, 0.09, back);
		float streak = exp(-pow(rel_y / line_w, 2.0)) * pow(1.0 - back, 1.6) * in_streak;
		float tip = exp(-length(vec2(UV.x - head_x, rel_y * 2.2)) * 28.0) * 1.4;
		col = mix(base_col, vec3(0.95, 0.99, 1.0), 0.65) * ((streak * 0.85 + tip * 1.20) * box_env * life_alpha);
	}

	col *= COLOR.a;
	float peak = max(col.r, max(col.g, col.b));
	if (peak <= 0.002) {
		discard;
	}
	COLOR = vec4(col, 1.0);
}
