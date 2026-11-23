shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D ink_sdf_tex : hint_default_white, filter_linear;
uniform bool has_ink_sdf = false;
uniform float ink_sdf_bias_px : hint_range(-1.5, 2.0) = 0.05;
uniform float ink_sdf_softness : hint_range(0.2, 2.0) = 0.85;
uniform sampler2D id_mask_tex : hint_default_black, filter_linear;
uniform bool has_id_mask = false;
uniform int leg_layer_pass : hint_range(0, 2) = 0;
uniform int body_hip_skin_pass : hint_range(0, 1) = 0;
uniform int head_layer_pass : hint_range(0, 2) = 0;
uniform float head_over_face_keep : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a <= 0.01) {
		COLOR = vec4(0.0);
	} else {
		vec4 raw_mask = has_id_mask ? textureLod(id_mask_tex, UV, 0.0) : vec4(0.0);
		float layer_alpha = 1.0;

		if (leg_layer_pass == 2) {
			// Paridad con pilot_rig_stylizer.gdshader: solo cuff superior traslapado de media/bota
			float cuff_top = smoothstep(0.25, 0.27, UV.y);
			float cuff_bot = 1.0 - smoothstep(0.44, 0.48, UV.y);
			float cuff_mask = smoothstep(0.20, 0.45, raw_mask.a);
			layer_alpha *= cuff_top * cuff_bot * cuff_mask;
			if (layer_alpha < 0.02) {
				discard;
			}
		}

		if (body_hip_skin_pass == 1 && UV.y <= 0.52) {
			discard;
		}

		if (head_layer_pass > 0) {
			float is_hair = smoothstep(0.12, 0.38, raw_mask.a);
			float is_collar_blue = smoothstep(0.42, 0.58, raw_mask.b);
			float w_skin = clamp(1.0 - (raw_mask.r + raw_mask.g + raw_mask.b + raw_mask.a), 0.0, 1.0);
			if (head_layer_pass == 1) {
				float neck_or_seam = max(is_collar_blue, smoothstep(0.55, 0.72, UV.y));
				layer_alpha *= neck_or_seam * mix(1.0, smoothstep(0.82, 0.98, tex.a), is_hair);
			} else if (head_layer_pass == 2) {
				float is_collar = smoothstep(0.25, 0.45, is_collar_blue) * (1.0 - smoothstep(0.35, 0.65, raw_mask.a));
				if (head_over_face_keep < 0.5) {
					float is_face_skin = smoothstep(0.35, 0.65, w_skin) * (1.0 - is_collar);
					layer_alpha *= max(is_hair, is_face_skin) * (1.0 - is_collar) * smoothstep(0.0, 0.12, tex.a);
				} else {
					layer_alpha *= 1.0 - is_collar;
				}
			}
			if (layer_alpha < 0.02) {
				discard;
			}
		}

		float sdf_ink_line = 0.0;
		if (has_ink_sdf) {
			vec2 duv_x = vec2(dFdx(UV.x), dFdy(UV.x));
			vec2 duv_y = vec2(dFdx(UV.y), dFdy(UV.y));
			float screen_px_in_texels = max(
				length(duv_x) / max(TEXTURE_PIXEL_SIZE.x, 1e-6),
				length(duv_y) / max(TEXTURE_PIXEL_SIZE.y, 1e-6)
			);
			float eff_tex_per_px = clamp(screen_px_in_texels, 1.0, 1.65);
			float bias_px = clamp(ink_sdf_bias_px, -0.35, 0.15);
			float aa_px = clamp(0.45 * ink_sdf_softness, 0.15, 0.65);

			if (screen_px_in_texels <= 1.65) {
				float sdf_tex = (textureLod(ink_sdf_tex, UV, 0.0).r - 0.5) * 16.0;
				float sdf_norm = sdf_tex / eff_tex_per_px;
				sdf_ink_line = 1.0 - smoothstep(-aa_px + bias_px, aa_px + bias_px, sdf_norm);
			} else {
				float s_foot = clamp(screen_px_in_texels * 0.36, 0.6, 2.2);
				vec2 s_rgss[4] = vec2[4](
					vec2(-0.35, -0.85), vec2(0.85, -0.35),
					vec2(0.35, 0.85), vec2(-0.85, 0.35)
				);
				float cov_sum = 0.0;
				for (int si = 0; si < 4; si++) {
					vec2 suv = clamp(UV + s_rgss[si] * s_foot * TEXTURE_PIXEL_SIZE, vec2(0.0), vec2(1.0));
					float stex = (textureLod(ink_sdf_tex, suv, 0.0).r - 0.5) * 16.0;
					float snorm = stex / eff_tex_per_px;
					cov_sum += 1.0 - smoothstep(-aa_px + bias_px, aa_px + bias_px, snorm);
				}
				sdf_ink_line = cov_sum * 0.25;
			}
		}
		// Canal R transporta la máscara de tinta interna SDF hacia el CanvasGroup (Pasada 2)
		COLOR = vec4(sdf_ink_line, 0.0, 0.0, tex.a * layer_alpha);
	}
}
