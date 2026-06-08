shader_type canvas_item;

uniform sampler2D mask_texture : filter_nearest;
uniform float mask_scale = 1.0;

void fragment() {
	vec2 centered_uv = (UV - vec2(0.5)) / vec2(mask_scale) + vec2(0.5);
	vec4 mask = texture(mask_texture, centered_uv);
	if (mask.a > 0.1) {
		discard;
	}
}