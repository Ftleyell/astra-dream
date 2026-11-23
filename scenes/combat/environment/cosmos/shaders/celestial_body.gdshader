shader_type canvas_item;

/**
 * celestial_body.gdshader (v2 Anime Space-Opera)
 *
 * Shader universal de cuerpos celestes (planetas y lunas) para Cosmos Engine.
 * Soporta proyección esférica 3D real desde mapas equirectangulares 2:1 + máscaras RGBA
 * (use_spherical_projection = true), conservando 100% de compatibilidad con texturas JPG legacy
 * (use_spherical_projection = false).
 *
 * Características v2:
 * 1. Proyección esférica 3D continua con inclinación axial y sin costura de mipmaps (textureLod + fwidth).
 * 2. Relieve bump tangente normalizado desde canal A.
 * 3. Capa de nubes ciclónicas 3D independientes desde canal R con rotación diferencial y sombra proyectada.
 * 4. Emisión nocturna / eclipse selectiva desde canal G con mezcla cromática multi-espectral.
 * 5. Brillo especular cel-stepped desde canal B (océanos, cristales, placas metálicas).
 * 6. Auroras polares ondulantes en latitudes altas y dispersión crepuscular Trigger.
 */

// Geometría y Recorte
uniform vec2 planet_center = vec2(0.5, 0.5);
uniform float planet_radius : hint_range(0.2, 0.5) = 0.485;
uniform float rim_edge_feather : hint_range(0.001, 0.05) = 0.007;
uniform float edge_crop_margin : hint_range(0.0, 0.05) = 0.012;

// Proyección Esférica 3D v2 y Mapas Compilados (R=clouds, G=emissive, B=spec, A=bump)
uniform bool use_spherical_projection = false;
uniform sampler2D surface_albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D surface_maps_tex : filter_linear_mipmap, repeat_enable;
uniform float axial_tilt_rad : hint_range(-1.2, 1.2) = 0.22;
uniform float lon_phase : hint_range(0.0, 6.2832) = 0.0;

// Nubes 3D, Normales Tangentes, Cavity AO y Sombra Proyectada
uniform bool use_normal_ao_map = false;
uniform sampler2D surface_normal_ao_tex : filter_linear_mipmap, repeat_enable;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.48;
uniform float cloud_coverage : hint_range(0.0, 1.5) = 0.0;
uniform float cloud_spin_speed_offset : hint_range(-0.1, 0.1) = 0.008;
uniform vec4 cloud_tint : source_color = vec4(0.96, 0.98, 1.0, 1.0);
uniform float cloud_shadow_offset : hint_range(0.0, 0.05) = 0.011;
uniform float cloud_height_parallax : hint_range(0.0, 0.04) = 0.016;
uniform float gas_band_shear : hint_range(0.0, 0.12) = 0.0;
uniform float limb_darkening_strength : hint_range(0.0, 0.8) = 0.34;
uniform float global_time_override = -1.0;

// Emisivos Nocturnos, Especular Cel, Bump y Auroras
uniform vec4 night_emissive_color : source_color = vec4(1.0, 0.72, 0.32, 1.0);
uniform float night_emissive_strength : hint_range(0.0, 4.0) = 0.0;
uniform float night_emissive_day_keep : hint_range(0.0, 1.0) = 0.0;
uniform float night_emissive_albedo_mix : hint_range(0.0, 1.0) = 0.0;
uniform float specular_strength : hint_range(0.0, 2.5) = 0.0;
uniform float specular_shininess : hint_range(4.0, 96.0) = 28.0;
uniform float bump_strength : hint_range(0.0, 1.5) = 0.25;
uniform vec4 aurora_color : source_color = vec4(0.25, 1.0, 0.78, 1.0);
uniform float aurora_strength : hint_range(0.0, 2.5) = 0.0;

