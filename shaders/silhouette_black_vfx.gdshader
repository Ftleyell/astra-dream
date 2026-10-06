shader_type canvas_item;

// SilhouetteBlackVFX.gdshader
// Silueta oscura con halo perimetral tenue para ítems bloqueados.
// Sigue el contorno exacto del asset oscureciendo el interior y resaltando el perímetro.

uniform vec4 silhouette_color : source_color = vec4(0.005, 0.01, 0.02, 0.98);
uniform vec4 outline_color : source_color = vec4(0.04, 0.08, 0.16, 0.85);
uniform float outline_width : hint_range(0.0, 5.0) = 1.5;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    if (col.a <= 0.01) {
        discard;
    }

    vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
    float a_up = texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
    float a_down = texture(TEXTURE, UV + vec2(0.0, size.y)).a;
    float a_left = texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
    float a_right = texture(TEXTURE, UV + vec2(size.x, 0.0)).a;

    // Detectar borde donde algún vecino sea transparente
    float min_neighbor_a = min(min(a_up, a_down), min(a_left, a_right));
    float is_edge = clamp(1.0 - min_neighbor_a, 0.0, 1.0);

    vec4 final_color = mix(silhouette_color, outline_color, is_edge * 0.75);
    final_color.a *= col.a;

    COLOR = final_color;
}
