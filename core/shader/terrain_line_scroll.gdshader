shader_type canvas_item;

uniform float scroll_speed : hint_range(-10.0, 10.0) = 0.0;
uniform float ripple_amplitude : hint_range(0.0, 50.0) = 0.0;
uniform float ripple_frequency : hint_range(0.0, 20.0) = 1.0;
uniform float ripple_speed : hint_range(-10.0, 10.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	uv.x += TIME * scroll_speed;
	uv.y += sin(uv.x * ripple_frequency + TIME * ripple_speed) * ripple_amplitude * TEXTURE_PIXEL_SIZE.y;
	COLOR = texture(TEXTURE, uv);
}