shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Shader Cel-Shading ArcSys 3D dedicado para Alas "Astral Seraph" (3D Lab — Valentina v2).
// Combina:
// - Rampas de 3 bandas cel-shaded calibradas a la paleta Cosmos / 02_valentina_razor_sharp
// - Tinta interna de aristas (crease ink vía fwidth(NORMAL)) para líneas de faceta cristalina
// - Canales rojos HDR con flujo energético animado raíz→punta (UV2.y) y núcleo joya nítido
// - Rebote luminoso carmesí sobre las placas plata adyacentes

uniform int material_kind = 0; // 0 = cristal plata, 1 = marco tinta/chasis oscuro, 2 = canal/punta rubí HDR
uniform vec4 base_color : source_color = vec4(0.92, 0.95, 1.0, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.46, 0.50, 0.72, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 key_light_dir = vec3(-0.48, 0.68, 0.55);
uniform vec4 key_light_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float key_light_boost : hint_range(0.3, 2.0) = 1.04;

uniform vec4 rim_color : source_color = vec4(0.88, 0.96, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 1.8) = 0.68;
uniform float specular_sweep_strength : hint_range(0.0, 1.5) = 0.52;

// Tinta interna en aristas duras de facetas (estilo Ink SDF 2x de Valentina)
uniform float crease_ink_strength : hint_range(0.0, 1.0) = 0.72;
uniform float crease_ink_threshold : hint_range(0.10, 0.90) = 0.28;
uniform vec4 crease_ink_color : source_color = vec4(0.045, 0.040, 0.095, 1.0);

// Canales rojos HDR + flujo de energía raíz→punta + rebote carmesí en placas plata
uniform float emissive_boost : hint_range(0.3, 3.5) = 1.35;
uniform float channel_glow_strength : hint_range(0.0, 3.0) = 1.35;
uniform float energy_flow_time = 0.0;
uniform float energy_flow_speed : hint_range(0.0, 8.0) = 2.6;
uniform float energy_flow_amp : hint_range(0.0, 1.0) = 0.38;
uniform float crimson_bounce_strength : hint_range(0.0, 1.2) = 0.34;

uniform float orbit_depth : hint_range(-1.0, 1.0) = 0.0;
uniform float depth_back_dim : hint_range(0.0, 0.8) = 0.22;
uniform vec4 depth_back_tint : source_color = vec4(0.32, 0.36, 0.62, 1.0);

uniform float fire_flash : hint_range(0.0, 2.5) = 0.0;
uniform vec4 fire_glow_color : source_color = vec4(0.98, 0.16, 0.34, 1.0);

varying float v_blade_u;
varying vec3 v_local_n;

void vertex() {
	v_blade_u = UV2.y;
	v_local_n = NORMAL;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	vec3 l = normalize(key_light_dir);
	float ndl = dot(n, l);
	float ndv = clamp(abs(dot(n, v)), 0.0, 1.0);

	// Onda energética viajando desde la raíz (0.0) hacia la punta rubí (1.0)
	float flow_wave = 0.5 + 0.5 * sin(v_blade_u * 8.5 - energy_flow_time * energy_flow_speed);
	float tip_bias = smoothstep(0.58, 1.0, v_blade_u);
	float energy_pulse = (1.0 - energy_flow_amp * 0.45) + flow_wave * energy_flow_amp + tip_bias * 0.28;

	vec3 rgb = base_color.rgb;

	if (material_kind == 2) {
		// Canales y punta rubí cristalina: núcleo joya de alto contraste + emisión HDR real bajo AgX
		float band_mid = smoothstep(-0.22, -0.04, ndl);
		float band_hi = smoothstep(0.36, 0.52, ndl);
		vec3 c_sh = base_color.rgb * vec3(0.45, 0.26, 0.42);
		vec3 c_mid = base_color.rgb * 1.18;
		vec3 c_hi = mix(base_color.rgb * 1.42, vec3(1.0, 0.82, 0.88), 0.48);
		rgb = mix(c_sh, c_mid, band_mid);
		rgb = mix(rgb, c_hi, band_hi);

		// Emisión HDR calibrada para encender Bloom suavemente en reposo y explotar en Boost/Burst
		float hdr_emit = channel_glow_strength * emissive_boost * energy_pulse;
		vec3 hot_core = mix(fire_glow_color.rgb, vec3(1.0, 0.45, 0.58), clamp(flow_wave * 0.45 + tip_bias * 0.35, 0.0, 0.75));
		rgb += hot_core * (0.58 * hdr_emit + fire_flash * 1.65);

		// Brillo especular afilado sobre facetas del cristal rubí
		vec3 h = normalize(l + v);
		float spec_c = smoothstep(0.84, 0.92, max(dot(n, h), 0.0)) * 0.55;
		rgb += vec3(1.0, 0.86, 0.92) * spec_c;
	} else if (material_kind == 1) {
		// Marco de tinta oscura / canal tallado: mantiene contraste ultra-limpio junto al canal rojo
		float band_mid = smoothstep(-0.05, 0.15, ndl);
		vec3 dark_ink = mix(crease_ink_color.rgb, base_color.rgb * 0.52, 0.55);
		vec3 dark_lit = mix(base_color.rgb * 0.78, fire_glow_color.rgb * 0.28, 0.22);
		rgb = mix(dark_ink, dark_lit, band_mid);
		rgb += fire_glow_color.rgb * (0.08 * channel_glow_strength * energy_pulse + fire_flash * 0.18);
	} else {
		// Placas cristalinas blanco-plata hielo (cel-shading 3 bandas nítidas estilo ArcSys)
		float band_mid = smoothstep(-0.06, 0.03, ndl);
		float band_hi = smoothstep(0.60, 0.70, ndl);

		vec3 c_sh = base_color.rgb * shadow_tint.rgb;
		vec3 c_mid = base_color.rgb * key_light_tint.rgb * key_light_boost;
		vec3 c_hi = mix(base_color.rgb * 1.18 * key_light_tint.rgb * key_light_boost, highlight_color.rgb, 0.52);

		rgb = mix(c_sh, c_mid, band_mid);
		rgb = mix(rgb, c_hi, band_hi);

		// Especular metálico-cristalino filoso
		vec3 h = normalize(l + v);
		float ndh = max(dot(n, h), 0.0);
		float spec = smoothstep(0.85, 0.92, ndh) * specular_sweep_strength;
		rgb += mix(base_color.rgb, highlight_color.rgb, 0.8) * spec * key_light_boost;

		// Rebote sutil de luz carmesí desde los canales rojos sobre las facetas plata cercanas
		float bounce_mask = (0.35 + 0.65 * (1.0 - band_mid)) * (0.45 + 0.55 * tip_bias);
		float bounce_amt = crimson_bounce_strength * channel_glow_strength * 0.26 * energy_pulse + fire_flash * 0.30;
		rgb += fire_glow_color.rgb * bounce_mask * bounce_amt;

		// Tinta interna en aristas duras entre facetas (reproduce el Ink SDF 2x en 3D)
		if (crease_ink_strength > 0.001) {
			float n_grad = length(fwidth(v_local_n));
			float crease = smoothstep(crease_ink_threshold, crease_ink_threshold + 0.26, n_grad);
			// Atenuar ligeramente la tinta interna en zonas de brillo especular extremo
			float crease_amt = crease * crease_ink_strength * (1.0 - spec * 0.65) * 0.85;
			rgb = mix(rgb, crease_ink_color.rgb, crease_amt);
		}
	}

	// Rim-light dual: blanco-hielo en el lado iluminado + leve contra-rim carmesí
	float rim = smoothstep(0.42, 0.82, pow(1.0 - ndv, 2.3)) * rim_strength;
	float front_boost = mix(0.50, 1.18, orbit_depth * 0.5 + 0.5);
	if (material_kind != 1) {
		float key_rim_mask = smoothstep(-0.25, 0.45, ndl);
		vec3 dual_rim = mix(fire_glow_color.rgb * 0.65, rim_color.rgb, key_rim_mask);
		rgb += dual_rim * rim * front_boost * 0.82;
	}

	// Atenuación atmosférica sutil cuando la cuchilla pasa detrás del piloto
	float back_factor = clamp(-orbit_depth, 0.0, 1.0);
	if (back_factor > 0.001 && depth_back_dim > 0.001) {
		float dim_amt = back_factor * depth_back_dim;
		rgb = mix(rgb, rgb * depth_back_tint.rgb, dim_amt * 0.78);
		rgb *= (1.0 - dim_amt * 0.28);
	}

	ALBEDO = rgb;
}
