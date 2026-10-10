shader_type canvas_item;
render_mode blend_mix, unshaded;

// space_deep_quad.gdshader
// Shader de estrato profundo continuo para fondo cósmico.
// Utiliza scroll analítico en UV alimentado por coordenadas lógicas,
// textura de base continua con repetición (repeat_enable) y estrellas procedimentales ligeras.

uniform sampler2D deep_space_texture : repeat_enable, filter_linear_mipmap;
uniform vec2 camera_world_pos = vec2(0.0);
uniform float parallax_factor = 0.05;
uniform vec2 texture_scale = vec2(4096.0, 4096.0);

uniform vec4 tint_color : source_color = vec4(0.02, 0.03, 0.08, 1.0);
uniform vec4 star_tint : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float star_density = 18.0;
uniform float star_brightness = 0.75;

// Hash determinista en GPU
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	// Offset de parallax analítico
	vec2 world_offset = camera_world_pos * parallax_factor;
	vec2 uv_scrolled = (UV * texture_scale + world_offset) / texture_scale;

	vec4 tex_sample = texture(deep_space_texture, uv_scrolled);

	// Capa procedimental de microestrellas estáticas en espacio mundial
	vec2 star_grid_pos = (UV * texture_scale + world_offset) * (star_density / 1000.0);
	vec2 grid_id = floor(star_grid_pos);
	vec2 grid_uv = fract(star_grid_pos) - 0.5;

	float star_rand = hash21(grid_id);
	float star = 0.0;
	if (star_rand > 0.88) {
		float dist = length(grid_uv);
		float radius = 0.06 * (star_rand - 0.85);
		star = smoothstep(radius, 0.0, dist) * star_brightness;
	}

	vec3 final_color = tex_sample.rgb * tint_color.rgb + (star * star_tint.rgb);
	COLOR = vec4(final_color, 1.0);
}
