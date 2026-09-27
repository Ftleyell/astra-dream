shader_type canvas_item;

uniform int star_level : hint_range(1, 3) = 1;
uniform vec4 glow_color : source_color = vec4(0.0, 0.94, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.0, 0.5, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_speed : hint_range(0.1, 10.0) = 2.5;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    if (star_level <= 1) {
        // 1★: Pure base recolor texture
        COLOR = tex_color;
    } else if (star_level == 2) {
        // 2★: Pulsating rim glow / neon bloom
        float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
        float alpha = tex_color.a;
        
        // Edge detection / outline glow approximation
        vec2 size = TEXTURE_PIXEL_SIZE * 2.0;
        float a_up = texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
        float a_down = texture(TEXTURE, UV + vec2(0.0, size.y)).a;
        float a_left = texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
        float a_right = texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
        float outline = clamp((a_up + a_down + a_left + a_right) - (alpha * 4.0), 0.0, 1.0);
        
        vec3 final_rgb = tex_color.rgb;
        if (alpha > 0.01) {
            final_rgb += glow_color.rgb * (pulse * 0.35 * glow_intensity);
        }
        if (outline > 0.1 && alpha < 0.9) {
            final_rgb = mix(final_rgb, glow_color.rgb, outline * pulse);
            alpha = max(alpha, outline * pulse * 0.85);
        }
        COLOR = vec4(final_rgb, alpha);
    } else {
        // 3★: Advanced iridescent shimmer, double aura and diamond shine
        float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
        float shimmer = 0.5 + 0.5 * sin((UV.x + UV.y) * 8.0 + TIME * 4.0);
        float alpha = tex_color.a;
        
        vec2 size = TEXTURE_PIXEL_SIZE * 3.5;
        float a_up = texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
        float a_down = texture(TEXTURE, UV + vec2(0.0, size.y)).a;
        float a_left = texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
        float a_right = texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
        float outline = clamp((a_up + a_down + a_left + a_right) - (alpha * 4.0), 0.0, 1.0);
        
        vec3 aura_mix = mix(glow_color.rgb, accent_color.rgb, shimmer);
        vec3 final_rgb = tex_color.rgb + aura_mix * (0.45 * pulse * glow_intensity);
        
        if (outline > 0.05) {
            final_rgb = mix(final_rgb, aura_mix, outline);
            alpha = max(alpha, outline * 0.9);
        }
        COLOR = vec4(final_rgb, alpha);
    }
}
