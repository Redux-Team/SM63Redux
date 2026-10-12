shader_type canvas_item;

uniform sampler2D mask_texture : filter_nearest, repeat_disable;
uniform sampler2D color_texture : filter_nearest;
uniform float mask_offset_y = 1.0;
uniform float wave_scale = 1.0;
uniform float aspect = 1.0;
uniform bool flip = false;

void fragment() {
	float sy = flip ? (1.0 - UV.y) : UV.y;
	float scale_y = wave_scale / aspect;
	vec2 mask_uv = vec2(fract(UV.x * wave_scale), clamp((sy - mask_offset_y) * scale_y, 0.0, 1.0));
	float mask = texture(mask_texture, mask_uv).r;
	if (mask < 0.5) {
		discard;
	}
	COLOR = texture(color_texture, UV) * COLOR;
}
