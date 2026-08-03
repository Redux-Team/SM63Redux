shader_type canvas_item;

// A 9x9 gaussian cost 81 screen samples per pixel every frame the window was open. The
// same look comes out of a 3x3 kernel reading a pre-filtered mip: the mip supplies the
// fine blur, the kernel the spread.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 0.4);
uniform float blur : hint_range(0.0, 16.0) = 8.0;

void fragment() {
	vec2 size = vec2(textureSize(screen_texture, 0));
	float lod = max(log2(max(blur, 1.0)), 0.0);
	vec4 col = vec4(0.0);
	float total = 0.0;
	
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 offset = vec2(float(x), float(y)) * (blur * 2.0 / size);
			float weight = exp(-float(x * x + y * y) / 2.0);
			col += textureLod(screen_texture, SCREEN_UV + offset, lod) * weight;
			total += weight;
		}
	}
	
	col /= total;
	COLOR = mix(col, vec4(tint.rgb, 1.0), tint.a);
	COLOR.a = 1.0;
}
