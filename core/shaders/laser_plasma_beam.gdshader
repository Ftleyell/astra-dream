shader_type canvas_item;
render_mode blend_add;

// Shader de Plasma y Rayos de Energía de Alta Frecuencia
// Genera flujo dinámico de energía, pulsación UV y borde incandescente HDR.

uniform vec4 energy_tint : source_color = vec4(0.2, 0.95, 1.0, 1.0);
uniform float core_intensity : hint_range(1.0, 6.0) = 2.8;
uniform float scroll_speed : hint_range(0.0, 20.0) = 8.0;
uniform float frequency : hint_range(1.0, 40.0) = 14.0;
uniform float pulse_speed : hint_range(0.0, 20.0) = 10.0;

void fragment() {
    vec2 uv = UV;
    // Flujo continuo horizontal de plasma
    uv.x -= TIME * scroll_speed * 0.1;

    vec4 tex = texture(TEXTURE, uv);

    // Modulación de energía y oscilación de núcleo
    float pulse = 0.9 + 0.1 * sin(TIME * pulse_speed + UV.x * frequency);
    
    // Perfil vertical del núcleo (brillo central puro)
    float dist_from_center = abs(UV.y - 0.5) * 2.0;
    float core_boost = pow(clamp(1.0 - dist_from_center, 0.0, 1.0), 3.0);

    vec3 final_color = mix(energy_tint.rgb, vec3(1.0, 1.0, 1.0), core_boost * 0.85);
    final_color *= core_intensity * pulse;

    COLOR = vec4(final_color, tex.a * energy_tint.a);
}
