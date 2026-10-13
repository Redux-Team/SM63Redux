shader_type canvas_item;


uniform ivec2 frame_count = ivec2(2, 2);
uniform float expand_reduce: hint_range(-1.0, 1.0) = 0.01;


void vertex() {
	vec2 frames = vec2(frame_count);
	float total = frames.x * frames.y;
	
	VERTEX.xy /= frames;
	UV /= frames;
	
	float chosen = mod(floor(INSTANCE_CUSTOM.z * total), total);
	UV += vec2(
		mod(chosen, frames.x) / frames.x,
		floor((chosen + 0.5) / frames.x) / frames.y
	);
}


void fragment() {
	float a = COLOR.a * (1.0 + expand_reduce);
	a += texture(TEXTURE, UV).a;
	COLOR.a = floor(a);
}