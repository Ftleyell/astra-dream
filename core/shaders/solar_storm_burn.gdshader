shader_type canvas_item;

// Solar Storm Burn Shader
// Genera ceguera periférica térmica dejando despejada la zona central alrededor del jugador.
// Da la apariencia de un sensor óptico sobreexpuesto y quemado por radiación coronal.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec2 player_screen_pos = vec2(960.0, 540.0);
uniform float inner_radius : hint_range(100.0, 600.0) = 280.0;
uniform float outer_radius : hint_range(300.0, 1200.0) = 600.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 burn_color : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform vec4 flare_edge_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float noise_speed : hint_range(0.5, 10.0) = 3.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	if (intensity <= 0.001) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		vec2 screen_pos = SCREEN_UV / SCREEN_PIXEL_SIZE;
		float dist = distance(screen_pos, player_screen_pos);

		// Distorsión sutil de calor
		vec2 uv_noise_offset = vec2(
			noise(screen_pos * 0.015 + vec2(TIME * noise_speed, 0.0)) - 0.5,
			noise(screen_pos * 0.015 + vec2(0.0, TIME * noise_speed)) - 0.5
		) * 8.0 * SCREEN_PIXEL_SIZE * intensity;

		vec4 base_color = texture(screen_texture, SCREEN_UV + uv_noise_offset);

		// Máscara de transición radial (Centro despejado -> Periferia quemada)
		float burn_factor = smoothstep(inner_radius, outer_radius, dist) * intensity;

		// Destellos armónicos en la frontera del cono de visión
		float border_wave = sin(dist * 0.05 - TIME * 6.0) * 0.5 + 0.5;
		float edge_glow = smoothstep(inner_radius - 40.0, inner_radius + 40.0, dist) *
		                  (1.0 - smoothstep(inner_radius + 40.0, inner_radius + 120.0, dist));

		// Tinte de sobreexposición blanca con bordes de llamarada naranja
		vec3 scorched_rgb = mix(base_color.rgb, flare_edge_color.rgb, edge_glow * 0.7 * intensity);
		scorched_rgb = mix(scorched_rgb, burn_color.rgb, burn_factor * 0.95);

		// Leve desaturación e hiper-brillo en la periferia
		float luma = dot(scorched_rgb, vec3(0.299, 0.587, 0.114));
		scorched_rgb = mix(scorched_rgb, vec3(luma * 1.4), burn_factor * 0.5);

		COLOR = vec4(scorched_rgb, 1.0);
	}
}
