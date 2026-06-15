shader_type canvas_item;

// Recolors a background layer by converting it to grayscale (luminance) and multiplying by this
// tint, so one color restyles the whole layer regardless of its original hues. Alpha is preserved.
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(luma) * tint_color.rgb, tex.a * tint_color.a);
}
