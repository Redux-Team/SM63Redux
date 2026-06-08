shader_type canvas_item;

uniform sampler2D mask_texture : filter_nearest;
uniform sampler2D color_texture : filter_nearest;
uniform float mask_offset_y = 1.0;

void fragment() {
	vec2 mask_uv = vec2(UV.x, UV.y - mask_offset_y);
	float mask = texture(mask_texture, mask_uv).r;
	if (mask < 0.5) {
		discard;
	}
	COLOR = texture(color_texture, UV) * COLOR;
}