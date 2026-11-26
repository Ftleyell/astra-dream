shader_type canvas_item;
render_mode blend_mix;

// Shader de Fusión sobre Escenario 3D y Recolor Selectivo por Skin para Cut-In 2D de Valentina v2.
// - Elimina con alfa suave el fondo espacial oscuro exterior para exponer el Escenario 3D Cel-Shaded
//   detrás de Valentina, protegiendo al 100% la silueta central (rostro, cabello, tinta negra).
// - Remapea selectivamente acentos carmesí/rubí (traje, alas, monóculo) hacia skin_accent_color
//   y potencia los brillos de retícula óptica hacia contrast_crosshair_color, protegiendo piel y B/N.

uniform vec4 skin_accent_color : source_color = vec4(0.98, 0.14, 0.34, 1.0);
uniform vec4 contrast_crosshair_color : source_color = vec4(0.08, 0.96, 0.88, 1.0);
uniform float bg_key_threshold : hint_range(0.02, 0.55) = 0.16;
uniform float recolor_strength : hint_range(0.0, 1.0) = 0.88;
uniform float enable_bg_key : hint_range(0.0, 1.0) = 1.0;
uniform float is_base_skin : hint_range(0.0, 1.0) = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = tex.rgb;
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 hsv = rgb2hsv(rgb);

	// 1. Recolor HSV selectivo por skin (protege tonos piel y blanco/negro neutro)
	float is_red_hue = max(1.0 - smoothstep(0.035, 0.075, hsv.x), smoothstep(0.86, 0.93, hsv.x));
	float sat_mask = smoothstep(0.32, 0.54, hsv.y);
	float val_mask = smoothstep(0.14, 0.28, hsv.z);
	// Protección estricta de tonos piel (hue cálido naranja-melocotón con saturación media y luminancia media-alta)
	float skin_hue = smoothstep(0.015, 0.045, hsv.x) * (1.0 - smoothstep(0.085, 0.13, hsv.x));
	float skin_protect = skin_hue * (1.0 - smoothstep(0.45, 0.62, hsv.y)) * smoothstep(0.42, 0.60, hsv.z);

	float accent_mask = clamp(is_red_hue * sat_mask * val_mask * (1.0 - skin_protect), 0.0, 1.0);
	vec3 target_hsv = rgb2hsv(skin_accent_color.rgb);
	vec3 contrast_hsv = rgb2hsv(contrast_crosshair_color.rgb);

	// Brillo intenso de retícula / monóculo ocular -> tintar hacia contrast_crosshair_color
	float eye_region = 1.0 - smoothstep(0.14, 0.36, length((UV - vec2(0.56, 0.44)) * vec2(1.35, 1.0)));
	float reticle_glow = eye_region * smoothstep(0.62, 0.88, hsv.z) * smoothstep(0.30, 0.60, hsv.y);

	vec3 recolored = rgb;
	if (is_base_skin < 0.5 && recolor_strength > 0.001) {
		vec3 mapped_hsv = vec3(target_hsv.x, clamp(hsv.y * max(target_hsv.y, 0.45), 0.0, 1.0), hsv.z);
		vec3 mapped_rgb = hsv2rgb(mapped_hsv);
		recolored = mix(rgb, mapped_rgb, accent_mask * recolor_strength);
	}
	if (reticle_glow > 0.001) {
		vec3 ret_rgb = hsv2rgb(vec3(contrast_hsv.x, clamp(max(hsv.y, 0.85), 0.0, 1.0), clamp(hsv.z * 1.15, 0.0, 1.0)));
		recolored = mix(recolored, ret_rgb, reticle_glow * (0.45 + 0.45 * recolor_strength));
	}

	// 2. Alfa suave para fundir fondo espacial oscuro sobre el Escenario 3D Cel-Shaded
	float out_alpha = tex.a;
	if (enable_bg_key > 0.5) {
		// Núcleo ovalado del retrato (rostro, cabello, hombros) siempre protegido 100% opaco
		vec2 p = (UV - vec2(0.50, 0.54)) * vec2(1.45, 1.08);
		float portrait_core = 1.0 - smoothstep(0.32, 0.62, length(p));
		float dark_bg = 1.0 - smoothstep(bg_key_threshold * 0.55, bg_key_threshold * 1.45, luma + hsv.y * 0.14);
		float key_cut = dark_bg * (1.0 - portrait_core);
		out_alpha = tex.a * clamp(1.0 - key_cut * 0.94, 0.0, 1.0);
	}

	COLOR = vec4(recolored, out_alpha);
}
