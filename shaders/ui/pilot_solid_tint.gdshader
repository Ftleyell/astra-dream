shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 base_tex = texture(TEXTURE, UV);
	COLOR = vec4(tint_color.rgb, base_tex.a * tint_color.a);
}
