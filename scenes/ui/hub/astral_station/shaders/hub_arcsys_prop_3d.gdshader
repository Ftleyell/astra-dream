shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Shader Cel-Shading ArcSys 3D Elevado para Islas, Quillas y Props del Hub.
// - Soporta Trim-Sheet PBR (Normal Map Tangent-Space, ORM, Ink SDF 2x sin mipmaps).
// - Recibe tintes dinámicos en tiempo real desde CosmicLightingSampler.
// - Implementa barrido radial de Desmaterialización Tecnológica con grilla hexagonal HDR.

uniform int material_kind = 0; // 0 = armadura titanio, 1 = chasis/tinta oscura, 2 = canal/núcleo HDR
uniform vec4 base_color : source_color = vec4(0.46, 0.52, 0.66, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.32, 0.36, 0.58, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 pilot_accent_color : source_color = vec4(0.95, 0.16, 0.34, 1.0);
uniform vec4 rim_color : source_color = vec4(0.62, 0.88, 1.0, 1.0);
uniform bool use_pilot_accent = true;

uniform bool has_trim_maps = false;
uniform sampler2D trim_normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D trim_orm_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D trim_ink_sdf_tex : filter_linear, repeat_enable;
uniform vec2 trim_uv_scale = vec2(1.0, 1.0);
uniform vec2 trim_native_size = vec2(1024.0, 1024.0);
uniform float normal_strength : hint_range(0.0, 2.0) = 0.85;
uniform float trim_ink_strength : hint_range(0.0, 1.0) = 0.65;

uniform float crease_ink_strength : hint_range(0.0, 1.0) = 0.58;
uniform float crease_ink_threshold : hint_range(0.10, 0.90) = 0.44;
uniform vec4 crease_ink_color : source_color = vec4(0.040, 0.036, 0.088, 1.0);

uniform float emissive_boost : hint_range(0.0, 4.0) = 1.65;
uniform float energy_flow_speed : hint_range(0.0, 8.0) = 2.4;
uniform float energy_flow_amp : hint_range(0.0, 1.0) = 0.35;
uniform float crimson_bounce_strength : hint_range(0.0, 1.2) = 0.24;
uniform float ambient_fill : hint_range(0.0, 0.9) = 0.24;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.46;
uniform float halftone_strength : hint_range(0.0, 1.0) = 0.18;

// Iluminación viva acoplada a CosmicLightingSampler
uniform vec4 cosmic_key_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cosmic_shadow_tint : source_color = vec4(0.24, 0.28, 0.46, 1.0);
uniform vec4 cosmic_rim_color : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float cosmic_light_mix : hint_range(0.0, 1.0) = 0.55;

// Progresión de estación: 0.0 = ONLINE, 1.0 = CALIBRATING
uniform float calibration_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec4 calibrating_tint : source_color = vec4(0.32, 0.36, 0.48, 1.0);
uniform vec4 calibrating_amber : source_color = vec4(0.92, 0.62, 0.18, 1.0);
uniform float newly_unlocked_pulse : hint_range(0.0, 1.5) = 0.0;

// Desmaterialización Tecnológica
uniform float demat_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 demat_origin = vec3(0.0);
uniform float demat_max_radius = 30.0;
uniform float demat_hex_scale = 2.4;
uniform vec4 demat_edge_color : source_color = vec4(0.15, 0.95, 1.0, 1.0);

varying float v_prop_u;
varying vec3 v_local_n;
varying float v_view_dist;
varying vec3 v_world_pos;

float _hex_cell(vec2 p) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	return max(abs(gv.x), dot(abs(gv), normalize(r)));
}

