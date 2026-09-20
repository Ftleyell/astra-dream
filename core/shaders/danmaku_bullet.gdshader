shader_type canvas_item;
render_mode blend_add;

uniform int h_frames = 8;
uniform int v_frames = 8;

varying vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	float frame = INSTANCE_CUSTOM.r;
	
	float u_width = 1.0 / float(h_frames);
	float v_height = 1.0 / float(v_frames);
	float u_offset = mod(frame, float(h_frames)) * u_width;
	float v_offset = floor(frame / float(h_frames)) * v_height;
	
	UV.x = UV.x * u_width + u_offset;
	UV.y = UV.y * v_height + v_offset;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = tex * vec4(v_custom.gba, 1.0);
}
