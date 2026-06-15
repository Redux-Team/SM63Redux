shader_type canvas_item;

uniform sampler2D mask_texture : filter_nearest, repeat_disable;
uniform sampler2D color_texture : filter_nearest;
// Sweeps the wave: +1 = fully revealed, -1/(wave_scale/aspect) = fully covered.
uniform float mask_offset_y = 1.0;
// Horizontal tiling count, so a small wave texture can repeat across the screen.
uniform float wave_scale = 1.0;
// Screen aspect (width / height). The vertical scale is wave_scale / aspect so each wave keeps its
// true shape (square in pixels) instead of being squished into a thin cropped band.
uniform float aspect = 1.0;
// Flips the wave vertically (used so the out transition sweeps in from the opposite side).
uniform bool flip = false;

void fragment() {
	float sy = flip ? (1.0 - UV.y) : UV.y;
	float scale_y = wave_scale / aspect;
	// Tile horizontally via fract; scale and clamp vertically (proportional to the horizontal
	// tiling via the aspect) so beyond the texture stays solid and the sweep fully covers.
	vec2 mask_uv = vec2(fract(UV.x * wave_scale), clamp((sy - mask_offset_y) * scale_y, 0.0, 1.0));
	float mask = texture(mask_texture, mask_uv).r;
	if (mask < 0.5) {
		discard;
	}
	COLOR = texture(color_texture, UV) * COLOR;
}
