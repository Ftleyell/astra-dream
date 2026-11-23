shader_type canvas_item;
render_mode blend_mix, unshaded;

// debris_cutout.gdshader
// Shader para fragmentos de restos espaciales instanciados en GPU vía MultiMeshInstance2D.
// Emplea un atlas 2D unificado indexado por INSTANCE_CUSTOM,
// rotación angular y deriva procedural en vertex shader (Zero CPU cost),
// y alpha-cutoff con descarte de fragmentos (discard) para evitar bordes cuadrados.

uniform sampler2D atlas_texture : filter_linear_mipmap;
uniform float global_time = 0.0;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.08;
uniform float drift_speed : hint_range(0.0, 100.0) = 15.0;
uniform float spin_speed_mult : hint_range(0.0, 5.0) = 0.8;

uniform float cell_radius = 6000.0;
uniform float edge_fade_margin = 1200.0;

// Estilizado Anime Space-Opera + Unificación Lumínica y Perspectiva Aérea Cósmica
uniform float anime_contrast : hint_range(0.8, 1.8) = 1.06;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.32;
uniform vec4 rim_tint : source_color = vec4(0.75, 0.88, 1.0, 1.0);
uniform float ink_edge_strength : hint_range(0.0, 1.0) = 0.26;
uniform float desaturation_amount : hint_range(0.0, 1.0) = 0.58;
uniform float biome_grade_mix : hint_range(0.0, 1.0) = 0.46;
uniform float max_debris_luma : hint_range(0.2, 1.2) = 0.60;

// Iluminación direccional solar, sombras planetarias en pantalla y atmósfera de bioma
uniform vec2 light_direction = vec2(0.85, -0.52);
uniform vec4 star_light_color : source_color = vec4(1.0, 0.90, 0.72, 1.0);
uniform float star_influence : hint_range(0.0, 1.0) = 0.0;
uniform vec4 biome_haze_color : source_color = vec4(0.08, 0.14, 0.28, 1.0);
uniform float depth_haze_strength : hint_range(0.0, 0.85) = 0.34;
uniform float eclipse_shadow : hint_range(0.0, 1.0) = 0.0;
uniform vec2 star_screen_uv = vec2(0.5, 0.5);
uniform float viewport_aspect = 1.7778;
uniform int planet_occluder_count : hint_range(0, 6) = 0;
uniform vec4 planet_occluders[6];

varying vec2 v_local_pos;
varying vec2 v_world_dir;

void vertex() {
	v_local_pos = VERTEX;
	float t = (global_time > 0.0) ? global_time : TIME;
	// Semilla determinista derivada de UVs y coordenadas del atlas
	float seed = fract(sin(float(INSTANCE_ID) * 12.9898 + INSTANCE_CUSTOM.x * 78.233 + INSTANCE_CUSTOM.y * 37.719) * 43758.5453);
	float spin_rate = (seed - 0.5) * 2.0 * spin_speed_mult;
	float angle = t * spin_rate;

	// Rotación 2D limpia sobre el centro del quad local (-0.5 .. 0.5)
	float c = cos(angle);
	float s = sin(angle);
	vec2 rotated_v = vec2(VERTEX.x * c - VERTEX.y * s, VERTEX.x * s + VERTEX.y * c);
	// Proyectar dirección al espacio del mundo/capa incluyendo rotación de instancia en MODEL_MATRIX
	v_world_dir = (MODEL_MATRIX * vec4(rotated_v, 0.0, 0.0)).xy;

	// Deriva armónica suave con amplitud atenuada para evitar jitter subpixel frente a la cámara
	vec2 drift_offset = vec2(
		cos(t * 0.15 + seed * 6.28318),
		sin(t * 0.12 + seed * 6.28318)
	) * (drift_speed * 0.02);

	VERTEX = rotated_v + drift_offset;

	// Remapeamos UV a la región correspondiente en la textura atlas usando INSTANCE_CUSTOM
	UV = INSTANCE_CUSTOM.xy + UV * INSTANCE_CUSTOM.zw;
}

