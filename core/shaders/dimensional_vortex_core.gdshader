shader_type canvas_item;
render_mode blend_mix;

// Shader de Vórtice Dimensional para Crescent Cyclone de Nyx
// Genera remolino de vacío giratorio, horizonte de corte dimensional y aura magenta.

uniform vec4 void_color : source_color = vec4(0.08, 0.01, 0.12, 0.85);
uniform vec4 rim_color : source_color = vec4(0.85, 0.18, 0.95, 0.7);
uniform float swirl_speed : hint_range(0.0, 20.0) = 9.0;
uniform float distortion_arms : hint_range(1.0, 8.0) = 3.0;

void fragment() {
    // Coordenadas centradas de -1.0 a +1.0
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float dist = length(p);

    if (dist > 1.0) {
        discard;
    }

    float angle = atan(p.y, p.x);
    // Espiral de torsión hacia el núcleo
    float swirl = angle + (1.0 - dist) * 4.5 - TIME * swirl_speed;

    // Brazos de energía en espiral
    float arm_pattern = sin(swirl * distortion_arms) * 0.5 + 0.5;
    arm_pattern = pow(arm_pattern, 2.0);

    // Borde exterior incandescente y núcleo profundo de vacío
    float rim = smoothstep(0.55, 0.98, dist);
    float core_depth = 1.0 - smoothstep(0.0, 0.65, dist);

    vec3 col = mix(void_color.rgb, rim_color.rgb, rim * (0.6 + 0.4 * arm_pattern));
    col += rim_color.rgb * arm_pattern * 0.5 * (1.0 - core_depth);

    float alpha = clamp((rim * rim_color.a + core_depth * void_color.a) * (1.0 - smoothstep(0.92, 1.0, dist)), 0.0, 1.0);

    COLOR = vec4(col, alpha);
}
