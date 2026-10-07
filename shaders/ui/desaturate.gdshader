shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.0) = 0.0;
uniform float brightness : hint_range(0.0, 2.0) = 0.85;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 out_rgb = mix(vec3(gray), col.rgb, saturation) * brightness;
	COLOR = vec4(out_rgb, col.a) * COLOR;
}