void fragment() {
	vec4 tex_color = texture(atlas_texture, UV);

	// Alpha testing con descarte temprano de fragmentos para eliminar recuadros
	if (tex_color.a < alpha_cutoff) {
		discard;
	}

	// Desvanecimiento suave en los bordes extremos del cuadrante para evitar cortes bruscos
	float dist_from_center = max(abs(v_local_pos.x), abs(v_local_pos.y));
	float fade_factor = 1.0 - smoothstep(cell_radius - edge_fade_margin, cell_radius, dist_from_center);

	// Desaturación cohesiva: doma colores chillones de cristales/pecios para fundirlos al bioma
	vec3 col = clamp((tex_color.rgb - vec3(0.5)) * anime_contrast + vec3(0.5), vec3(0.0), vec3(1.0));
	float base_luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(base_luma), desaturation_amount);

	float edge_band = smoothstep(alpha_cutoff, alpha_cutoff + 0.18, tex_color.a) * (1.0 - smoothstep(alpha_cutoff + 0.18, alpha_cutoff + 0.45, tex_color.a));
	col = mix(col, mix(vec3(0.025, 0.03, 0.075), biome_haze_color.rgb * 0.45, 0.45), edge_band * ink_edge_strength);

	// Iluminación direccional 2.5D desde el sol activo, sombras planetarias y grado cromático de bioma
	float screen_shadow = 0.0;
	if (planet_occluder_count > 0 && star_influence > 0.04) {
		vec2 aspect_scale = vec2(viewport_aspect, 1.0);
		vec2 frag_a = SCREEN_UV * aspect_scale;
		vec2 star_a = star_screen_uv * aspect_scale;
		vec2 to_frag = frag_a - star_a;
		float frag_sun_d = length(to_frag);
		vec2 sun_ray_dir = (frag_sun_d > 0.0005) ? (to_frag / frag_sun_d) : vec2(1.0, 0.0);
		for (int i = 0; i < 6; i++) {
			if (i >= planet_occluder_count) {
				break;
			}
			vec2 p_a = planet_occluders[i].xy * aspect_scale;
			float p_r = planet_occluders[i].z;
			float p_exp = max(planet_occluders[i].w, 1.25);
			if (p_r <= 0.001) {
				continue;
			}
			vec2 to_p = p_a - star_a;
			float p_sun_d = length(to_p);
			if (p_sun_d <= 0.002) {
				continue;
			}
			vec2 p_dir = to_p / p_sun_d;
			if (dot(sun_ray_dir, p_dir) > 0.0) {
				float proj = dot(frag_a - star_a, p_dir);
				if (proj > p_sun_d) {
					float frag_from_p = length(frag_a - p_a);
					float sphere_clear = smoothstep(p_r * 0.90, p_r * 1.15, frag_from_p);
					float perp = length((frag_a - star_a) - p_dir * proj);
					float progress = clamp((proj - p_sun_d) / max(1.2, 0.25), 0.0, 1.0);
					float cone_r = p_r * mix(0.94, p_exp, pow(progress, 0.85));
					float behind = smoothstep(p_sun_d + p_r * 0.35, p_sun_d + p_r * 0.85, proj) * sphere_clear;
					float sh = (1.0 - smoothstep(cone_r * 0.58, cone_r * 1.15, perp)) * behind;
					screen_shadow = max(screen_shadow, sh);
				}
			}
		}
	}
	float eff_eclipse = clamp(max(eclipse_shadow, screen_shadow * 0.92), 0.0, 1.0);

	vec2 ldir = normalize(light_direction + vec2(0.0001, 0.0));
	vec2 wdir = (length(v_world_dir) > 0.0001) ? normalize(v_world_dir) : vec2(0.0, -1.0);
	float solar_facing = dot(wdir, ldir);
	float shade = smoothstep(-0.65, 0.55, solar_facing) * (1.0 - eff_eclipse * 0.72);
	float luma = dot(col, vec3(0.299, 0.587, 0.114));

	vec3 key_tint = mix(vec3(0.88), star_light_color.rgb, 0.58 * star_influence + 0.20);
	vec3 ambient_floor = mix(vec3(0.14, 0.17, 0.26), biome_haze_color.rgb * 1.15, 0.65);
	col *= mix(ambient_floor, key_tint * 1.08, shade);

	vec3 sector_grade = mix(biome_haze_color.rgb * 1.45, star_light_color.rgb, shade * (0.35 + star_influence * 0.45));
	col = mix(col, col * sector_grade * 1.25 + sector_grade * 0.10, biome_grade_mix * 0.48);

	// Rim solar en el cuadrante orientado al sol + relieve anime sutil
	float rim_factor = smoothstep(0.32, 0.92, solar_facing) * smoothstep(0.32, 0.90, luma + edge_band * 0.30) * rim_strength * (1.0 - eff_eclipse * 0.85);
	vec3 rim_col = mix(rim_tint.rgb, star_light_color.rgb, star_influence * 0.75);
	col += rim_col * rim_factor * 0.26;

	// Perspectiva aérea de bioma: integra el estrato lejano y sombras en el polvo de la nebulosa
	float shadow_mask = 1.0 - shade;
	float haze_mix = clamp(depth_haze_strength * (0.50 + shadow_mask * 0.50), 0.0, 0.90);
	col = mix(col, biome_haze_color.rgb, haze_mix);

	// Tope suave de luminancia para nunca competir con planetas ni con Valentina
	float post_luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	if (post_luma > max_debris_luma) {
		float capped_luma = max_debris_luma + (post_luma - max_debris_luma) * 0.25;
		col *= capped_luma / max(post_luma, 0.0001);
	}

	// Modulación de color por la instancia y fade perimetral
	COLOR = vec4(col, tex_color.a) * COLOR;
	COLOR.a *= fade_factor;
}

