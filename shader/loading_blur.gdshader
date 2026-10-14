shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.106, 0.165, 0.255, 0.55);
uniform float blur : hint_range(0.0, 16.0) = 9.0;

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

void fragment() {
	vec2 size = vec2(textureSize(screen_texture, 0));
	float lod = max(log2(max(blur, 1.0)), 0.0);
	vec4 col = vec4(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 offset = vec2(float(x), float(y)) * (blur / size);
			float weight = exp(-float(x * x + y * y) / 4.0);
			col += textureLod(screen_texture, SCREEN_UV + offset, lod) * weight;
			total += weight;
		}
	}
	
	col /= total;
	COLOR = vec4(mix(col.rgb, tint.rgb, tint.a), vertex_color.a);
}
