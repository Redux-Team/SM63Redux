shader_type canvas_item;


uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.5;
uniform float fisheye_strength : hint_range(0.0, 1.0) = 0.3;
uniform float zoom_velocity = 0.0;


void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float dist = length(centered_uv);
	float pulse = abs(zoom_velocity) * fisheye_strength;
	vec2 distorted_uv = centered_uv * (1.0 + pulse * dist * dist) + vec2(0.5);
	vec4 color = texture(screen_texture, distorted_uv);
	float vignette = 1.0 - smoothstep(0.0, vignette_softness, dist * pulse * vignette_strength);
	COLOR = vec4(color.rgb * vignette, color.a);
}