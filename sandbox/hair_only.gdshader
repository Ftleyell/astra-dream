shader_type canvas_item;

uniform float wind_speed : hint_range(0.0, 30.0) = 14.0;
uniform float wave_freq : hint_range(0.0, 40.0) = 18.0;
uniform float hair_amp : hint_range(0.0, 0.05) = 0.025;

void fragment() {
	vec2 uv = UV;
	
	// Máscara procedural precisa para las dos coletas de Nova:
	// Las coletas están en la mitad superior (UV.y < 0.65) y hacia los extremos laterales (UV.x < 0.38 o UV.x > 0.62)
	float is_left_hair = smoothstep(0.42, 0.25, uv.x) * smoothstep(0.7, 0.2, uv.y);
	float is_right_hair = smoothstep(0.58, 0.75, uv.x) * smoothstep(0.7, 0.2, uv.y);
	
	// Flameo asimétrico continuo
	float wave_l = sin((uv.y * wave_freq) + (TIME * wind_speed)) * hair_amp * is_left_hair;
	float wave_r = sin((uv.y * wave_freq) + (TIME * wind_speed) + 1.7) * hair_amp * is_right_hair;
	
	uv.x += (wave_l + wave_r);
	COLOR = texture(TEXTURE, uv);
}