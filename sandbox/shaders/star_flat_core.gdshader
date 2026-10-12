shader_type canvas_item;
render_mode blend_mix, unshaded;

// star_flat_core.gdshader
// Renderiza un disco circular plano y sólido para el fondo del núcleo estelar,
// eliminando transparencias no deseadas o agujeros que dejan ver el fondo cósmico.

uniform vec4 flat_color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float core_radius : hint_range(0.1, 0.5) = 0.32;
uniform float edge_feather : hint_range(0.001, 0.1) = 0.035;

void fragment() {
	vec2 delta = UV - vec2(0.5);
	float dist = length(delta);
	float alpha = 1.0 - smoothstep(core_radius - edge_feather, core_radius, dist);
	if (alpha <= 0.0) {
		discard;
	}
	COLOR = vec4(flat_color.rgb, flat_color.a * alpha);
}
