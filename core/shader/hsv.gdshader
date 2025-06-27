shader_type canvas_item;

uniform float hue_shift : hint_range(-1.0, 1.0) = 0.0;
uniform float saturation_scale : hint_range(0.0, 2.0) = 1.0;
uniform float value_scale : hint_range(0.0, 2.0) = 1.0;
uniform vec4 modulate_color : source_color = vec4(1, 1, 1, 1);

vec3 rgb_to_hsv(vec3 color) {
	float max_c = max(color.r, max(color.g, color.b));
	float min_c = min(color.r, min(color.g, color.b));
	float delta = max_c - min_c;

	float h = 0.0;
	if (delta != 0.0) {
		if (max_c == color.r) {
			h = mod((color.g - color.b) / delta, 6.0);
		} else if (max_c == color.g) {
			h = ((color.b - color.r) / delta) + 2.0;
		} else {
			h = ((color.r - color.g) / delta) + 4.0;
		}
		h /= 6.0;
	}

	float s = (max_c == 0.0) ? 0.0 : (delta / max_c);
	float v = max_c;

	return vec3(h, s, v);
}

vec3 hsv_to_rgb(vec3 hsv) {
	float h = hsv.x * 6.0;
	float s = hsv.y;
	float v = hsv.z;

	int i = int(floor(h));
	float f = h - float(i);
	float p = v * (1.0 - s);
	float q = v * (1.0 - s * f);
	float t = v * (1.0 - s * (1.0 - f));

	if (i == 0) return vec3(v, t, p);
	if (i == 1) return vec3(q, v, p);
	if (i == 2) return vec3(p, v, t);
	if (i == 3) return vec3(p, q, v);
	if (i == 4) return vec3(t, p, v);
	return vec3(v, p, q);
}

void fragment() {
	vec4 src_color = texture(TEXTURE, UV);
	vec3 hsv = rgb_to_hsv(src_color.rgb);

	hsv.x = mod(hsv.x + hue_shift, 1.0);
	hsv.y = clamp(hsv.y * saturation_scale, 0.0, 1.0);
	hsv.z = clamp(hsv.z * value_scale, 0.0, 1.0);

	vec3 final_color = hsv_to_rgb(hsv);
	COLOR = vec4(final_color, src_color.a) * modulate_color;
}
