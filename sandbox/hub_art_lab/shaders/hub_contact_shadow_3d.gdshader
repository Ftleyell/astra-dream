shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// Sombra de contacto radial suave justo bajo las botas de la piloto para anclarla físicamente al deck.

uniform vec4 contact_color : source_color = vec4(0.015, 0.012, 0.035, 0.62);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	p.y *= 1.45; // Ligera elipse horizontal acorde al apoyo de ambos pies
	float d = length(p);
	float mask = exp(-d * d * 4.2) * (1.0 - smoothstep(0.65, 1.0, d));
	ALBEDO = contact_color.rgb;
	ALPHA = contact_color.a * mask * opacity;
}
