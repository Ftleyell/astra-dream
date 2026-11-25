shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.45);
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.08;
uniform float fade_min : hint_range(0.0, 1.0) = 0.18;
uniform float fade_power : hint_range(0.5, 3.0) = 1.2;

void fragment() {
	// Muestreo suavizado de 5 taps para bordes PCF blandos acordes con las sombras Forward+
	vec2 off = vec2(0.0045, 0.0045);
	float a_c = texture(texture_albedo, UV).a;
	float a_1 = texture(texture_albedo, clamp(UV + vec2(off.x, 0.0), vec2(0.0), vec2(1.0))).a;
	float a_2 = texture(texture_albedo, clamp(UV - vec2(off.x, 0.0), vec2(0.0), vec2(1.0))).a;
	float a_3 = texture(texture_albedo, clamp(UV + vec2(0.0, off.y), vec2(0.0), vec2(1.0))).a;
	float a_4 = texture(texture_albedo, clamp(UV - vec2(0.0, off.y), vec2(0.0), vec2(1.0))).a;
	float soft_alpha = a_c * 0.40 + (a_1 + a_2 + a_3 + a_4) * 0.15;
	if (soft_alpha < alpha_threshold * 0.5) {
		discard;
	}
	ALBEDO = shadow_color.rgb;
	// UV.y: 1.0 = pies (contacto nítido y oscuro en el suelo), 0.0 = cabeza (desvanecimiento gradual)
	float ground_dist = 1.0 - clamp(UV.y, 0.0, 1.0);
	float fade = mix(1.0, fade_min, pow(ground_dist, fade_power));
	ALPHA = shadow_color.a * soft_alpha * fade;
}
