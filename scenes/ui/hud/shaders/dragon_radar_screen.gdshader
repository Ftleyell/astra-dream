shader_type canvas_item;

// Cuadrícula y pantalla estilo Radar Dragon Ball (CRT fósforo con Grilla de Cuadraditos)
uniform vec4 bg_color : source_color = vec4(0.01, 0.05, 0.02, 0.85);
uniform vec4 grid_color : source_color = vec4(0.12, 0.65, 0.28, 0.55);
uniform vec4 sweep_color : source_color = vec4(0.3, 1.0, 0.45, 0.85);

uniform float sweep_angle : hint_range(0.0, 6.2831853) = 0.0;
uniform float sweep_tail_length : hint_range(0.1, 3.14159) = 1.047; // ~60 grados de estela
uniform float grid_divisions : hint_range(2.0, 24.0) = 8.0; // Cuadraditos de la rejilla
uniform float border_radius : hint_range(0.1, 0.5) = 0.430; // 441px en 1024x1024
uniform float line_thickness : hint_range(0.001, 0.02) = 0.0035;
uniform sampler2D mask_texture : hint_default_white;
uniform bool use_mask_texture = true;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 uv_offset = UV - center;
    float dist = length(uv_offset);

    // Si está fuera del radio útil circular, transparentar
    if (dist > border_radius) {
        COLOR = vec4(0.0);
    } else {
        // Modular por máscara PNG
        float mask_val = 1.0;
        if (use_mask_texture) {
            mask_val = texture(mask_texture, UV).r;
        }

        if (mask_val < 0.1) {
            COLOR = vec4(0.0);
        } else {
            // Color base de fondo del radar
            vec4 final_color = bg_color;

            // Viñeta sutil hacia el borde interior
            float vignette = smoothstep(border_radius, border_radius * 0.4, dist);
            final_color.rgb *= mix(0.75, 1.15, vignette);

            // 1. Grilla cartesiana de cuadraditos (Dragon Radar Clásico)
            vec2 grid_uv = uv_offset / (border_radius * 2.0); // [-0.5, 0.5]
            vec2 cell_fract = abs(fract(grid_uv * grid_divisions) - 0.5);
            vec2 cell_dist = (0.5 - cell_fract) / grid_divisions * (border_radius * 2.0);
            float grid_x = smoothstep(line_thickness, 0.0, cell_dist.x);
            float grid_y = smoothstep(line_thickness, 0.0, cell_dist.y);
            float grid_mask = clamp(grid_x + grid_y, 0.0, 1.0);

            // Resaltar ejes centrales (cruz mayor)
            float axis_x = smoothstep(line_thickness * 1.5, 0.0, abs(uv_offset.x));
            float axis_y = smoothstep(line_thickness * 1.5, 0.0, abs(uv_offset.y));
            float axis_mask = clamp(axis_x + axis_y, 0.0, 1.0);

            final_color = mix(final_color, grid_color, max(grid_mask * 0.7, axis_mask) * grid_color.a);

            // 2. Haz de barrido rotativo (Sweep Beam) con estela degradada
            float angle = atan(uv_offset.y, uv_offset.x);
            if (angle < 0.0) {
                angle += 6.28318530718;
            }

            float angle_diff = sweep_angle - angle;
            if (angle_diff < 0.0) {
                angle_diff += 6.28318530718;
            }

            if (angle_diff <= sweep_tail_length) {
                float tail_factor = 1.0 - (angle_diff / sweep_tail_length);
                float sweep_intensity = pow(tail_factor, 1.8);
                vec4 active_sweep = sweep_color * sweep_intensity;
                final_color.rgb += active_sweep.rgb * active_sweep.a;
                final_color.a = max(final_color.a, active_sweep.a * 0.7);
            }

            COLOR = final_color * mask_val;
        }
    }
}
