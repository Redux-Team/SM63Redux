shader_type canvas_item;
render_mode unshaded;

uniform int thickness : hint_range(1, 8) = 1;
uniform float saturation : hint_range(0.0, 1.0, 0.01) = 0.8;
uniform float brightness : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float cycle_speed = 1.2;
uniform float spread = 0.03;
uniform float fill_alpha : hint_range(0.0, 1.0, 0.01) = 0.0;

varying vec2 local_position;
varying float modulate_alpha;


void vertex() {
	local_position = VERTEX;
	modulate_alpha = COLOR.a;
}


vec3 hue_to_rgb(float hue) {
	vec3 channels = clamp(abs(mod(hue * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return brightness * mix(vec3(1.0), channels, saturation);
}


void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	float edge = 0.0;
	
	for (int x = -thickness; x <= thickness; x++) {
		for (int y = -thickness; y <= thickness; y++) {
			edge = max(edge, alpha - texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE).a);
		}
	}
	
	vec2 pixel = floor(local_position);
	float hue = fract(TIME * cycle_speed - (pixel.x + pixel.y) * spread);
	COLOR = vec4(hue_to_rgb(hue), max(step(0.5, edge), step(0.5, alpha) * fill_alpha) * modulate_alpha);
}
