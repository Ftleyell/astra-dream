shader_type canvas_item;
render_mode blend_add, unshaded;

// Capa aditiva HDR para la emisión de luz roja real en las vetas y puntas de las alas.
// Vive fuera de UnifiedCharacterGroup para atravesar el Bloom HDR del WorldEnvironment.
uniform sampler2D ilm_mask_tex : filter_linear_mipmap;
uniform vec4 glow_color : source_color = vec4(1.0, 0.08, 0.22, 1.0);
uniform float glow_intensity : hint_range(0.0, 4.0) = 1.2;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float em = smoothstep(0.18, 0.82, texture(ilm_mask_tex, UV).a);
	float mask = base.a * em;
	COLOR = vec4(glow_color.rgb * glow_intensity * mask, mask);
}
