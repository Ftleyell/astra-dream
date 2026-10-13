shader_type canvas_item;
render_mode blend_mul, unshaded;

/**
 * planet_day_night_lighting.gdshader
 *
 * Overlay de iluminacion esferica analitica dia/noche para planetas interactuables de combate.
 * Opera en render_mode blend_mul multiplicando la corteza, el manto y el nucleo subyacentes.
 *
 * Caracteristicas:
 * 1. Normal esferica 3D analitica Z = sqrt(max(0.0, 1.0 - X^2 - Y^2)).
 * 2. Terminador dia/noche orientado dinamicamente hacia la estrella central (light_direction).
 * 3. Modo multiplicativo: dia preserva la exposicion / brillo y noche oscurece a penumbra ambiental.
 * 4. Recorte perimetrico suave en el limbo de la esfera con antialiasing.
 */

uniform vec2 light_direction = vec2(-1.0, 0.0);
uniform float terminator_softness : hint_range(0.01, 1.0) = 0.28;
uniform float night_ambient : hint_range(0.0, 1.0) = 0.18;
uniform float day_exposure_boost : hint_range(0.5, 2.5) = 1.0;
uniform float light_depth : hint_range(0.0, 1.0) = 0.15;
uniform float terminator_offset : hint_range(-1.0, 1.0) = 0.0;
uniform float rim_edge_feather : hint_range(0.001, 0.08) = 0.012;
uniform vec4 night_tint_color : source_color = vec4(0.12, 0.14, 0.22, 1.0);

void fragment() {
	// UV va de (0.0, 0.0) a (1.0, 1.0).
	// Centramos las coordenadas en el centro de la esfera [-1.0, 1.0]
	vec2 delta = (UV - vec2(0.5)) * 2.0;
	float dist_sq = dot(delta, delta);

	// Fuera del disco del planeta no se aplica ningun oscurecimiento
	if (dist_sq > 1.0) {
		discard;
	}

	float dist = sqrt(dist_sq);

	// Normal esferica 3D analitica de la semiesfera frontal visible
	float z = sqrt(max(0.0, 1.0 - dist_sq));
	vec3 normal = vec3(delta, z);

	// Vector 3D de luz hacia la estrella
	vec2 l_dir_2d = length(light_direction) > 0.0001 ? normalize(light_direction) : vec2(-1.0, 0.0);
	vec3 light_dir_3d = normalize(vec3(l_dir_2d.x, l_dir_2d.y, light_depth));

	// Incidencia de la luz (Terminador dia / noche)
	float n_dot_l = dot(normal, light_dir_3d);
	float lit_factor = smoothstep(terminator_offset - terminator_softness, terminator_offset + terminator_softness, n_dot_l);

	// Mezcla entre noche (penumbra ambiental tintada) y dia (exposicion completa)
	vec3 night_color = night_tint_color.rgb * night_ambient;
	vec3 day_color = vec3(day_exposure_boost);
	vec3 surface_light = mix(night_color, day_color, lit_factor);

	// Antialiasing perimetrico suave en el borde del limbo
	float edge_mask = 1.0 - smoothstep(1.0 - rim_edge_feather, 1.0, dist);

	// Multiplicador neutral 1.0 donde se desvanece el borde
	vec3 mult_color = mix(vec3(1.0), surface_light, edge_mask);

	// Respetar desvanecimiento de modulate (ej. desintegracion)
	float effective_alpha = COLOR.a;
	mult_color = mix(vec3(1.0), mult_color, effective_alpha);

	COLOR = vec4(mult_color, 1.0);
}
