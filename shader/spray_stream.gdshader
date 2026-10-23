shader_type canvas_item;

uniform vec4 body_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 top_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float uv_length = 10.0;
uniform float body_length = 29.0;
uniform float top_length = 0.0;
uniform float flow_speed = 280.0;
uniform float wobble_amount = 0.06;
uniform float wobble_frequency = 1.0;
uniform float wobble_speed = 8.0;
uniform float width_padding = 1.0;
uniform float tail_width_scale = 1.0;
uniform float tail_taper_start = 0.7;
uniform float tail_fade_start = 0.55;
instance uniform float line_length = 0.0;
instance uniform float tail_amount = 1.0;
instance uniform float stream_width = 1.0;

varying vec4 line_color;

vec2 region_uv(vec4 region, vec2 uv) {
	return region.xy + clamp(uv, 0.0, 0.999) * region.zw;
}

float ramp(float value, float start) {
	return clamp((value - start) / max(1.0 - start, 0.001), 0.0, 1.0);
}

void vertex() {
	line_color = COLOR;
}

void fragment() {
	float distance_along = UV.x * uv_length;
	float progress = clamp(distance_along / max(line_length, 0.001), 0.0, 1.0);
	float width_scale = (
		mix(
			1.0,
			mix(1.0, tail_width_scale, ramp(progress, tail_taper_start)),
			tail_amount
		)
		* stream_width
		/ width_padding
	);
	float across = (UV.y - 0.5) / width_scale + 0.5;
	float top = min(top_length, line_length);
	vec4 water;
	if (distance_along < top) {
		water = texture(
			TEXTURE,
			region_uv(
				top_region,
				vec2(across, (distance_along - top + top_length) / top_length)
			)
		);
	} else {
		float tiles = (distance_along - top - TIME * flow_speed) / body_length;
		across += (
			sin(tiles * wobble_frequency * TAU + TIME * wobble_speed)
			* wobble_amount
		);
		water = texture(
			TEXTURE,
			region_uv(body_region, vec2(across, fract(tiles)))
		);
	}
	
	water.a *= (
		step(0.0, across)
		* step(across, 1.0)
		* (1.0 - ramp(progress, tail_fade_start) * tail_amount)
	);
	COLOR = water * line_color;
}
