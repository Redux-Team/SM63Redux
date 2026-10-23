shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform int thickness : hint_range(1, 8) = 1;


void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	float edge = 0.0;
	
	for (int x = -thickness; x <= thickness; x++) {
		for (int y = -thickness; y <= thickness; y++) {
			edge = max(
				edge,
				alpha - texture(
					TEXTURE,
					UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE
				).a
			);
		}
	}
	
	COLOR = vec4(outline_color.rgb, outline_color.a * step(0.5, edge));
}
