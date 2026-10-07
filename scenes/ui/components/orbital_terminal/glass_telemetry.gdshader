shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 glass_tint : source_color = vec4(0.015, 0.025, 0.04, 0.88);
uniform float refraction_strength : hint_range(0.0, 0.05) = 0.003;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.0015;

uniform float hex_scale : hint_range(5.0, 100.0) = 48.0;
uniform float hex_opacity : hint_range(0.0, 1.0) = 0.05;
uniform vec4 hex_color : source_color = vec4(0.3, 0.85, 0.95, 1.0);

uniform float scanline_density : hint_range(0.5, 5.0) = 2.2;
uniform float scanline_opacity : hint_range(0.0, 0.5) = 0.07;

uniform float shimmer_position : hint_range(-0.5, 1.5) = -0.5;
uniform float shimmer_width : hint_range(0.05, 0.5) = 0.18;
uniform float shimmer_intensity : hint_range(0.0, 3.0) = 0.0;

float hex_distance(vec2 p) {
	p = abs(p);
	float c = dot(p, normalize(vec2(1.0, 1.7320508)));
	c = max(c, p.x);
	return c;
}

vec4 generate_hex_grid(vec2 uv, vec2 aspect_ratio) {
	vec2 p = uv * aspect_ratio * hex_scale;
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;

	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 gv = length(a) < length(b) ? a : b;

	float edge = hex_distance(gv);
	float line = smoothstep(0.48, 0.50, edge) - smoothstep(0.50, 0.52, edge);
	return vec4(hex_color.rgb, line * hex_opacity);
}

void fragment() {
	vec2 screen_uv = SCREEN_UV;

	// Muestreo con aberración cromática transversal
	float r = textureLod(screen_texture, screen_uv + vec2(refraction_strength + chromatic_aberration, 0.0), 0.5).r;
	float g = textureLod(screen_texture, screen_uv + vec2(refraction_strength, 0.0), 0.5).g;
	float b = textureLod(screen_texture, screen_uv + vec2(refraction_strength - chromatic_aberration, 0.0), 0.5).b;
	vec3 scene_sample = vec3(r, g, b);

	// Mezcla de absorción cromática del vidrio ahumado
	vec3 composite = mix(scene_sample, glass_tint.rgb, glass_tint.a);

	// Cálculo e inyección de la micro-rejilla hexagonal
	vec2 aspect = normalize(vec2(1.0 / TEXTURE_PIXEL_SIZE.x, 1.0 / TEXTURE_PIXEL_SIZE.y));
	vec4 hex = generate_hex_grid(UV, aspect);
	composite += hex.rgb * hex.a;

	// Líneas de escaneo horizontales (CRT falloff)
	float scanline = sin((UV.y / TEXTURE_PIXEL_SIZE.y) * scanline_density);
	scanline = (scanline * 0.5 + 0.5) * scanline_opacity;
	composite -= scanline;

	// Barrido especular de alta pureza (Shimmer)
	float sweep_axis = UV.x - UV.y * 0.35;
	float sweep = smoothstep(shimmer_position - shimmer_width, shimmer_position, sweep_axis)
				- smoothstep(shimmer_position, shimmer_position + shimmer_width, sweep_axis);
	vec3 sweep_glow = vec3(0.6, 1.8, 2.4) * max(0.0, sweep) * shimmer_intensity;
	composite += sweep_glow;

	COLOR = vec4(composite, 1.0);
}
