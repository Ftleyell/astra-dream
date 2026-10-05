shader_type canvas_item;

// pilot_showcase_hologram.gdshader
// Shader de escaparate táctico para heroínas en Astra Dream.
// 1. Limpia halos y bordes residuales de extracción alfa.
// 2. Proyecta un rim-light perimetral con el color temático de la piloto.
// 3. Aplica desvanecimiento suave en la base inferior para encuadre orgánico (oculta cortes planos como el de Valentina).
// 4. Pulso de luminosidad sutil para vitalidad estética.

uniform vec4 rim_color : source_color = vec4(0.0, 0.94, 1.0, 1.0);
uniform float rim_thickness : hint_range(0.0, 6.0) = 2.2;
uniform float rim_intensity : hint_range(0.0, 2.5) = 1.25;
uniform float alpha_cutoff : hint_range(0.0, 0.2) = 0.04;
uniform float bottom_fade_start : hint_range(0.5, 1.0) = 0.88;
uniform float bottom_fade_power : hint_range(1.0, 4.0) = 1.8;
uniform float subtle_pulse_speed : hint_range(0.0, 5.0) = 1.2;
uniform float pulse_amplitude : hint_range(0.0, 0.3) = 0.06;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // 1. Descartar píxeles residuales con alfa extremadamente bajo
    if (tex_color.a < alpha_cutoff) {
        discard;
    }
    
    vec2 ps = TEXTURE_PIXEL_SIZE;
    
    // 2. Detección de silueta/borde para rim-light y limpieza de fringe
    float a_up    = texture(TEXTURE, UV + vec2(0.0, -rim_thickness) * ps).a;
    float a_down  = texture(TEXTURE, UV + vec2(0.0,  rim_thickness) * ps).a;
    float a_left  = texture(TEXTURE, UV + vec2(-rim_thickness, 0.0) * ps).a;
    float a_right = texture(TEXTURE, UV + vec2( rim_thickness, 0.0) * ps).a;
    
    float neighbor_min_a = min(min(a_up, a_down), min(a_left, a_right));
    float edge_factor = clamp(tex_color.a - neighbor_min_a, 0.0, 1.0);
    
    // Pulso sutil de energía
    float pulse = 1.0 + sin(TIME * subtle_pulse_speed) * pulse_amplitude;
    
    // Mezclar el color de la textura con el rim-light para disimular bordes oscuros residuales
    vec3 final_rgb = tex_color.rgb;
    final_rgb = mix(final_rgb, rim_color.rgb * rim_intensity * pulse, edge_factor * 0.75);
    
    // Aplicar leve realce interior del color temático en los bordes
    final_rgb += rim_color.rgb * edge_factor * 0.35 * rim_intensity;
    
    // 3. Desvanecimiento inferior suave para disimular cortes de rodilla/base
    float alpha = tex_color.a;
    if (UV.y > bottom_fade_start) {
        float t = (UV.y - bottom_fade_start) / (1.0 - bottom_fade_start);
        float fade = pow(1.0 - clamp(t, 0.0, 1.0), bottom_fade_power);
        alpha *= fade;
    }
    
    COLOR = vec4(final_rgb, alpha);
}
