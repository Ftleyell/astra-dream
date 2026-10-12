shader_type canvas_item;
render_mode blend_mix, unshaded;

// space_nebula_quad.gdshader
// Estrato medio de gas nebular procedural y texturizado continuo.
// Emplea coordenadas mundiales desacopladas de CPU, blending aditivo/suave y modulación cromática.

uniform sampler2D nebula_texture : repeat_enable, filter_linear_mipmap;
uniform vec2 camera_world_pos = vec2(0.0);
uniform float parallax_factor = 0.2;
uniform vec2 texture_scale = vec2(2048.0, 2048.0);

uniform vec4 nebula_color_a : source_color = vec4(0.4, 0.1, 0.6, 0.4);
uniform vec4 nebula_color_b : source_color = vec4(0.1, 0.3, 0.7, 0.3);
uniform float flow_speed = 0.02;
uniform float density = 1.0;

// Ruido simple 2D para modulación de volumen y remolinos
float noise(vec2 st) {
	vec2 i = floor(st);
	vec2 f = fract(st);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = fract(sin(dot(i, vec2(12.9898, 78.233))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(12.9898, 78.233))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(12.9898, 78.233))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(12.9898, 78.233))) * 43758.5453);

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 world_offset = camera_world_pos * parallax_factor;
	float time_drift = TIME * flow_speed;
	vec2 uv_scrolled = (UV * texture_scale + world_offset) / texture_scale;

	vec4 tex_sample = texture(nebula_texture, uv_scrolled + vec2(time_drift * 0.2, -time_drift * 0.1));

	// Modulación de distorsión gaseosa FBM de 2 octavas
	vec2 n_coord = (UV * texture_scale + world_offset) * 0.0004;
	float n1 = noise(n_coord + vec2(time_drift, 0.0));
	float n2 = noise(n_coord * 2.0 - vec2(0.0, time_drift * 1.5));
	float cloud_density = smoothstep(0.2, 0.85, (n1 * 0.6 + n2 * 0.4) * tex_sample.r) * density;

	vec3 chrominance = mix(nebula_color_a.rgb, nebula_color_b.rgb, n2);
	float alpha = clamp(cloud_density * max(nebula_color_a.a, nebula_color_b.a), 0.0, 1.0);

	COLOR = vec4(chrominance * alpha, alpha);
}
