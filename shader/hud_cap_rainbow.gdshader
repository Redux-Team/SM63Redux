shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0, 0.001) = 1.0;
uniform float half_width = 32.0;
uniform float fill_left : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float fill_right : hint_range(0.0, 1.0, 0.001) = 1.0;
uniform float saturation : hint_range(0.0, 1.0, 0.01) = 0.85;
uniform float shading : hint_range(0.0, 1.0, 0.01) = 0.6;
uniform float cycle_speed = 1.2;
uniform float spread = 0.03;

varying vec2 local_position;


void vertex() {
	local_position = VERTEX;
}


vec3 hue_to_rgb(float hue) {
	vec3 channels = clamp(abs(mod(hue * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return mix(vec3(1.0), channels, saturation);
}


void fragment() {
	vec4 col = COLOR;
	vec2 pixel = floor(local_position);
	float left = fill_left * half_width * 2.0;
	float ratio = (pixel.x + half_width + 0.5 - left) / (fill_right * half_width * 2.0 - left);
	float inside = step(ratio, progress) * step(0.0001, progress);
	
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rainbow = hue_to_rgb(fract(TIME * cycle_speed - (pixel.x + pixel.y) * spread)) * mix(1.0, lum * 1.6, shading);
	COLOR = vec4(mix(col.rgb, min(rainbow, vec3(1.0)), inside), col.a);
}
