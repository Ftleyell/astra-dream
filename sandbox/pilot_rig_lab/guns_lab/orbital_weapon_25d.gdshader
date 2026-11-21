shader_type canvas_item;
// Shader 2.5D para armamento en Anillo Orbital (Guns Lab — Valentina v2).
// Combina deformación trapezoidal proyectiva, extrusión 3D multi-tap,
// iluminación especular rotacional, rim-light, atenuación por profundidad y pulso HDR de disparo.

uniform float barrel_z : hint_range(-1.0, 1.0) = 0.0;
uniform float orbit_depth : hint_range(-1.0, 1.0) = 0.0;
uniform float orbit_angle : hint_range(-6.2832, 6.2832) = 0.0;
uniform float pivot_u : hint_range(0.0, 1.0) = 0.44;
uniform float trapezoid_strength : hint_range(0.0, 1.0) = 0.42;
uniform float extrude_depth_px : hint_range(0.0, 16.0) = 5.5;
uniform vec2 extrude_dir = vec2(-0.35, 0.92);
uniform vec4 extrude_tint : source_color = vec4(0.10, 0.16, 0.28, 0.92);
uniform float depth_back_dim : hint_range(0.0, 0.8) = 0.28;
uniform vec4 depth_back_tint : source_color = vec4(0.32, 0.36, 0.62, 1.0);
uniform float rim_strength : hint_range(0.0, 1.5) = 0.55;
uniform vec4 rim_color : source_color = vec4(0.30, 0.92, 1.0, 1.0);
uniform float specular_sweep_strength : hint_range(0.0, 1.5) = 0.38;
uniform float fire_flash : hint_range(0.0, 2.0) = 0.0;
uniform vec4 fire_glow_color : source_color = vec4(0.35, 0.95, 1.0, 1.0);

vec2 warp_trapezoid_uv(vec2 uv) {
	float u_rel = uv.x - pivot_u;
	float v_rel = uv.y - 0.5;
	// w > 1.0 en la boca cuando barrel_z > 0 (boca hacia cámara => se ensancha)
	float w = clamp(1.0 + u_rel * barrel_z * trapezoid_strength * 1.65, 0.35, 2.25);
	float v_mapped = 0.5 + (v_rel / w);
	// Ligero desplazamiento no-lineal en U para reforzar escorzo proyectivo
	float u_mapped = pivot_u + (u_rel / mix(1.0, w, 0.32));
	return vec2(u_mapped, v_mapped);
}

vec4 sample_warped(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, uv);
}

void fragment() {
	vec2 base_uv = warp_trapezoid_uv(UV);
	vec4 front = sample_warped(TEXTURE, base_uv);

	// Extrusión 3D falsa detrás de la cara frontal (se acentúa cuando el arma gira en perspectiva)
	float extrude_factor = mix(0.35, 1.0, abs(barrel_z));
	vec2 px_size = TEXTURE_PIXEL_SIZE;
	vec2 step_uv = extrude_dir * (extrude_depth_px * extrude_factor / 6.0) * px_size;

	vec4 body_col = front;
	if (front.a < 0.92 && extrude_depth_px > 0.05) {
		vec4 ext_acc = vec4(0.0);
		for (int i = 1; i <= 6; i++) {
			vec2 s_uv = warp_trapezoid_uv(UV + step_uv * float(i));
			vec4 s_col = sample_warped(TEXTURE, s_uv);
			if (s_col.a > 0.25) {
				float shade = mix(0.95, 0.42, float(i) / 6.0);
				vec3 ext_rgb = mix(s_col.rgb * 0.48, extrude_tint.rgb, 0.55) * shade;
				float ext_a = s_col.a * extrude_tint.a;
				// Mezcla front-to-back detrás de la cara frontal
				ext_acc.rgb = mix(ext_rgb, ext_acc.rgb, ext_acc.a);
				ext_acc.a = max(ext_acc.a, ext_a);
				break;
			}
		}
		if (ext_acc.a > 0.01) {
			vec3 comp_rgb = mix(ext_acc.rgb, front.rgb, front.a);
			float comp_a = max(front.a, ext_acc.a);
			body_col = vec4(comp_rgb, comp_a);
		}
	}

	if (body_col.a < 0.01) {
		discard;
	}

	vec3 rgb = body_col.rgb;

	// Detectar emisivos cian/azul del propio rifle para darles brillo HDR en disparo y reposo
	float cyan_energy = clamp((rgb.b + rgb.g * 0.85) - rgb.r * 1.45, 0.0, 1.0);
	float energy_mask = smoothstep(0.18, 0.62, cyan_energy);

	// Barrido especular metálico dependiente del ángulo orbital 3D
	float sweep_center = 0.5 + 0.36 * cos(orbit_angle * 1.5);
	float sweep_band = exp(-pow((base_uv.x - sweep_center) * 5.2, 2.0));
	float metallic_mask = (1.0 - energy_mask) * smoothstep(0.10, 0.45, max(rgb.r, max(rgb.g, rgb.b)));
	rgb += vec3(0.75, 0.90, 1.0) * sweep_band * metallic_mask * specular_sweep_strength * (0.65 + 0.35 * orbit_depth);

	// Rim-light en borde superior/frontal (estima gradiente alfa local)
	if (rim_strength > 0.01 && front.a > 0.25) {
		vec2 rim_off = vec2(0.0, -2.0) * px_size;
		float a_up = sample_warped(TEXTURE, warp_trapezoid_uv(UV + rim_off)).a;
		float edge_rim = clamp(front.a - a_up, 0.0, 1.0);
		float front_boost = mix(0.45, 1.15, orbit_depth * 0.5 + 0.5);
		rgb += rim_color.rgb * edge_rim * rim_strength * front_boost;
	}

	// Pulso HDR en canales de energía y cañón al disparar
	if (fire_flash > 0.001) {
		float muzzle_grad = smoothstep(pivot_u, 0.98, base_uv.x);
		rgb += fire_glow_color.rgb * (energy_mask * 0.95 + muzzle_grad * 0.45) * fire_flash;
	} else {
		// Brillo sutil permanente en los núcleos de energía del rifle
		rgb += fire_glow_color.rgb * energy_mask * 0.28;
	}

	// Atenuación atmosférica cuando pasa detrás del piloto (orbit_depth < 0)
	float back_factor = clamp(-orbit_depth, 0.0, 1.0);
	if (back_factor > 0.001 && depth_back_dim > 0.001) {
		float dim_amt = back_factor * depth_back_dim;
		rgb = mix(rgb, rgb * depth_back_tint.rgb, dim_amt * 0.85);
		rgb *= (1.0 - dim_amt * 0.35);
	}

	COLOR = vec4(rgb, body_col.a);
}
