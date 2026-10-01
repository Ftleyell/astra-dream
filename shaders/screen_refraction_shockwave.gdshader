shader_type canvas_item;

// Shader de distorsión refractiva de pantalla (Shockwave) con aberración cromática
// Simula una onda de choque espacial que deforma la luz del fondo al estallar el jefe.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec2 center = vec2(0.5, 0.5);
uniform float force : hint_range(0.0, 0.2) = 0.06;
uniform float size : hint_range(0.0, 1.5) = 0.0;
uniform float thickness : hint_range(0.0, 0.3) = 0.08;
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.008;
uniform float screen_aspect = 1.777777; // 16:9 por defecto

void fragment() {
	if (size > 0.001 && size < 1.45) {
		vec2 diff = SCREEN_UV - center;
		diff.x *= screen_aspect;
		float dist = length(diff);

		if (dist <= size + thickness && dist >= size - thickness) {
			float diff_dist = dist - size;
			float pow_diff = 1.0 - pow(abs(diff_dist / thickness), 2.0);
			float mask = clamp(pow_diff, 0.0, 1.0);
			
			vec2 dir = normalize(SCREEN_UV - center);
			// El empuje decae a medida que la onda crece
			float decay = clamp(1.0 - (size / 1.4), 0.0, 1.0);
			vec2 offset = dir * (mask * force * decay);

			float r = texture(screen_texture, SCREEN_UV - offset * (1.0 + chromatic_aberration)).r;
			float g = texture(screen_texture, SCREEN_UV - offset).g;
			float b = texture(screen_texture, SCREEN_UV - offset * (1.0 - chromatic_aberration)).b;
			COLOR = vec4(r, g, b, 1.0);
		} else {
			COLOR = texture(screen_texture, SCREEN_UV);
		}
	} else {
		COLOR = texture(screen_texture, SCREEN_UV);
	}
}
