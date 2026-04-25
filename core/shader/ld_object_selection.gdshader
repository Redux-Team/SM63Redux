shader_type canvas_item;
uniform int state: hint_range(0, 2) = 0;
uniform int palette_index: hint_range(0, 16) = 0;
uniform sampler2D palette_texture: filter_nearest, repeat_disable;
uniform vec4 pre_modulate: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 post_modulate: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width: hint_range(0.0, 10.0) = 1.0;
uniform vec4 outline_color: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 fill_color: source_color = vec4(1.0, 1.0, 1.0, 0.25);
uniform vec4 hover_outline_color: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 hover_fill_color: source_color = vec4(1.0, 1.0, 1.0, 0.1);
uniform float pulse_speed: hint_range(0.0, 5.0) = 0.5;
uniform float pulse_min: hint_range(0.0, 1.0) = 0.3;
uniform float pulse_max: hint_range(0.0, 1.0) = 1.0;
uniform bool outline_ignore_holes = true;
uniform bool outline_enabled = true;

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

bool is_enclosed_hole(sampler2D tex, vec2 uv, vec2 texel) {
	float left  = texture(tex, uv + vec2(-texel.x, 0.0)).a;
	float right = texture(tex, uv + vec2( texel.x, 0.0)).a;
	float up    = texture(tex, uv + vec2(0.0,  texel.y)).a;
	float down  = texture(tex, uv + vec2(0.0, -texel.y)).a;
	return left > 0.1 && right > 0.1 && up > 0.1 && down > 0.1;
}

float get_neighbor_max(sampler2D tex, vec2 uv, vec2 texel) {
	float neighbor_max = 0.0;
	for (float x = -1.0; x <= 1.0; x += 1.0) {
		for (float y = -1.0; y <= 1.0; y += 1.0) {
			if (x == 0.0 && y == 0.0) {
				continue;
			}
			neighbor_max = max(neighbor_max, texture(tex, uv + vec2(x, y) * texel).a);
		}
	}
	return neighbor_max;
}

float get_pulse() {
	return pulse_min + (pulse_max - pulse_min) * (sin(TIME * pulse_speed * 5.0) * 0.5 + 0.5);
}

vec4 apply_hover(vec4 tex_color, bool is_outline, bool is_inside) {
	if (is_outline) {
		return hover_outline_color;
	} else if (is_inside) {
		return vec4(mix(tex_color.rgb, hover_fill_color.rgb, hover_fill_color.a), tex_color.a);
	}
	return tex_color;
}

vec4 apply_selected(vec4 tex_color, bool is_outline, bool is_inside) {
	float pulse = get_pulse();
	if (is_outline) {
		return vec4(outline_color.rgb, outline_color.a * pulse);
	} else if (is_inside) {
		vec4 fill = vec4(fill_color.rgb, fill_color.a * pulse);
		return vec4(mix(tex_color.rgb, fill.rgb, fill.a), tex_color.a);
	}
	return tex_color;
}

vec4 apply_selection(sampler2D tex, vec4 tex_color, vec2 uv) {
	if (!outline_enabled) {
		return tex_color;
	}
	vec2 texel = outline_width / vec2(textureSize(tex, 0));
	float neighbor_max = get_neighbor_max(tex, uv, texel);
	bool candidate_for_outline = tex_color.a < 0.1 && neighbor_max > 0.1;
	bool is_outline = candidate_for_outline && !(outline_ignore_holes && is_enclosed_hole(tex, uv, texel));
	bool is_inside = tex_color.a > 0.1;
	if (state == 1) {
		return apply_hover(tex_color, is_outline, is_inside);
	}
	return apply_selected(tex_color, is_outline, is_inside);
}

void fragment() {
	vec2 pal_size = vec2(textureSize(palette_texture, 0));
	vec4 tex = texture(TEXTURE, UV);
	vec4 pre = vec4(tex.rgb * pre_modulate.rgb, tex.a * pre_modulate.a);
	vec4 tex_swapped = vec4(swap_palette(palette_texture, pre.rgb, pal_size), pre.a);
	vec4 result;
	if (state != 0) {
		result = apply_selection(TEXTURE, tex_swapped, UV);
	} else {
		result = tex_swapped;
	}
	COLOR = vec4(result.rgb * post_modulate.rgb, result.a * post_modulate.a);
}