shader_type canvas_item;
render_mode blend_mix, unshaded;

// debris_cutout.gdshader
// Shader para fragmentos de restos espaciales instanciados en GPU vía MultiMeshInstance2D.
// Emplea un atlas 2D unificado indexado por INSTANCE_CUSTOM (o color/UV),
// soporte de alpha-cutoff (discard) para Early-Z optimization y un tint sutil por instancia.

uniform sampler2D atlas_texture : filter_linear_mipmap;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.05;

// INSTANCE_CUSTOM en MultiMeshInstance2D provee un vec4 por instancia:
// INSTANCE_CUSTOM.xy -> UV offset del sub-rect en el atlas
// INSTANCE_CUSTOM.zw -> UV scale (anchura, altura normalizadas) del sub-rect

void vertex() {
	// UV viene en rango [0.0, 1.0] sobre la quad geométrica base.
	// Remapeamos UV a la región correspondiente en la textura atlas usando INSTANCE_CUSTOM.
	UV = INSTANCE_CUSTOM.xy + UV * INSTANCE_CUSTOM.zw;
}

void fragment() {
	vec4 tex_color = texture(atlas_texture, UV);

	// Alpha testing con descarte temprano de fragmentos para ahorrar fillrate
	if (tex_color.a < alpha_cutoff) {
		discard;
	}

	// Modulación de color por el color de la instancia (COLOR provisto por MultiMesh)
	COLOR = tex_color * COLOR;
}