void vertex() {
	v_prop_u = UV2.y;
	v_local_n = NORMAL;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_view_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float demat_edge = 0.0;
	float hex_wire = 0.0;
	if (demat_progress > 0.001) {
		float d_origin = length(v_world_pos.xz - demat_origin.xz);
		float hex_d = _hex_cell(v_world_pos.xz * demat_hex_scale);
		float wave_r = mix(-2.5, demat_max_radius, demat_progress);
		float signed_wave = (d_origin + hex_d * 1.1) - wave_r;
		if (signed_wave < 0.0) {
			discard;
		}
		demat_edge = 1.0 - smoothstep(0.0, 2.2, signed_wave);
		hex_wire = smoothstep(0.38, 0.48, hex_d) * (1.0 - smoothstep(2.2, 4.8, signed_wave));
	}

	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float ndv = clamp(abs(dot(n, v)), 0.0, 1.0);
	vec3 eff_rim_col = mix(rim_color.rgb, cosmic_rim_color.rgb, cosmic_light_mix);
	float rim_w = pow(1.0 - ndv, 2.8) * rim_strength;

	vec3 accent = use_pilot_accent ? pilot_accent_color.rgb : base_color.rgb;
	float flow_wave = 0.5 + 0.5 * sin(v_prop_u * 8.0 - TIME * energy_flow_speed);
	float energy_pulse = (1.0 - energy_flow_amp * 0.45) + flow_wave * energy_flow_amp;

	vec3 prop_albedo = base_color.rgb;
	vec3 prop_emissive = vec3(0.0);
	float rough_out = (material_kind == 1) ? 0.82 : 0.26;
	float metal_out = (material_kind == 0) ? 0.16 : 0.0;
	float ao_out = 1.0;

	if (has_trim_maps && material_kind != 2) {
		vec2 tuv = vec2(UV.x * trim_uv_scale.x, clamp(UV.y * trim_uv_scale.y, 0.005, 0.995));
		vec3 orm = texture(trim_orm_tex, tuv).rgb;
		rough_out = mix(0.46, max(orm.r, 0.42), 0.65);
		ao_out = mix(1.0, orm.g, 0.65);
		metal_out = mix(metal_out, orm.b, 0.45);
		NORMAL_MAP = texture(trim_normal_tex, tuv).rgb;
		NORMAL_MAP_DEPTH = normal_strength * 0.72;

		float sdf_s = textureLod(trim_ink_sdf_tex, tuv, 0.0).r;
		float sdf_tex = (sdf_s - 0.5) * 16.0;
		float px_in_tex = max(length(fwidth(tuv * trim_native_size)), 0.001);
		float trim_ink = (1.0 - smoothstep(-0.65, 0.65, sdf_tex / px_in_tex)) * trim_ink_strength;
		prop_albedo = mix(prop_albedo, crease_ink_color.rgb, trim_ink * 0.78);
	}

	if (material_kind == 2) {
		vec3 active_col = mix(accent, calibrating_amber.rgb * 0.65, calibration_factor);
		prop_albedo = active_col;
		float active_hdr = emissive_boost * energy_pulse * 1.15 * (1.0 - calibration_factor * 0.82);
		float standby_led = calibration_factor * (0.20 + 0.14 * sin(TIME * 3.0));
		prop_emissive = active_col * (active_hdr + standby_led + newly_unlocked_pulse * 0.95);
	} else if (material_kind == 1) {
		prop_albedo = mix(crease_ink_color.rgb, prop_albedo * 0.68, 0.58);
		prop_albedo = mix(prop_albedo, calibrating_tint.rgb * 0.52, calibration_factor * 0.55);
		prop_emissive = accent * min(0.04 * (1.0 - calibration_factor), 0.22);
	} else {
		float luma = dot(prop_albedo, vec3(0.299, 0.587, 0.114));
		vec3 cal_col = mix(vec3(luma) * calibrating_tint.rgb * 1.35, calibrating_tint.rgb, 0.45);
		prop_albedo = mix(prop_albedo, cal_col, calibration_factor * 0.78);

		if (crease_ink_strength > 0.001) {
			float n_grad = length(fwidth(v_local_n));
			float crease = smoothstep(crease_ink_threshold, crease_ink_threshold + 0.30, n_grad);
			float dist_atten = 1.0 / (1.0 + v_view_dist * 0.055);
			prop_albedo = mix(prop_albedo, crease_ink_color.rgb, crease * crease_ink_strength * 0.72 * dist_atten);
		}

		float bounce = crimson_bounce_strength * 0.18 * energy_pulse * (1.0 - calibration_factor);
		vec3 raw_emit = accent * (bounce + newly_unlocked_pulse * 0.22) + eff_rim_col * (rim_w * 0.24 * (1.0 - calibration_factor * 0.55));
		prop_emissive += min(raw_emit, vec3(0.28));
	}

	if (material_kind != 2) {
		prop_albedo *= ao_out;
	}

	vec3 eff_shadow = mix(shadow_tint.rgb, cosmic_shadow_tint.rgb, cosmic_light_mix);
	vec3 demat_glow = mix(demat_edge_color.rgb, accent, 0.30) * (demat_edge * 2.8 + hex_wire * 1.35);

	ALBEDO = mix(prop_albedo * mix(vec3(1.0), cosmic_key_tint.rgb, cosmic_light_mix * 0.35), demat_edge_color.rgb, demat_edge * 0.65);
	EMISSION = prop_albedo * eff_shadow * ambient_fill + prop_emissive + demat_glow;
	METALLIC = metal_out;
	ROUGHNESS = rough_out;
	SPECULAR = (material_kind == 0) ? 0.28 : 0.0;
}

void light() {
	float ndotl = max(dot(NORMAL, LIGHT), 0.0);
	float shadow_f = smoothstep(0.12, 0.88, ATTENUATION);
	float band_mid = smoothstep(0.06, 0.30, ndotl) * shadow_f;
	float band_hi = smoothstep(0.52, 0.76, ndotl) * shadow_f;
	float cel_intensity = 0.10 + band_mid * 0.60 + band_hi * 0.24;
	vec3 eff_light = LIGHT_COLOR * mix(vec3(1.0), cosmic_key_tint.rgb, cosmic_light_mix * 0.45);
	if (material_kind != 2) {
		DIFFUSE_LIGHT = min(DIFFUSE_LIGHT + cel_intensity * eff_light, vec3(0.96));
	} else {
		DIFFUSE_LIGHT += cel_intensity * eff_light;
	}

	if (material_kind == 0) {
		vec3 h = normalize(LIGHT + VIEW);
		float ndh = max(dot(NORMAL, h), 0.0);
		float spec = smoothstep(0.82, 0.94, ndh) * band_mid * (1.0 - calibration_factor * 0.60);
		SPECULAR_LIGHT = min(SPECULAR_LIGHT + spec * eff_light * 0.22, vec3(0.28));
	}
}
