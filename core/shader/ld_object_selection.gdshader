shader_type canvas_item;


uniform int state: hint_range(0, 2) = 0;
uniform vec4 custom_modulate: source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float outline_width: hint_range(0.0, 10.0) = 1.0;
uniform vec4 outline_color: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 fill_color: source_color = vec4(1.0, 1.0, 1.0, 0.25);
uniform vec4 hover_outline_color: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 hover_fill_color: source_color = vec4(1.0, 1.0, 1.0, 0.1);
uniform float pulse_speed: hint_range(0.0, 5.0) = 0.5;
uniform float pulse_min: hint_range(0.0, 1.0) = 0.3;
uniform float pulse_max: hint_range(0.0, 1.0) = 1.0;


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
	return pulse_min + (pulse_max - pulse_min) * (sin(TIME * pulse_speed * TAU) * 0.5 + 0.5);
}


vec4 apply_hover(vec4 tex_color, bool is_outline, bool is_inside) {
	if (is_outline) {
		return hover_outline_color;
	} else if (is_inside) {
		return vec4(mix(tex_color.rgb, hover_fill_color.rgb, hover_fill_color.a), tex_color.a);
	}
	return vec4(0.0);
}


vec4 apply_selected(vec4 tex_color, bool is_outline, bool is_inside) {
	float pulse = get_pulse();
	if (is_outline) {
		return vec4(outline_color.rgb, outline_color.a * pulse);
	} else if (is_inside) {
		vec4 fill = vec4(fill_color.rgb, fill_color.a * pulse);
		return vec4(mix(tex_color.rgb, fill.rgb, fill.a), tex_color.a);
	}
	return vec4(0.0);
}


vec4 apply_selection(sampler2D tex, vec4 tex_color, vec2 uv) {
	vec2 texel = outline_width / vec2(textureSize(tex, 0));
	float neighbor_max = get_neighbor_max(tex, uv, texel);
	bool is_outline = tex_color.a < 0.1 && neighbor_max > 0.1;
	bool is_inside = tex_color.a > 0.1;
	
	if (state == 1) {
		return apply_hover(tex_color, is_outline, is_inside);
	}
	return apply_selected(tex_color, is_outline, is_inside);
}


void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 result = state != 0 ? apply_selection(TEXTURE, tex, UV) : tex;
	COLOR = vec4(result.rgb * custom_modulate.rgb, result.a * custom_modulate.a);
}