// Iluminación Dinámica y Terminador Día/Noche
uniform vec2 light_direction = vec2(-1.0, 0.0);
uniform float light_depth : hint_range(0.0, 1.0) = 0.30;
uniform float terminator_offset : hint_range(-1.0, 1.0) = 0.0;
uniform float terminator_softness : hint_range(0.01, 1.0) = 0.28;
uniform float night_ambient : hint_range(0.0, 0.5) = 0.22;
uniform float day_exposure_boost : hint_range(0.8, 2.5) = 1.30;
uniform float eclipse_shadow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 night_tint_color : source_color = vec4(0.02, 0.03, 0.08, 1.0);

// Sombras Proyectadas en Superficie (Anillos 2.5D y Tránsito Lunar)
uniform bool has_ring_shadow = false;
uniform sampler2D ring_shadow_tex : filter_linear_mipmap, repeat_enable;
uniform float ring_shadow_inner_r = 1.28;
uniform float ring_shadow_outer_r = 2.28;
uniform float ring_shadow_tilt_x_rad = 1.18;
uniform float ring_shadow_roll_rad = 0.0;
uniform float ring_shadow_opacity : hint_range(0.0, 1.0) = 0.72;
uniform float ring_shadow_spin_speed = 0.012;
uniform vec2 transit_shadow_uv = vec2(0.0, 0.0);
uniform float transit_shadow_radius = 0.25;
uniform float transit_shadow_strength : hint_range(0.0, 1.0) = 0.0;

// Atmósfera y Resplandor (Fresnel)
uniform vec4 atmosphere_color : source_color = vec4(0.35, 0.75, 1.0, 1.0);
uniform float atmosphere_intensity : hint_range(0.0, 5.0) = 1.2;
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.5;
uniform float outer_atmosphere_thickness : hint_range(0.0, 0.08) = 0.022;
uniform float outer_atmosphere_intensity : hint_range(0.0, 3.0) = 0.75;

// Dinámica y Efectos Especiales (Legacy + Base)
uniform float axial_spin_speed : hint_range(-0.1, 0.1) = 0.006;
uniform float emission_glow : hint_range(0.0, 2.0) = 0.0;
uniform vec4 emission_color : source_color = vec4(1.0, 0.3, 0.1, 1.0);

// Integración con Bioma Cósmico y Luz de la Estrella Central
uniform vec4 biome_tint_color : source_color = vec4(0.15, 0.08, 0.25, 1.0);
uniform float biome_tint_intensity : hint_range(0.0, 1.0) = 0.15;
uniform vec4 star_light_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float star_light_tint_strength : hint_range(0.0, 1.0) = 0.35;
uniform float star_atmo_tint_strength : hint_range(0.0, 1.0) = 0.45;

// Estilizado Anime Space-Opera
uniform float cel_terminator_mix : hint_range(0.0, 1.0) = 0.24;
uniform float terminator_scatter_strength : hint_range(0.0, 1.5) = 0.42;
uniform vec4 terminator_scatter_color : source_color = vec4(0.95, 0.38, 0.52, 1.0);
uniform float atmo_cel_rim_sharpness : hint_range(0.0, 1.0) = 0.55;
uniform float silhouette_ink_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec4 silhouette_ink_color : source_color = vec4(0.03, 0.03, 0.08, 1.0);


