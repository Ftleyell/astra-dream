shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded;

// Shader de integración 3D de alta nitidez para avatar 2.5D en el Hub Astral (Forward+):
// - Supersampling RGSS 4-tap guiado por derivadas de pantalla (dFdx/dFdy) con alfa premultiplicada:
//   preserva trazos finos Ink SDF 2x al reducir en FREE_ROAM sin halos negros ni bordes serruchados.
// - Renderizado unshaded + alpha blending limpio (sin ALPHA_SCISSOR duro ni doble iluminación 3D)
//   para igualar la pureza cromática y el cel-shading del combate 2D tras el tonemapper AGX.

uniform sampler2D avatar_tex : source_color, filter_linear, repeat_disable;
uniform vec4 shadow_tint : source_color = vec4(0.34, 0.36, 0.58, 1.0);
uniform vec4 rim_tint : source_color = vec4(1.0, 0.42, 0.62, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.22;
uniform float ambient_floor : hint_range(0.0, 1.5) = 0.56;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	if (opacity <= 0.01) {
		discard;
	}

	// Huella real del píxel en pantalla para muestreo RGSS 4-tap sin difuminar en closeups
	vec2 duv_x = dFdx(UV);
	vec2 duv_y = dFdy(UV);
	vec2 off0 = duv_x * 0.375 + duv_y * 0.125;
	vec2 off1 = -duv_x * 0.375 - duv_y * 0.125;
	vec2 off2 = -duv_x * 0.125 + duv_y * 0.375;
	vec2 off3 = duv_x * 0.125 - duv_y * 0.375;

	vec4 s0 = texture(avatar_tex, clamp(UV + off0, vec2(0.0), vec2(1.0)));
	vec4 s1 = texture(avatar_tex, clamp(UV + off1, vec2(0.0), vec2(1.0)));
	vec4 s2 = texture(avatar_tex, clamp(UV + off2, vec2(0.0), vec2(1.0)));
	vec4 s3 = texture(avatar_tex, clamp(UV + off3, vec2(0.0), vec2(1.0)));

	float a_sum = s0.a + s1.a + s2.a + s3.a;
	float a_avg = a_sum * 0.25;
	float alpha_out = a_avg * opacity;
	if (alpha_out < 0.005) {
		discard;
	}

	vec3 rgb_premul = s0.rgb * s0.a + s1.rgb * s1.a + s2.rgb * s2.a + s3.rgb * s3.a;
	vec3 clean_rgb = rgb_premul / max(a_sum, 0.0001);

	// Rim light sutil únicamente sobre el contorno real sin lavar la piel ni la tinta
	vec2 ts = vec2(1.6) / max(vec2(textureSize(avatar_tex, 0)), vec2(512.0));
	float a_l = texture(avatar_tex, clamp(UV + vec2(-ts.x, 0.0), vec2(0.0), vec2(1.0))).a;
	float a_r = texture(avatar_tex, clamp(UV + vec2(ts.x, 0.0), vec2(0.0), vec2(1.0))).a;
	float a_u = texture(avatar_tex, clamp(UV + vec2(0.0, -ts.y), vec2(0.0), vec2(1.0))).a;
	float a_d = texture(avatar_tex, clamp(UV + vec2(0.0, ts.y), vec2(0.0), vec2(1.0))).a;
	float min_nb = min(min(a_l, a_r), min(a_u, a_d));
	float rim_edge = clamp((a_avg - min_nb) * 1.15, 0.0, 1.0);
	float top_bias = clamp(1.10 - UV.y * 0.65, 0.25, 1.0);
	vec3 rim_glow = rim_tint.rgb * rim_edge * rim_strength * top_bias * 0.45 * clamp(ambient_floor + 0.44, 0.6, 1.1);

	// Compensación sutil de contraste para preservar cel-shading 2D intacto bajo AGX
	vec3 harmony = mix(vec3(1.0), clamp(shadow_tint.rgb * 1.45, vec3(0.84), vec3(1.12)), 0.14);
	ALBEDO = clean_rgb * harmony * 1.06 + rim_glow;
	ALPHA = clamp(alpha_out, 0.0, 1.0);
}
