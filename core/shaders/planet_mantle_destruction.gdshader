shader_type canvas_item;

// Manto Interior Planetario (Magma / Roca profunda / Hielo)
// Máscara angular de daño en 8 sectores (0.0 = intacto, 1.0 = completamente destruido/desprendido)
uniform float sector_damage[8];
uniform float inner_radius_ratio = 0.0917; // Radio de la cavidad central del núcleo (55 / 600)
uniform float outer_radius_ratio = 0.3167; // Radio perimetral exterior del manto (190 / 600)
uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.15, 1.0);

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 dir = UV - center;
    float dist = length(dir);
    
    // El manto sólo existe entre inner_radius_ratio y outer_radius_ratio
    // Fuera del manto (espacio/corteza) -> descartar
    if (dist > outer_radius_ratio) {
        discard;
    }
    // En la cavidad central del núcleo -> descartar para revelar el PlanetCore
    if (dist < inner_radius_ratio) {
        discard;
    }
    
    // Calcular ángulo continuo normalizado [0, 8)
    float angle = atan(dir.y, dir.x);
    if (angle < 0.0) {
        angle += 6.28318530718;
    }
    float norm_sector = (angle / 6.28318530718) * 8.0;
    int idx = int(floor(norm_sector)) % 8;
    
    // Interpolar suavemente entre sectores adyacentes
    int next_idx = (idx + 1) % 8;
    float frac = fract(norm_sector);
    float dmg = mix(sector_damage[idx], sector_damage[next_idx], smoothstep(0.35, 0.65, frac));
    
    // Ruido angular para fracturas geológicas profundas
    float jagged = sin(angle * 28.0 + dist * 36.0) * 0.025 * dmg;
    float effective_dmg = clamp(dmg + jagged, 0.0, 1.0);
    
    // Umbral de erosión del manto desde outer_radius_ratio hacia inner_radius_ratio
    float erosion_threshold = mix(outer_radius_ratio + 0.01, inner_radius_ratio, effective_dmg);
    
    // Si la brecha se abrió por daño en este sector
    if (dist > erosion_threshold && dmg > 0.04) {
        discard; // Manto destruido, túnel abierto directo al núcleo
    }
    
    // Si el sector del manto está completamente destruido, descartar todo el sector
    if (effective_dmg >= 0.95) {
        discard;
    }
    
    vec4 base_col = texture(TEXTURE, UV);
    
    // Resplandor geotérmico / núcleo energético en los bordes rotos
    float edge_dist = abs(dist - erosion_threshold);
    if (edge_dist < 0.025 && dmg > 0.08) {
        float glow_factor = (1.0 - (edge_dist / 0.025)) * (dmg * 1.8);
        base_col.rgb = mix(base_col.rgb, glow_color.rgb * 2.0, clamp(glow_factor, 0.0, 0.95));
    }
    
    COLOR = base_col;
}
