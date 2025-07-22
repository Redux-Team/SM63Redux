shader_type canvas_item;

uniform sampler2D color_texture : filter_nearest;
uniform sampler2D mask_texture : filter_nearest;
instance uniform vec2 mask_offset = vec2(0.0, 0.0);
instance uniform vec2 mask_scale = vec2(1.0, 1.0);
instance uniform vec2 color_offset = vec2(0.0, 0.0);
instance uniform vec2 color_scale = vec2(1.0, 1.0);

void fragment() {
	vec2 mask_uv = (UV - mask_offset) / mask_scale;
	float mask = texture(mask_texture, mask_uv).r;

	if (mask < 0.5) {
		discard;
	}

	vec2 color_uv = (UV - color_offset) / color_scale;
	COLOR = texture(color_texture, color_uv) * COLOR;
}