void fragment() {
	float t_anim = (global_time_override >= 0.0) ? global_time_override : TIME;
	vec2 delta = UV - planet_center;
	float dist = length(delta);

	float effective_radius = max(planet_radius - edge_crop_margin, 0.001);
	float crop_norm_dist = dist / effective_radius;
	bool is_inside_sphere = crop_norm_dist <= 1.0;

	// Normal 3D de la semiesfera frontal visible
	float z = is_inside_sphere ? sqrt(max(0.0, 1.0 - crop_norm_dist * crop_norm_dist)) : 0.0;
	vec3 normal = is_inside_sphere ? normalize(vec3(delta / effective_radius, z)) : vec3(0.0, 0.0, 1.0);

	// Precalculo continuo para mip_lod libre de artefactos de derivada en discontinuidad atan/fract
	float ct = cos(axial_tilt_rad);
	float st = sin(axial_tilt_rad);
	vec3 sp_tilt = vec3(normal.x * ct + normal.y * st, -normal.x * st + normal.y * ct, normal.z);
	float mip_lod = clamp(log2(max(length(fwidth(sp_tilt.xy)) * 140.0, 1.0)), 0.0, 5.5);

	// Vector 3D de luz estelar
	vec2 l_dir_2d = length(light_direction) > 0.0001 ? normalize(light_direction) : vec2(-1.0, 0.0);
	vec3 light_dir_3d = normalize(vec3(l_dir_2d.x, l_dir_2d.y, light_depth));

	// Fresnel esférico
	float fresnel = is_inside_sphere ? pow(1.0 - z, fresnel_power) : 0.0;

	// Máscara perimétrica suave para el recorte esférico
	float edge_mask = 1.0 - smoothstep(effective_radius - rim_edge_feather, effective_radius, dist);

	// Corona exterior atmosférica en el vacío espacial
	float outer_atmosphere = 0.0;
	if (atmosphere_intensity > 0.01 && outer_atmosphere_thickness > 0.001 && dist > effective_radius && dist < effective_radius + outer_atmosphere_thickness) {
		float outer_dist = (dist - effective_radius) / outer_atmosphere_thickness;
		float outer_falloff = exp(-outer_dist * 3.5) * (1.0 - outer_dist);

		vec2 dir_2d = normalize(delta);
		float dir_alignment = max(0.0, dot(dir_2d, l_dir_2d));
		float lit_outer = mix(0.15, 1.0, pow(dir_alignment, 1.4));

		outer_atmosphere = outer_falloff * lit_outer * outer_atmosphere_intensity * atmosphere_intensity;
	}

	if (edge_mask > 0.001) {
		if (use_spherical_projection) {
			float lon = atan(sp_tilt.x, sp_tilt.z);
			float shear = (abs(gas_band_shear) > 0.0001) ? (sin(sp_tilt.y * 4.5 + t_anim * 0.42) * 0.72 + sin(sp_tilt.y * 8.5 - t_anim * 0.28) * 0.28) * gas_band_shear : 0.0;
			float u_surf = fract(lon * 0.159154943 + 0.5 + lon_phase * 0.159154943 - t_anim * axial_spin_speed + shear);
			float v_surf = clamp(0.5 + asin(clamp(sp_tilt.y, -1.0, 1.0)) * 0.318309886, 0.002, 0.998);
			vec2 eq_uv = vec2(u_surf, v_surf);

			vec3 albedo_raw = textureLod(surface_albedo_tex, eq_uv, mip_lod).rgb;
			vec4 maps = textureLod(surface_maps_tex, eq_uv, mip_lod);

			// Marco tangente ortonormal sobre la esfera inclinada
			vec2 t_xz = vec2(sp_tilt.z, -sp_tilt.x);
			vec3 tu = length(t_xz) > 0.01 ? normalize(vec3(t_xz.x, 0.0, t_xz.y)) : vec3(1.0, 0.0, 0.0);
			vec3 tv = normalize(cross(sp_tilt, tu));
			if (tv.y < 0.0) {
				tv = -tv;
			}

			// Normal Map tangente multi-escala + Cavity AO (o fallback desde canal A)
			vec3 bump_vec = sp_tilt;
			float cavity_ao = 1.0;
			if (use_normal_ao_map) {
				vec3 n_ao = textureLod(surface_normal_ao_tex, eq_uv, mip_lod).rgb;
				vec2 t_xy = (n_ao.rg * 2.0 - vec2(1.0)) * (bump_strength * 1.65);
				bump_vec = normalize(sp_tilt + tu * t_xy.x + tv * t_xy.y);
				cavity_ao = mix(1.0, clamp(n_ao.b, 0.30, 1.0), ao_strength);
			} else if (bump_strength > 0.005) {
				float h_c = maps.a;
				float h_r = textureLod(surface_maps_tex, vec2(fract(eq_uv.x + 0.00195), eq_uv.y), mip_lod).a;
				float h_d = textureLod(surface_maps_tex, vec2(eq_uv.x, clamp(eq_uv.y + 0.0039, 0.002, 0.998)), mip_lod).a;
				float slope_scale = 8.5 * bump_strength;
				bump_vec = normalize(sp_tilt + tu * ((h_c - h_r) * slope_scale) + tv * ((h_c - h_d) * slope_scale));
			}
			vec3 shaded_normal = normalize(vec3(bump_vec.x * ct - bump_vec.y * st, bump_vec.x * st + bump_vec.y * ct, max(bump_vec.z, 0.08)));

			// Iluminación macro (cielo/nubes) e iluminación micro con relieve (terreno)
			float macro_n_dot_l = dot(normal, light_dir_3d);
			float macro_soft = smoothstep(terminator_offset - terminator_softness, terminator_offset + terminator_softness, macro_n_dot_l);
			float macro_cel = smoothstep(terminator_offset - 0.14, terminator_offset - 0.04, macro_n_dot_l) * 0.48
				+ smoothstep(terminator_offset + 0.06, terminator_offset + 0.15, macro_n_dot_l) * 0.52;
			float macro_lit = mix(macro_soft, macro_cel, cel_terminator_mix);

			float n_dot_l = dot(shaded_normal, light_dir_3d);
			float lit_soft = smoothstep(terminator_offset - terminator_softness, terminator_offset + terminator_softness, n_dot_l);
			float cel_step_mid = smoothstep(terminator_offset - 0.14, terminator_offset - 0.04, n_dot_l);
			float cel_step_hi = smoothstep(terminator_offset + 0.06, terminator_offset + 0.15, n_dot_l);
			float lit_cel = cel_step_mid * 0.48 + cel_step_hi * 0.52;
			float lit_factor = mix(lit_soft, lit_cel, cel_terminator_mix);

			// Domo de nubes 3D elevado con paralaje esférico + sombra proyectada sobre el suelo
			float cloud_alpha = 0.0;
			float cloud_shadow = 0.0;
			if (cloud_coverage > 0.01) {
				float c_thresh = clamp(1.02 - cloud_coverage * 0.78, 0.15, 0.99);
				float cloud_radius = effective_radius * (1.0 + cloud_height_parallax);
				vec2 c_xy = clamp(delta / max(cloud_radius, 0.001), vec2(-1.0), vec2(1.0));
				float c_len2 = dot(c_xy, c_xy);
				vec2 c_uv = eq_uv;
				if (c_len2 < 1.0) {
					float c_z = sqrt(max(0.0, 1.0 - c_len2));
					vec3 c_nrm = normalize(vec3(c_xy, c_z));
					vec3 c_tilt = vec3(c_nrm.x * ct + c_nrm.y * st, -c_nrm.x * st + c_nrm.y * ct, c_nrm.z);
					float c_lon = atan(c_tilt.x, c_tilt.z);
					float u_c = fract(c_lon * 0.159154943 + 0.5 + lon_phase * 0.159154943 - t_anim * (axial_spin_speed + cloud_spin_speed_offset));
					float v_c = clamp(0.5 + asin(clamp(c_tilt.y, -1.0, 1.0)) * 0.318309886, 0.002, 0.998);
					c_uv = vec2(u_c, v_c);
				} else {
					c_uv = vec2(fract(u_surf - t_anim * cloud_spin_speed_offset), eq_uv.y);
				}
				float cloud_raw = textureLod(surface_maps_tex, c_uv, mip_lod).r;
				cloud_alpha = smoothstep(c_thresh - 0.12, c_thresh + 0.18, cloud_raw) * min(cloud_coverage * 1.15, 1.0);

				vec2 tilt_light = vec2(l_dir_2d.x * ct + l_dir_2d.y * st, -l_dir_2d.x * st + l_dir_2d.y * ct);
				float eff_shadow_off = cloud_shadow_offset + cloud_height_parallax * 0.55;
				vec2 sh_uv = vec2(
					fract(c_uv.x + tilt_light.x * eff_shadow_off * 0.62),
					clamp(c_uv.y + tilt_light.y * eff_shadow_off * 0.95, 0.002, 0.998)
				);
				float sh_raw = textureLod(surface_maps_tex, sh_uv, mip_lod).r;
				cloud_shadow = smoothstep(c_thresh - 0.08, c_thresh + 0.22, sh_raw) * min(cloud_coverage, 1.0);
			}

			// Sombras proyectadas sobre superficie: Anillos 2.5D y Tránsito Lunar local
			float ring_cast_shadow = 0.0;
			if (has_ring_shadow && macro_n_dot_l > -0.15) {
				float rc = cos(ring_shadow_roll_rad);
				float rs = sin(ring_shadow_roll_rad);
				float sin_rt = sin(ring_shadow_tilt_x_rad);
				float cos_rt = cos(ring_shadow_tilt_x_rad);
				vec3 ring_n = vec3(rs * sin_rt, -rc * sin_rt, cos_rt);
				float ray_denom = dot(light_dir_3d, ring_n);
				if (abs(ray_denom) > 0.001) {
					float t_hit = -dot(normal, ring_n) / ray_denom;
					if (t_hit > 0.001) {
						vec3 hit = normal + light_dir_3d * t_hit;
						float r_hit = length(hit);
						if (r_hit >= ring_shadow_inner_r && r_hit <= ring_shadow_outer_r) {
							float r_u = (r_hit - ring_shadow_inner_r) / max(ring_shadow_outer_r - ring_shadow_inner_r, 0.001);
							float r_env = smoothstep(0.0, 0.06, r_u) * (1.0 - smoothstep(0.94, 1.0, r_u));
							float hx = hit.x * rc + hit.y * rs;
							float hy = (-hit.x * rs + hit.y * rc) / max(cos_rt, 0.14);
							float theta_v = fract(atan(hy, hx) * 0.15915494 + t_anim * ring_shadow_spin_speed);
							float r_alpha = textureLod(ring_shadow_tex, vec2(r_u, theta_v), 1.4).a;
							ring_cast_shadow = r_alpha * r_env * ring_shadow_opacity * smoothstep(-0.15, 0.12, macro_n_dot_l);
						}
					}
				}
			}

			float transit_occl = 0.0;
			if (transit_shadow_strength > 0.005 && macro_n_dot_l > -0.12) {
				vec3 p_perp = normal - light_dir_3d * dot(normal, light_dir_3d);
				vec3 m_vec = vec3(transit_shadow_uv, 0.0);
				vec3 m_perp = m_vec - light_dir_3d * dot(m_vec, light_dir_3d);
				float t_dist = length(p_perp - m_perp);
				float umbra_c = 1.0 - smoothstep(transit_shadow_radius * 0.56, transit_shadow_radius * 1.16, t_dist);
				transit_occl = umbra_c * transit_shadow_strength * smoothstep(-0.08, 0.18, macro_n_dot_l);
			}

			float surface_occl = clamp(max(ring_cast_shadow, transit_occl), 0.0, 0.92);
			float lit_shaded = lit_factor * (1.0 - surface_occl * 0.86);
			float macro_lit_shaded = macro_lit * (1.0 - surface_occl * 0.84);

			// Sombreado de terreno día / noche con Limb Darkening esférico, Cavity AO y relieve rasante en terminador
			float limb_curve = mix(1.0, pow(clamp(z, 0.05, 1.0), 0.42), limb_darkening_strength);
			float ao_lit = mix(0.85 + cavity_ao * 0.15, cavity_ao, smoothstep(0.0, 0.65, lit_shaded));
			float light_multiplier = mix(night_ambient, day_exposure_boost, lit_shaded) * limb_curve * ao_lit;
			if (eclipse_shadow > 0.001) {
				light_multiplier *= (1.0 - eclipse_shadow * 0.85);
			}
			vec3 lit_terrain = albedo_raw * light_multiplier * (1.0 - cloud_shadow * 0.48 * lit_shaded);

			float grazing_relief = clamp(n_dot_l - macro_n_dot_l, 0.0, 1.0)
				* smoothstep(-0.35, 0.30, macro_n_dot_l)
				* (1.0 - smoothstep(0.35, 0.85, macro_n_dot_l))
				* bump_strength;
			lit_terrain += mix(albedo_raw, star_light_color.rgb, 0.45) * (grazing_relief * 0.65 * (1.0 - eclipse_shadow * 0.85) * (1.0 - surface_occl * 0.85));

			if (star_light_tint_strength > 0.001) {
				vec3 star_tinted = mix(lit_terrain, lit_terrain * star_light_color.rgb * 1.38, star_light_tint_strength);
				lit_terrain = mix(lit_terrain, star_tinted, lit_shaded);
			}

			vec3 earthshine = albedo_raw * mix(vec3(0.09, 0.11, 0.19), mix(night_tint_color.rgb * 2.0, biome_tint_color.rgb * 0.95, 0.55), 0.62) * (night_ambient * 1.65);
			vec3 night_terrain = mix(lit_terrain, earthshine, (1.0 - lit_shaded) * 0.78);
			vec3 surface = mix(night_terrain, lit_terrain, lit_shaded);

			// Especular cel-stepped (maps.b)
			if (specular_strength > 0.005 && maps.b > 0.01) {
				vec3 half_vec = normalize(light_dir_3d + vec3(0.0, 0.0, 1.0));
				float ndh = max(dot(shaded_normal, half_vec), 0.0);
				float spec_pow = pow(ndh, specular_shininess);
				float spec_cel = smoothstep(0.22, 0.32, spec_pow) * 0.52 + smoothstep(0.58, 0.70, spec_pow) * 0.62;
				vec3 spec_col = mix(vec3(0.86, 0.96, 1.0), star_light_color.rgb, 0.50);
				surface += spec_col * (spec_cel * maps.b * specular_strength * lit_shaded * limb_curve * (1.0 - eclipse_shadow * 0.9) * (1.0 - cloud_alpha * 0.85));
			}

			// Emisivos nocturnos / eclipse (maps.g)
			if (night_emissive_strength > 0.005 && maps.g > 0.01) {
				float night_vis = clamp(max(1.0 - lit_factor, max(eclipse_shadow * 0.85, transit_occl * 0.75)), 0.0, 1.0);
				float em_weight = mix(night_emissive_day_keep, 1.0, night_vis);
				vec3 albedo_hue = normalize(max(albedo_raw, vec3(0.01))) * 1.15;
				vec3 em_col = mix(night_emissive_color.rgb, albedo_hue * night_emissive_color.rgb, night_emissive_albedo_mix);
				surface += em_col * (maps.g * night_emissive_strength * em_weight * (1.0 - cloud_alpha * 0.62));
			}

			// Capa de nubes 3D sobre terreno
			if (cloud_alpha > 0.002) {
				vec3 c_day = cloud_tint.rgb * mix(vec3(1.0), star_light_color.rgb * 1.22, star_light_tint_strength * 0.75) * day_exposure_boost * mix(1.0, limb_curve, 0.65) * (1.0 - eclipse_shadow * 0.84) * (1.0 - surface_occl * 0.82);
				vec3 c_night = cloud_tint.rgb * mix(vec3(0.15, 0.17, 0.28), night_tint_color.rgb * 2.2, 0.55) * (night_ambient * 1.9);
				vec3 c_col = mix(c_night, c_day, macro_lit_shaded);
				float c_twilight = clamp(macro_lit_shaded * (1.0 - macro_lit_shaded) * 4.0, 0.0, 1.0);
				c_col += terminator_scatter_color.rgb * (c_twilight * terminator_scatter_strength * 0.34 * (1.0 - eclipse_shadow * 0.8));
				surface = mix(surface, c_col, cloud_alpha * 0.84);
			}

			// Auroras polares ondulantes en latitudes altas
			if (aurora_strength > 0.01) {
				float lat_abs = abs(sp_tilt.y);
				float aurora_ring = smoothstep(0.64, 0.78, lat_abs) * (1.0 - smoothstep(0.84, 0.96, lat_abs));
				float curtain = 0.5 + 0.5 * sin(lon * 5.0 + t_anim * 0.85) * sin(lon * 11.0 - t_anim * 1.25 + sp_tilt.y * 8.0);
				float aurora_night_boost = mix(0.28, 1.15, clamp(max(1.0 - macro_lit, eclipse_shadow * 0.7), 0.0, 1.0));
				surface += aurora_color.rgb * (aurora_ring * pow(curtain, 1.35) * aurora_strength * aurora_night_boost * 0.85);
			}

			// Banda cromática crepuscular anime en el terminador
			if (terminator_scatter_strength > 0.005) {
				float twilight_band = clamp(macro_lit * (1.0 - macro_lit) * 4.0, 0.0, 1.0);
				vec3 scatter_col = mix(terminator_scatter_color.rgb, atmosphere_color.rgb, 0.48);
				surface += scatter_col * twilight_band * terminator_scatter_strength * 0.26 * (1.0 - eclipse_shadow * 0.8);
			}

			// Velo de bioma cósmico
			if (biome_tint_intensity > 0.001) {
				vec3 ambient_biome = mix(surface * 0.85, surface * biome_tint_color.rgb * 1.50, 0.55);
				surface = mix(surface, ambient_biome, biome_tint_intensity);
				surface += biome_tint_color.rgb * ((1.0 - macro_lit) * biome_tint_intensity * 0.12);
			}

			// Resplandor atmosférico interior (Fresnel cel)
			if (atmosphere_intensity > 0.01) {
				vec3 effective_atmo_color = atmosphere_color.rgb;
				if (star_atmo_tint_strength > 0.001) {
					effective_atmo_color = mix(effective_atmo_color, effective_atmo_color * star_light_color.rgb * 1.3, star_atmo_tint_strength * macro_lit);
				}
				float fresnel_styled = mix(fresnel, smoothstep(0.32, 0.72, fresnel), atmo_cel_rim_sharpness);
				float inner_atmosphere = fresnel_styled * mix(0.10, 1.0, macro_lit) * atmosphere_intensity;
				surface += effective_atmo_color * inner_atmosphere;
			}

			// Borde sutil de tinta perimétrica
			if (silhouette_ink_strength > 0.005) {
				float rim_ink = smoothstep(0.955, 0.992, crop_norm_dist) * (1.0 - smoothstep(0.992, 1.002, crop_norm_dist));
				surface = mix(surface, silhouette_ink_color.rgb, rim_ink * silhouette_ink_strength);
			}

			// Rolloff suave de altas luces estilo AgX
			surface = surface / (vec3(1.0) + max(surface - vec3(1.05), vec3(0.0)) * 0.42);
			COLOR = vec4(surface, edge_mask) * COLOR;
		} else {
			// Ruta legacy 100% compatible para texturas JPG cuadradas sin máscara v2
			vec2 surface_uv = UV;
			if (abs(axial_spin_speed) > 0.00001) {
				float angle = t_anim * axial_spin_speed;
				float c = cos(angle);
				float s = sin(angle);
				vec2 rot_delta = vec2(delta.x * c - delta.y * s, delta.x * s + delta.y * c);
				surface_uv = planet_center + rot_delta;
			}

			float n_dot_l = dot(normal, light_dir_3d);
			float lit_soft = smoothstep(terminator_offset - terminator_softness, terminator_offset + terminator_softness, n_dot_l);
			float cel_step_mid = smoothstep(terminator_offset - 0.14, terminator_offset - 0.04, n_dot_l);
			float cel_step_hi = smoothstep(terminator_offset + 0.06, terminator_offset + 0.15, n_dot_l);
			float lit_cel = cel_step_mid * 0.48 + cel_step_hi * 0.52;
			float lit_factor = mix(lit_soft, lit_cel, cel_terminator_mix);

			vec4 tex_color = texture(TEXTURE, surface_uv);
			vec3 surface = tex_color.rgb;

			if (emission_glow > 0.01) {
				float luminance = dot(surface, vec3(0.299, 0.587, 0.114));
				vec3 emissive_boost = emission_color.rgb * emission_glow * (luminance * 0.8 + 0.2);
				surface += emissive_boost * (1.0 - lit_factor * 0.5);
			}

			float light_multiplier = mix(night_ambient, day_exposure_boost, lit_factor);
			if (eclipse_shadow > 0.001) {
				light_multiplier *= (1.0 - eclipse_shadow * 0.85);
			}
			vec3 lit_surface = surface * light_multiplier;

			if (star_light_tint_strength > 0.001) {
				vec3 star_tinted = mix(lit_surface, lit_surface * star_light_color.rgb * 1.4, star_light_tint_strength);
				lit_surface = mix(lit_surface, star_tinted, lit_factor);
			}

			vec3 earthshine = surface * mix(vec3(0.20, 0.22, 0.30), night_tint_color.rgb * 2.5, 0.5) * (night_ambient * 2.2);
			vec3 night_color = mix(lit_surface, earthshine, (1.0 - lit_factor) * 0.7);
			surface = mix(night_color, lit_surface, lit_factor);

			if (terminator_scatter_strength > 0.005) {
				float twilight_band = clamp(lit_factor * (1.0 - lit_factor) * 4.0, 0.0, 1.0);
				vec3 scatter_col = mix(terminator_scatter_color.rgb, atmosphere_color.rgb, 0.55);
				surface += scatter_col * twilight_band * terminator_scatter_strength * 0.24 * (1.0 - eclipse_shadow * 0.8);
			}

			if (biome_tint_intensity > 0.001) {
				vec3 ambient_biome = mix(surface, surface * biome_tint_color.rgb * 1.6, 0.5);
				surface = mix(surface, ambient_biome, biome_tint_intensity);
			}

			if (atmosphere_intensity > 0.01) {
				vec3 effective_atmo_color = atmosphere_color.rgb;
				if (star_atmo_tint_strength > 0.001) {
					effective_atmo_color = mix(effective_atmo_color, effective_atmo_color * star_light_color.rgb * 1.3, star_atmo_tint_strength * lit_factor);
				}
				float fresnel_styled = mix(fresnel, smoothstep(0.32, 0.72, fresnel), atmo_cel_rim_sharpness);
				float inner_atmosphere = fresnel_styled * lit_factor * atmosphere_intensity;
				surface += effective_atmo_color * inner_atmosphere;
			}

			if (silhouette_ink_strength > 0.005) {
				float rim_ink = smoothstep(0.955, 0.992, crop_norm_dist) * (1.0 - smoothstep(0.992, 1.002, crop_norm_dist));
				surface = mix(surface, silhouette_ink_color.rgb, rim_ink * silhouette_ink_strength);
			}

			COLOR = vec4(surface, edge_mask) * COLOR;
		}
	} else if (outer_atmosphere > 0.001) {
		vec3 effective_outer_color = atmosphere_color.rgb;
		if (star_atmo_tint_strength > 0.001) {
			effective_outer_color = mix(effective_outer_color, effective_outer_color * star_light_color.rgb * 1.3, star_atmo_tint_strength * 0.7);
		}
		vec3 outer_color = mix(effective_outer_color, biome_tint_color.rgb, biome_tint_intensity * 0.4);
		COLOR = vec4(outer_color, outer_atmosphere * atmosphere_color.a) * COLOR;
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
}
