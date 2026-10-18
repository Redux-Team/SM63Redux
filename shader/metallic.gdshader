shader_type canvas_item;

uniform sampler2D ramp : source_color, filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(0.85, 0.9, 1.0, 1.0);
uniform vec4 accent : source_color = vec4(0.54, 0.36, 0.78, 1.0);
uniform float accent_strength : hint_range(0.0, 1.0, 0.05) = 0.4;
uniform float ramp_contrast : hint_range(0.5, 3.0, 0.05) = 1.4;
uniform float sheen_strength : hint_range(0.0, 1.0, 0.05) = 0.35;
uniform float sheen_width : hint_range(1.0, 32.0, 1.0) = 5.0;
uniform float sheen_interval = 180.0;
uniform float sheen_speed = 60.0;
uniform float sheen_slant = 0.6;
uniform float rim_strength : hint_range(0.0, 1.0, 0.05) = 0.45;
uniform vec2 light_direction = vec2(-1.0, -1.0);

varying vec2 local_position;


void vertex() {
	local_position = VERTEX;
}


float luminance(vec3 col) {
	return dot(col, vec3(0.299, 0.587, 0.114));
}


float sheen(vec2 pos) {
	vec2 pixel = floor(pos);
	float band = pixel.x + pixel.y * sheen_slant - TIME * sheen_speed;
	float distance_to_band = abs(mod(band, sheen_interval) - sheen_interval * 0.5);
	return 1.0 - smoothstep(0.0, sheen_width, distance_to_band);
}


void fragment() {
	vec4 col = COLOR;
	float lum = clamp((luminance(col.rgb) - 0.5) * ramp_contrast + 0.5, 0.0, 1.0);
	vec3 metal = texture(ramp, vec2(lum, 0.5)).rgb * tint.rgb;
	metal += sheen(local_position) * sheen_strength;
	float rim = 1.0 - step(0.5, texture(TEXTURE, UV + sign(light_direction) * TEXTURE_PIXEL_SIZE).a);
	metal += mix(vec3(1.0), accent.rgb, accent_strength) * rim * rim_strength;
	COLOR = vec4(min(metal, vec3(1.0)), col.a);
}
