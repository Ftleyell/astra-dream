shader_type canvas_item;
render_mode blend_add, unshaded;

// star_light_field.gdshader
// Proyecta el bioma estelar y la luz ambiental del sol en todo su dominio orbital y más allá.
// Utiliza atenuación cuadrática suave (inverse-square celestial falloff),
// ruido procedural FBM de polvo estelar / heliosfera y micro-pulsaciones orgánicas
// con un suave fade out perimétrico en el límite de la heliopausa.

uniform vec4 light_color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float intensity : hint_range(0.0, 3.5) = 1.0;
uniform float core_cutoff_radius : hint_range(0.0, 0.2) = 0.04;
uniform float falloff_exponent : hint_range(0.5, 4.0) = 1.1;
uniform float pulse_speed : hint_range(0.1, 3.0) = 0.8;
uniform float heliosphere_noise_strength : hint_range(0.0, 1.0) = 0.45;
uniform float heliosphere_edge_feather : hint_range(0.02, 0.5) = 0.25;
uniform float noise_scale : hint_range(1.0, 30.0) = 6.0;

// Pseudo-random gradient hash 2D
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// Gradient noise 2D
float gradient_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
		    dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
		mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
		    dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
		u.y
	);
}

// FBM liviano de 3 octavas para gas cósmico orbital
float fbm_heliosphere(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 3; i++) {
		val += amp * (gradient_noise(p) * 0.5 + 0.5);
		p = rot * p * 2.02;
		amp *= 0.5;
	}
	return val;
}

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 d = UV - center;
	float dist = length(d); // 0.0 en el centro, 0.5 en el borde del quad

	// Normalizamos radio a 0..1 en el círculo inscrito
	float norm_r = dist * 2.0;

	if (norm_r >= 1.0) {
		discard;
	}

	// Atenuación base desde el núcleo hacia el límite orbital
	// Curva suave con persistencia en el bioma medio (entre órbitas planetarias)
	float falloff = pow(1.0 - norm_r, falloff_exponent);

	// Suave fade out en el borde de órbita (heliopausa)
	float edge_fade = smoothstep(1.0, 1.0 - heliosphere_edge_feather, norm_r);

	// Ruido de gas y polvo cósmico rotando y fluyendo sutilmente
	vec2 noise_coords = (d * noise_scale) + vec2(sin(TIME * 0.05), cos(TIME * 0.04)) * 0.2;
	float gas = fbm_heliosphere(noise_coords);

	// Modulación de gas sobre el halo
	float gas_factor = mix(1.0, gas * 1.5, heliosphere_noise_strength);

	// Suave pulsación lenta de radiación estelar
	float pulse = 1.0 + sin(TIME * pulse_speed) * 0.04;

	float combined_mask = falloff * edge_fade * gas_factor * pulse;
	vec3 final_color = light_color.rgb * intensity * combined_mask;
	float final_alpha = combined_mask * intensity * light_color.a;

	COLOR = vec4(final_color, final_alpha);
}

