shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture :
	hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 tint : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.88, 0.96, 1.0, 1.0);
uniform vec4 fringe_warm : source_color = vec4(1.0, 0.35, 0.7, 1.0);
uniform vec4 fringe_cool : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float body_alpha : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float edge_alpha : hint_range(0.0, 1.0, 0.01) = 0.7;
uniform float fringe_alpha : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float fringe_offset : hint_range(0.0, 4.0, 1.0) = 1.0;
uniform float stripe_alpha : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float stripe_brightness : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float stripe_spacing : hint_range(2.0, 16.0, 1.0) = 4.0;
uniform float stripe_speed = 12.0;

varying vec2 local_position;
varying float pixel_scale;


void vertex() {
	local_position = VERTEX;
	pixel_scale = length(CANVAS_MATRIX[0].xy);
}


float alpha_at(vec2 uv) {
	return step(0.5, textureLod(screen_texture, uv, 0.0).a);
}


void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE * pixel_scale;
	float row = floor(local_position.y);
	vec4 source = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (source.a > 0.0001) {
		source.rgb /= source.a;
	}
	
	float mask = step(0.5, source.a);
	float neighbours = min(
		min(
			alpha_at(SCREEN_UV + vec2(pixel.x, 0.0)),
			alpha_at(SCREEN_UV - vec2(pixel.x, 0.0))
		),
		min(
			alpha_at(SCREEN_UV + vec2(0.0, pixel.y)),
			alpha_at(SCREEN_UV - vec2(0.0, pixel.y))
		)
	);
	float edge = mask * (1.0 - neighbours);
	float stripe = step(
		stripe_spacing - 1.0,
		mod(row + floor(TIME * stripe_speed), stripe_spacing)
	);
	
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 body = mix(source.rgb, tint.rgb * (0.5 + luminance), tint_strength);
	body = mix(body, edge_color.rgb, max(edge, stripe * stripe_brightness));
	float body_out = mask * mix(
		body_alpha + stripe * stripe_alpha,
		edge_alpha,
		edge
	);
	
	vec2 shift = vec2(fringe_offset * pixel.x, 0.0);
	float warm = max(alpha_at(SCREEN_UV + shift) - mask, 0.0) * fringe_alpha;
	float cool = max(alpha_at(SCREEN_UV - shift) - mask, 0.0) * fringe_alpha;
	float fringe_out = max(warm, cool);
	vec3 fringe = (
		(fringe_warm.rgb * warm + fringe_cool.rgb * cool)
		/ max(warm + cool, 0.0001)
	);
	
	float alpha = body_out + fringe_out * (1.0 - body_out);
	vec3 rgb = (
		(body * body_out + fringe * fringe_out * (1.0 - body_out))
		/ max(alpha, 0.0001)
	);
	COLOR *= vec4(rgb, alpha);
}
