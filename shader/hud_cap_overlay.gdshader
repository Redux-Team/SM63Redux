shader_type canvas_item;

#include "res://shader/hud_cap.gdshaderinc"

uniform vec2 center = vec2(32.0, 32.0);


void fragment() {
	COLOR = hud_apply_caps(COLOR, floor(UV / TEXTURE_PIXEL_SIZE), center, 1.0 / TEXTURE_PIXEL_SIZE);
}
