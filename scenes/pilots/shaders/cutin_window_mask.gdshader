shader_type canvas_item;
render_mode blend_mix;

// Máscara geométrica animada para Cut-Ins de Skill [R] y Ultimate [Q] — Astra Dream
// mask_mode:
//   0 = Franja Diagonal (Formato ZZZ / Persona)
//   1 = Visor Horizontal Letterbox (Formato HSR)
//   2 = Ventana HUD Táctica Lateral con chaflán (Formato WuWa)
//   3 = Corte Asimétrico Full-Height (Ultimate ZZZ)
//   4 = Pantalla Completa (Fullscreen Bleed)
//   5 = Letterbox Cinemático Widescreen

uniform int mask_mode : hint_range(0, 5) = 0;
uniform float reveal_progress : hint_range(0.0, 1.0) = 1.0;
uniform float strip_angle_deg : hint_range(-45.0, 45.0) = -18.0;
uniform float strip_height_ratio : hint_range(0.08, 0.85) = 0.25;
uniform float strip_y_ratio : hint_range(0.10, 0.90) = 0.44;
uniform float border_width_px : hint_range(1.0, 14.0) = 5.0;
uniform vec4 accent_color : source_color = vec4(0.98, 0.14, 0.34, 1.0);
uniform vec4 bg_panel_color : source_color = vec4(0.05, 0.02, 0.09, 0.94);
uniform float time_sec = 0.0;

void fragment() {
	vec2 uv = UV;
	float dist_edge = -1.0; // negativo = dentro, positivo = fuera

	if (mask_mode == 0) {
		// Franja diagonal centrada en strip_y_ratio
		float rad = radians(strip_angle_deg);
		vec2 p = uv - vec2(0.5, strip_y_ratio);
		float rot_y = -p.x * sin(rad) + p.y * cos(rad);
		float half_h = strip_height_ratio * 0.5 * reveal_progress;
		dist_edge = abs(rot_y) - half_h;
	} else if (mask_mode == 1) {
		// Visor horizontal HSR
		float half_h = strip_height_ratio * 0.5 * reveal_progress;
		dist_edge = abs(uv.y - strip_y_ratio) - half_h;
	} else if (mask_mode == 2) {
		// Ventana HUD táctica lateral izquierda con chaflán superior/inferior
		float w = 0.38 * reveal_progress;
		float h = max(strip_height_ratio * 1.45, 0.36);
		vec2 c = vec2(0.04 + w * 0.5, strip_y_ratio);
		vec2 d = abs(uv - c) - vec2(w * 0.5, h * 0.5);
		float box_d = max(d.x, d.y);
		float chamfer = (d.x + d.y) * 0.7071 + 0.032;
		dist_edge = max(box_d, chamfer);
	} else if (mask_mode == 3) {
		// Corte asimétrico diagonal ZZZ (mitad izquierda/centro-izquierda full-height)
		float slash_x = 0.56 * reveal_progress + (0.5 - uv.y) * 0.22;
		dist_edge = uv.x - slash_x;
	} else if (mask_mode == 4) {
		// Fullscreen Bleed
		dist_edge = -1.0 + (1.0 - reveal_progress) * 2.0;
	} else {
		// Letterbox Cinemático Widescreen
		float half_h = 0.38 * reveal_progress;
		dist_edge = abs(uv.y - 0.5) - half_h;
	}

	float px_size = max(SCREEN_PIXEL_SIZE.y, 0.0005);
	float border_uv = border_width_px * px_size;

	if (dist_edge > border_uv) {
		COLOR = vec4(0.0);
	} else {
		vec4 tex_col = texture(TEXTURE, uv);
		// Fondo estilizado con líneas speedlines anime detrás del personaje transparente
		float speed_stripe = smoothstep(0.65, 0.95, sin((uv.y * 65.0 + uv.x * 12.0) - time_sec * 18.0) * 0.5 + 0.5);
		vec3 panel_bg = bg_panel_color.rgb + accent_color.rgb * (0.14 + 0.24 * speed_stripe);
		vec3 composed = mix(panel_bg, tex_col.rgb, tex_col.a);

		// Borde exterior tinta negra + brillo HDR acento
		float inner_glow = 1.0 - smoothstep(-border_uv * 2.2, 0.0, dist_edge);
		float outer_border = smoothstep(-border_uv * 0.35, border_uv * 0.25, dist_edge);
		vec3 final_rgb = mix(composed, accent_color.rgb * 1.75, inner_glow * 0.65);
		final_rgb = mix(final_rgb, vec3(1.65, 1.60, 1.72), outer_border * 0.85);
		float alpha = 1.0 - smoothstep(border_uv * 0.55, border_uv, dist_edge);
		COLOR = vec4(final_rgb, alpha);
	}
}
