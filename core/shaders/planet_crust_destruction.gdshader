shader_type canvas_item;

// Corteza Exterior Planetaria (Superficie con continentes, océanos, atmósfera)
// Máscara angular de daño en 8 sectores (0.0 = intacto, 1.0 = completamente destruido/desprendido)
uniform float sector_damage[8];
uniform float inner_radius_ratio = 0.3167; // Radio del manto interior (190 / 600)
uniform float outer_radius_ratio = 0.50; // Radio perimetral exterior de la corteza (300 / 600)
uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.15, 1.0);

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 dir = UV - center;
    float dist = length(dir);
    
    // Si está fuera del disco esférico planetario, descartar
    if (dist > outer_radius_ratio) {
        discard;
    }
    
    // Calcular ángulo continuo normalizado [0, 8)
    float angle = atan(dir.y, dir.x);
    if (angle < 0.0) {
        angle += 6.28318530718;
    }
    float norm_sector = (angle / 6.28318530718) * 8.0;
    int idx = int(floor(norm_sector)) % 8;
    
    // Interpolar suavemente entre sectores adyacentes para una transición orgánica de grietas
    int next_idx = (idx + 1) % 8;
    float frac = fract(norm_sector);
    float dmg = mix(sector_damage[idx], sector_damage[next_idx], smoothstep(0.35, 0.65, frac));
    
    // Ruido angular simulado para bordes quebrados irregulares en lugar de cortes rectos
    float jagged = sin(angle * 24.0 + dist * 30.0) * 0.03 * dmg;
    float effective_dmg = clamp(dmg + jagged, 0.0, 1.0);
    
    // Umbral de erosión desde afuera hacia adentro
    float erosion_threshold = mix(outer_radius_ratio + 0.02, inner_radius_ratio, effective_dmg);
    
    // Si el daño en este sector supera el umbral de erosión exterior
    if (dist > erosion_threshold && dmg > 0.04) {
        // Brecha abierta: la corteza se ha desprendido en esta zona revelando el manto debajo
        discard;
    }
    
    // Si el sector de corteza está completamente destruido, descartar todo el sector
    // para no tapar el manto ni el núcleo subyacente
    if (effective_dmg >= 0.95) {
        discard;
    }
    
    vec4 base_col = texture(TEXTURE, UV);
    
    // Grietas térmicas en todo el sector dañado (visibles atacando desde adentro o afuera)
    if (dmg > 0.08) {
        float cracks = abs(sin(angle * 28.0 + dist * 35.0));
        if (cracks < 0.12 * dmg) {
            float crack_glow = (1.0 - (cracks / (0.12 * dmg))) * dmg;
            base_col.rgb = mix(base_col.rgb, glow_color.rgb * 2.0, clamp(crack_glow, 0.0, 0.9));
        }
    }
    
    // Borde incandescente / resplandor térmico de fractura cerca del borde carcomido
    float edge_dist = abs(dist - erosion_threshold);
    if (edge_dist < 0.03 && dmg > 0.08) {
        float glow_factor = (1.0 - (edge_dist / 0.03)) * (dmg * 1.6);
        base_col.rgb = mix(base_col.rgb, glow_color.rgb * 1.8, clamp(glow_factor, 0.0, 0.9));
    }
    
    COLOR = base_col;
}
