shader_type canvas_item;

uniform sampler2D mask_texture : hint_default_black;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float mask_legs = texture(mask_texture, UV).g;
	
	// Si no está en el canal verde de la máscara, lo hace transparente
	if (mask_legs < 0.1) {
		COLOR = vec4(0.0);
	} else {
		COLOR = base;
	}
}