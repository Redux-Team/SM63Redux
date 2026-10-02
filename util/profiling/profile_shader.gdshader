shader_type canvas_item;
render_mode unshaded;

uniform sampler2D noise_texture : filter_linear, repeat_enable;
uniform int iterations = 1;

void fragment() {
	vec2 p = UV;
	vec4 acc = vec4(0.0);
	for (int i = 0; i < iterations; i++) {
		p = fract(p * 1.37 + vec2(0.11, 0.07));
		acc += texture(noise_texture, p) * vec4(sin(p.x * 6.283), cos(p.y * 6.283), p.x, 1.0);
	}
	COLOR = acc / float(max(iterations, 1));
}