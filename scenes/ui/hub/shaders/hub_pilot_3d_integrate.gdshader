shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Shader de integración 3D real para avatar 2.5D en el Hub Astral (Forward+):
// - Recibe sombras proyectadas y spotlights 3D reales sin perder legibilidad en el rostro.
// - Escribe profundidad opaca vía Alpha Scissor para interactuar con SSAO, SSIL y Volumetric Fog.
// - Sintetiza luz de contorno (rim light) automática a partir del gradiente alpha del SubViewport 1024px.

uniform sampler2D avatar_tex : source_color, filter_linear, repeat_disable;
uniform vec4 shadow_tint : source_color = vec4(0.34, 0.36, 0.58, 1.0);
uniform vec4 rim_tint : source_color = vec4(1.0, 0.42, 0.62, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.44;
uniform float ambient_floor : hint_range(0.0, 1.5) = 0.56;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	if (opacity <= 0.02) {
		discard;
	}
	vec4 c = texture(avatar_tex, UV);
	float alpha_out = c.a * opacity;
	if (alpha_out < 0.08) {
		discard;
	}

	// Rim light de silueta 2.5D desde vecindad alpha del SubViewport (dinámico para cualquier viewport_size)
	vec2 ts = vec2(2.2) / max(vec2(textureSize(avatar_tex, 0)), vec2(256.0));
	float a_l = texture(avatar_tex, clamp(UV + vec2(-ts.x, 0.0), vec2(0.0), vec2(1.0))).a;
	float a_r = texture(avatar_tex, clamp(UV + vec2(ts.x, 0.0), vec2(0.0), vec2(1.0))).a;
	float a_u = texture(avatar_tex, clamp(UV + vec2(0.0, -ts.y), vec2(0.0), vec2(1.0))).a;
	float a_d = texture(avatar_tex, clamp(UV + vec2(0.0, ts.y), vec2(0.0), vec2(1.0))).a;
	float min_nb = min(min(a_l, a_r), min(a_u, a_d));
	float rim_edge = clamp((c.a - min_nb) * 1.45, 0.0, 1.0);
	// Realza bordes superiores/laterales (hacia Ventanal Cosmos y foco cenital)
	float top_bias = clamp(1.15 - UV.y * 0.75, 0.25, 1.0);
	vec3 rim_glow = rim_tint.rgb * rim_edge * rim_strength * top_bias * c.a;

	ALBEDO = c.rgb;
	EMISSION = c.rgb * shadow_tint.rgb * ambient_floor + rim_glow;
	ROUGHNESS = 0.72;
	SPECULAR = 0.08;
	ALPHA = alpha_out;
	ALPHA_SCISSOR_THRESHOLD = 0.08;
}

void light() {
	// Wrap suave para evitar oscurecimiento duro al inclinar el Sprite3D, preservando sombras/focos 3D
	float ndl_wrap = clamp(dot(NORMAL, LIGHT) * 0.45 + 0.55, 0.22, 1.0);
	float att = smoothstep(0.04, 0.48, ATTENUATION);
	float weight = 0.14 + att * ndl_wrap * 0.76;
	DIFFUSE_LIGHT = min(DIFFUSE_LIGHT + LIGHT_COLOR * weight, vec3(1.08));
}
