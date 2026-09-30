shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.45);
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.08;
uniform float fade_min : hint_range(0.0, 1.0) = 0.18;
uniform float fade_power : hint_range(0.5, 3.0) = 1.2;

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	if (albedo_tex.a < alpha_threshold) {
		discard;
	}
	ALBEDO = shadow_color.rgb;
	// UV.y: 1.0 = pies (contacto nítido y oscuro en el suelo), 0.0 = cabeza (desvanecimiento gradual)
	float ground_dist = 1.0 - clamp(UV.y, 0.0, 1.0);
	float fade = mix(1.0, fade_min, pow(ground_dist, fade_power));
	ALPHA = shadow_color.a * albedo_tex.a * fade;
}

