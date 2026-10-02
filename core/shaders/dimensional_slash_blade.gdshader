shader_type canvas_item;
render_mode blend_add;

// Shader de Hoja Dimensional de Nyx (Dimensional Blade Slash)
// Genera flujo de energía astral, núcleo incandescente en el filo,
// filamentos de plasma y disolución etérea en la espalda del corte.

uniform vec4 blade_color : source_color = vec4(0.95, 0.2, 0.98, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.95, 1.0, 1.0);
uniform vec4 edge_glow_color : source_color = vec4(0.65, 0.1, 1.0, 1.0);

uniform float energy_intensity : hint_range(1.0, 5.0) = 2.4;
uniform float flow_speed : hint_range(0.0, 20.0) = 8.0;
uniform float slash_progress : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec2 uv = UV;

    // 1. Flujo continuo de plasma dimensional a lo largo del arco
    float time_flow = TIME * flow_speed;
    float wave1 = sin(uv.x * 22.0 - time_flow * 1.5) * 0.5 + 0.5;
    float wave2 = sin(uv.x * 45.0 + time_flow * 2.2 + uv.y * 12.0) * 0.5 + 0.5;
    float plasma_noise = mix(wave1, wave2, 0.45);

    // 2. Perfil transversal (UV.y: 0.0 espalda cóncava -> 1.0 filo exterior afilado)
    // El filo exterior (y=1.0) es incandescente y afilado; el interior (y=0.0) se disuelve en vacío
    float edge_falloff = pow(clamp(uv.y, 0.0, 1.0), 1.8);
    float sharp_blade_edge = smoothstep(0.72, 1.0, uv.y); // filo blanco ultra-caliente

    // 3. Perfil longitudinal (puntas afiladas en uv.x = 0.0 y uv.x = 1.0, panza en uv.x = 0.5)
    float tip_falloff = sin(clamp(uv.x, 0.0, 1.0) * 3.14159265);
    tip_falloff = pow(tip_falloff, 0.6); // Mantiene cuerpo en la panza y afila las puntas

    // 4. Filamentos de corte y crepitación astral
    float filaments = pow(plasma_noise, 2.5) * edge_falloff * 1.4;

    // 5. Composición cromática multicapa
    // Base: púrpura astral profundo
    vec3 col = mix(edge_glow_color.rgb, blade_color.rgb, edge_falloff);
    // Filamentos de plasma
    col += blade_color.rgb * filaments;
    // Filo de corte hiper-brillante blanco
    col = mix(col, core_color.rgb, sharp_blade_edge * 0.9);

    // Multiplicador de brillo y fade en puntas
    col *= energy_intensity * (0.85 + 0.15 * plasma_noise);
    float alpha = edge_falloff * tip_falloff * blade_color.a * slash_progress;

    // Compresión suave anti-blowout
    col = col / (1.0 + col * 0.12);

    COLOR = vec4(col, clamp(alpha, 0.0, 1.0)) * COLOR;
}
