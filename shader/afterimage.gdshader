shader_type canvas_item;

uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.85;

varying vec4 modulate_color;


void vertex() {
	modulate_color = COLOR;
}


void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	COLOR = vec4(
		mix(texel.rgb, modulate_color.rgb, tint_strength),
		texel.a * modulate_color.a
	);
}
