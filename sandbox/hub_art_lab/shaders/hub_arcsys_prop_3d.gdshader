shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Shader Cel-Shading ArcSys 3D para Props del Hub (Cápsula, Consolas, Reliquias, Invocador).
// Evolución directa de astral_wing_toon_3d.gdshader adaptada a luces/sombras reales y estados
// de progresión (CALIBRATING -> NEWLY_UNLOCKED -> ONLINE).

uniform int material_kind = 0; // 0 = armadura titanio, 1 = chasis/tinta oscura, 2 = canal/núcleo HDR
uniform vec4 base_color : source_color = vec4(0.46, 0.52, 0.66, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.32, 0.36, 0.58, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 pilot_accent_color : source_color = vec4(0.95, 0.16, 0.34, 1.0);
uniform vec4 rim_color : source_color = vec4(0.62, 0.88, 1.0, 1.0);
uniform bool use_pilot_accent = true;

uniform float crease_ink_strength : hint_range(0.0, 1.0) = 0.58;
uniform float crease_ink_threshold : hint_range(0.10, 0.90) = 0.28;
uniform vec4 crease_ink_color : source_color = vec4(0.040, 0.036, 0.088, 1.0);

uniform float emissive_boost : hint_range(0.0, 4.0) = 1.65;
uniform float energy_flow_speed : hint_range(0.0, 8.0) = 2.4;
uniform float energy_flow_amp : hint_range(0.0, 1.0) = 0.35;
uniform float crimson_bounce_strength : hint_range(0.0, 1.2) = 0.24;
uniform float ambient_fill : hint_range(0.0, 0.9) = 0.24;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.46;
uniform float halftone_strength : hint_range(0.0, 1.0) = 0.18;

// Progresión de estación: 0.0 = ONLINE, 1.0 = CALIBRATING (desaturado y tenue)
uniform float calibration_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec4 calibrating_tint : source_color = vec4(0.32, 0.36, 0.48, 1.0);
uniform vec4 calibrating_amber : source_color = vec4(0.92, 0.62, 0.18, 1.0);
uniform float newly_unlocked_pulse : hint_range(0.0, 1.5) = 0.0;

varying float v_prop_u;
varying vec3 v_local_n;
varying float v_view_dist;

void vertex() {
	v_prop_u = UV2.y;
	v_local_n = NORMAL;
	v_view_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float ndv = clamp(abs(dot(n, v)), 0.0, 1.0);
	float rim_w = pow(1.0 - ndv, 2.8) * rim_strength;

	vec3 accent = use_pilot_accent ? pilot_accent_color.rgb : base_color.rgb;
	float flow_wave = 0.5 + 0.5 * sin(v_prop_u * 8.0 - TIME * energy_flow_speed);
	float energy_pulse = (1.0 - energy_flow_amp * 0.45) + flow_wave * energy_flow_amp;

	vec3 prop_albedo = base_color.rgb;
	vec3 prop_emissive = vec3(0.0);

	if (material_kind == 2) {
		vec3 active_col = mix(accent, calibrating_amber.rgb * 0.65, calibration_factor);
		prop_albedo = active_col;
		float active_hdr = emissive_boost * energy_pulse * 1.15 * (1.0 - calibration_factor * 0.82);
		float standby_led = calibration_factor * (0.20 + 0.14 * sin(TIME * 3.0));
		prop_emissive = active_col * (active_hdr + standby_led + newly_unlocked_pulse * 0.95);
	} else if (material_kind == 1) {
		prop_albedo = mix(crease_ink_color.rgb, base_color.rgb * 0.68, 0.58);
		prop_albedo = mix(prop_albedo, calibrating_tint.rgb * 0.52, calibration_factor * 0.55);
		prop_emissive = accent * min(0.04 * (1.0 - calibration_factor), 0.22);
	} else {
		float luma = dot(base_color.rgb, vec3(0.299, 0.587, 0.114));
		vec3 cal_col = mix(vec3(luma) * calibrating_tint.rgb * 1.35, calibrating_tint.rgb, 0.45);
		prop_albedo = mix(base_color.rgb, cal_col, calibration_factor * 0.78);

		// Tinta interna en aristas duras entre facetas atenuada suavemente con distancia
		if (crease_ink_strength > 0.001) {
			float n_grad = length(fwidth(v_local_n));
			float crease = smoothstep(crease_ink_threshold, crease_ink_threshold + 0.26, n_grad);
			float dist_atten = 1.0 / (1.0 + v_view_dist * 0.045);
			prop_albedo = mix(prop_albedo, crease_ink_color.rgb, crease * crease_ink_strength * 0.85 * dist_atten);
		}

		// Rebote cromático + rim-light estilo razor sharp estrictamente acotados <= 0.22 (cero bloom en armadura)
		float bounce = crimson_bounce_strength * 0.18 * energy_pulse * (1.0 - calibration_factor);
		vec3 raw_emit = accent * (bounce + newly_unlocked_pulse * 0.22) + rim_color.rgb * (rim_w * 0.20 * (1.0 - calibration_factor * 0.55));
		prop_emissive += min(raw_emit, vec3(0.22));
	}

	ALBEDO = prop_albedo;
	EMISSION = prop_albedo * shadow_tint.rgb * ambient_fill + prop_emissive;
	METALLIC = 0.0;
	ROUGHNESS = (material_kind == 1) ? 0.85 : 0.30;
	SPECULAR = 0.0;
}

void light() {
	float lit = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	float band_mid = smoothstep(0.04, 0.15, lit);
	float band_hi = smoothstep(0.58, 0.70, lit);

	float penumbra = band_mid * (1.0 - band_mid) * 4.0;
	float ht = 0.5 + 0.5 * (sin(FRAGCOORD.x * 0.9) * sin(FRAGCOORD.y * 0.9));
	float cel_intensity = band_mid * 0.64 + band_hi * 0.22;
	cel_intensity *= (1.0 - penumbra * halftone_strength * ht);
	DIFFUSE_LIGHT += cel_intensity * LIGHT_COLOR;

	if (material_kind != 1) {
		vec3 h = normalize(LIGHT + VIEW);
		float ndh = max(dot(NORMAL, h), 0.0);
		float spec = smoothstep(0.86, 0.93, ndh) * band_mid * (1.0 - calibration_factor * 0.65);
		SPECULAR_LIGHT += spec * LIGHT_COLOR * 0.28;
	}
}
