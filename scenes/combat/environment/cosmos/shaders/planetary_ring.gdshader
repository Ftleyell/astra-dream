shader_type canvas_item;
render_mode blend_mix, unshaded;

/**
 * planetary_ring.gdshader
 *
 * Shader de anillos planetarios 2.5D Anime Space-Opera para Cosmos Engine.
 * Muestrea una textura polar compilada (U = radial r_in..r_out, V = ángulo 0..2pi)
 * realizando proyección perspectiva inversa del disco inclinado (tilt_x_rad + roll_rad),
 * separación exacta en 2 pasadas (ring_pass = 0 detrás del planeta / 1 delante),
 * terminador solar sutil y sombra analítica del planeta proyectada sobre el anillo.
 */

uniform sampler2D ring_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform int ring_pass : hint_range(0, 1) = 0; // 0 = detrás del planeta, 1 = delante del planeta

uniform float inner_r_norm : hint_range(0.05, 0.45) = 0.27;
uniform float outer_r_norm : hint_range(0.20, 0.50) = 0.485;
uniform float planet_r_norm : hint_range(0.05, 0.40) = 0.21;
uniform float tilt_x_rad : hint_range(0.20, 1.45) = 1.18; // ~68 grados
uniform float roll_rad : hint_range(-3.1416, 3.1416) = 0.28;
uniform float ring_spin_speed : hint_range(-0.15, 0.15) = 0.012;

uniform vec4 ring_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float ring_opacity : hint_range(0.0, 1.5) = 0.92;

// Iluminación solar, bioma y sombra planetaria
uniform vec2 light_direction = vec2(-1.0, 0.0);
uniform float light_depth : hint_range(0.0, 1.0) = 0.30;
uniform vec4 star_light_color : source_color = vec4(1.0, 0.9, 0.65, 1.0);
uniform float star_light_tint_strength : hint_range(0.0, 1.0) = 0.45;
uniform vec4 biome_tint_color : source_color = vec4(0.15, 0.08, 0.25, 1.0);
uniform float biome_tint_intensity : hint_range(0.0, 1.0) = 0.28;
uniform float eclipse_shadow : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float cr = cos(roll_rad);
	float sr = sin(roll_rad);
	// Rotar coordenada al espacio local del anillo (X = eje mayor, Y = eje menor aplastado)
	vec2 p_rot = vec2(p.x * cr + p.y * sr, -p.x * sr + p.y * cr);

	float cos_tilt = max(cos(tilt_x_rad), 0.14);
	float sin_tilt = sin(tilt_x_rad);
	float y_plane = p_rot.y / cos_tilt;

	// Profundidad en cámara: +Y pantalla abajo = delante del planeta (z > 0), -Y pantalla arriba = detrás (z < 0)
	float z_ring = p_rot.y * (sin_tilt / cos_tilt);
	if (ring_pass == 0 && z_ring > 0.0005) {
		discard;
	}
	if (ring_pass == 1 && z_ring <= 0.0005) {
		discard;
	}

	float r_3d = length(vec2(p_rot.x, y_plane));
	float r_span = max(outer_r_norm - inner_r_norm, 0.001);
	if (r_3d < inner_r_norm || r_3d > outer_r_norm) {
		discard;
	}

	float r_u = (r_3d - inner_r_norm) / r_span;
	float edge_fade = smoothstep(0.0, 0.055, r_u) * (1.0 - smoothstep(0.945, 1.0, r_u));
	if (edge_fade <= 0.002) {
		discard;
	}

	float ang = atan(y_plane, p_rot.x);
	float theta_v = fract(ang * 0.15915494 + TIME * ring_spin_speed);

	vec4 tex = texture(ring_texture, vec2(r_u, theta_v));
	float alpha = tex.a * edge_fade * ring_opacity;
	if (alpha <= 0.008) {
		discard;
	}

	// Reconstruir posición 3D en espacio pantalla del anillo (eje Y local del anillo inclinado hacia el espectador)
	vec2 ring_x_axis = vec2(cr, sr);
	vec2 ring_y_axis = vec2(-sr, cr);
	vec2 xy_screen = ring_x_axis * p_rot.x + ring_y_axis * p_rot.y;
	vec3 pos_3d = vec3(xy_screen, z_ring);

	// Sombra analítica real de la esfera del planeta sobre el anillo
	vec2 l2 = length(light_direction) > 0.0001 ? normalize(light_direction) : vec2(-1.0, 0.0);
	vec3 l3 = normalize(vec3(l2.x, l2.y, light_depth));

	vec3 p_unit = pos_3d / max(planet_r_norm, 0.001);
	float along_light = dot(p_unit, l3);
	float ring_shadow = 0.0;
	if (along_light < 0.0) {
		float perp_dist = length(p_unit - l3 * along_light);
		ring_shadow = 1.0 - smoothstep(0.94, 1.04, perp_dist);
	}
	float total_shadow = clamp(max(ring_shadow, eclipse_shadow * 0.85), 0.0, 0.95);

	// Retroiluminación crepuscular + desaturación ligera + tinte solar anime
	float lit_factor = mix(1.0, 0.14, total_shadow);
	vec3 base_col = tex.rgb * ring_tint.rgb;
	base_col = mix(base_col, vec3(dot(base_col, vec3(0.299, 0.587, 0.114))), 0.18);
	vec3 star_lit = mix(base_col, base_col * star_light_color.rgb * 1.45, star_light_tint_strength * 0.72);
	vec3 col = mix(base_col * mix(vec3(0.14, 0.16, 0.28), biome_tint_color.rgb * 1.4, 0.45), star_lit, lit_factor);

	// Velo de bioma en el polvo del anillo
	if (biome_tint_intensity > 0.001) {
		col = mix(col, col * biome_tint_color.rgb * 1.55, biome_tint_intensity * 0.55);
	}

	// Borde brillante sutil en la transición de sombra del anillo (halo de hielo retroiluminado)
	float shadow_edge = clamp(ring_shadow * (1.0 - ring_shadow) * 4.0, 0.0, 1.0);
	col += star_light_color.rgb * shadow_edge * 0.16;

	COLOR = vec4(col, clamp(alpha, 0.0, 1.0)) * COLOR;
}
