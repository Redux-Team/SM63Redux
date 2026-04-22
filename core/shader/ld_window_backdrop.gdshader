shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 0.4);
uniform float blur : hint_range(0.0, 16.0) = 8.0;

void fragment() {
	vec2 size = vec2(textureSize(screen_texture, 0));
	vec4 col = vec4(0.0);
	float total = 0.0;
	
	for (int x = -4; x <= 4; x++) {
		for (int y = -4; y <= 4; y++) {
			vec2 offset = vec2(float(x), float(y)) * (blur / size);
			float weight = exp(-float(x * x + y * y) / 8.0);
			col += texture(screen_texture, SCREEN_UV + offset) * weight;
			total += weight;
		}
	}
	
	col /= total;
	COLOR = mix(col, vec4(tint.rgb, 1.0), tint.a);
	COLOR.a = 1.0;
}