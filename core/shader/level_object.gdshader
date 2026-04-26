shader_type canvas_item;
uniform int palette_index: hint_range(0, 16) = 0;
uniform sampler2D palette_texture: filter_nearest, repeat_disable;

vec3 swap_palette(sampler2D pal, vec3 rgb, vec2 pal_size) {
	if (palette_index <= 0) {
		return rgb;
	}
	float palette_row = float(palette_index) / pal_size.y;
	if (palette_row >= 1.0) {
		return rgb;
	}
	float base_row = 0.5 / pal_size.y;
	float target_row = (float(palette_index) + 0.5) / pal_size.y;
	int col_count = int(pal_size.x);
	float best_dist = 0.0001;
	vec3 result = rgb;
	for (int i = 0; i < col_count; i++) {
		float u = (float(i) + 0.5) / pal_size.x;
		vec3 src = texture(pal, vec2(u, base_row)).rgb;
		vec3 diff = rgb - src;
		float dist = dot(diff, diff);
		if (dist < best_dist) {
			best_dist = dist;
			result = texture(pal, vec2(u, target_row)).rgb;
		}
	}
	return result;
}

void fragment() {
	vec2 pal_size = vec2(textureSize(palette_texture, 0));
	vec4 tex = texture(TEXTURE, UV);
	vec4 tex_swapped = vec4(swap_palette(palette_texture, tex.rgb, pal_size), tex.a);
	COLOR = tex_swapped;
}