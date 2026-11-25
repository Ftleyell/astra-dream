shader_type canvas_item;

// Post-proceso fílmico sutil de unificación cromática y viñeta cósmica periférica.

uniform vec4 vignette_color : source_color = vec4(0.02, 0.025, 0.075, 1.0);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.30;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float r = length(centered * vec2(1.12, 0.96));
	float vig = smoothstep(0.38, 0.82, r) * vignette_strength;
	COLOR = vec4(vignette_color.rgb, vig);
}
