shader_type canvas_item;

uniform float time_sec = 0.0;
uniform vec2 camera_offset = vec2(0.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * noise2(p);
		p *= 2.04;
		amp *= 0.5;
	}
	return v;
}

float star_layer(vec2 uv, float scale, float density) {
	vec2 gv = fract(uv * scale) - 0.5;
	vec2 id = floor(uv * scale);
	float rnd = hash21(id);
	if (rnd < density) {
		return 0.0;
	}
	vec2 jitter = vec2(fract(rnd * 37.1) - 0.5, fract(rnd * 91.7) - 0.5) * 0.65;
	float d = length(gv - jitter);
	float twinkle = 0.65 + 0.35 * sin(time_sec * (1.8 + rnd * 3.0) + rnd * 25.0);
	return smoothstep(0.08, 0.008, d) * twinkle;
}

void fragment() {
	vec2 uv = UV + camera_offset * 0.00025;
	vec3 bg = vec3(0.025, 0.032, 0.068);

	float n1 = fbm(uv * 3.2 + vec2(time_sec * 0.012, -time_sec * 0.008));
	float n2 = fbm(uv * 5.6 - vec2(time_sec * 0.015, time_sec * 0.010));

	bg += vec3(0.06, 0.03, 0.14) * smoothstep(0.35, 0.85, n1);
	bg += vec3(0.02, 0.08, 0.16) * smoothstep(0.45, 0.90, n2);

	float stars_far = star_layer(uv + camera_offset * 0.00008, 28.0, 0.84) * 0.55;
	float stars_near = star_layer(uv * 1.3 + camera_offset * 0.00018, 16.0, 0.91) * 0.95;

	bg += vec3(0.85, 0.90, 1.0) * (stars_far + stars_near);
	COLOR = vec4(bg, 1.0);
}
