shader_type canvas_item;

uniform int state : hint_range(0, 2) = 0;
instance uniform int palette_index : hint_range(0, 16) = 0;
uniform sampler2D palette_texture : filter_nearest, repeat_disable;
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;
uniform vec4 selected_outline : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 selected_fill : source_color = vec4(1.0, 1.0, 1.0, 0.25);
uniform vec4 hover_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float hover_tint_min : hint_range(0.0, 1.0) = 0.06;
uniform float hover_tint_max : hint_range(0.0, 1.0) = 0.22;
uniform float hover_pulse_speed : hint_range(0.0, 5.0) = 0.6;
uniform float pulse_speed : hint_range(0.0, 5.0) = 0.5;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.3;
uniform float pulse_max : hint_range(0.0, 1.0) = 1.0;

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

vec3 swap_palette(vec3 rgb) {
	vec2 pal_size = vec2(textureSize(palette_texture, 0));
	if (palette_index <= 0 || float(palette_index) >= pal_size.y) {
		return rgb;
	}
	
	float base_row = 0.5 / pal_size.y;
	float target_row = (float(palette_index) + 0.5) / pal_size.y;
	float best_dist = 0.0001;
	vec3 result = rgb;
	for (int i = 0; i < int(pal_size.x); i++) {
		float u = (float(i) + 0.5) / pal_size.x;
		vec3 diff = rgb - texture(palette_texture, vec2(u, base_row)).rgb;
		float dist = dot(diff, diff);
		if (dist < best_dist) {
			best_dist = dist;
			result = texture(palette_texture, vec2(u, target_row)).rgb;
		}
	}
	return result;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 color = vec4(swap_palette(tex.rgb), tex.a) * vertex_color;
	if (state == 1) {
		if (tex.a > 0.1) {
			float wave = sin(TIME * hover_pulse_speed * TAU) * 0.5 + 0.5;
			color.rgb = mix(
				color.rgb,
				hover_tint.rgb,
				mix(hover_tint_min, hover_tint_max, wave)
			);
		}
	} else if (state == 2) {
		vec2 texel = outline_width / vec2(textureSize(TEXTURE, 0));
		bool inside = tex.a > 0.1;
		float around = 0.0;
		for (float x = -1.0; x <= 1.0; x += 1.0) {
			for (float y = -1.0; y <= 1.0; y += 1.0) {
				around = max(
					around,
					texture(TEXTURE, UV + vec2(x, y) * texel).a
				);
			}
		}
		bool enclosed = texture(TEXTURE, UV + vec2(-texel.x, 0.0)).a > 0.1
			&& texture(TEXTURE, UV + vec2(texel.x, 0.0)).a > 0.1
			&& texture(TEXTURE, UV + vec2(0.0, texel.y)).a > 0.1
			&& texture(TEXTURE, UV + vec2(0.0, -texel.y)).a > 0.1;
		bool outline = !inside && around > 0.1 && !enclosed;
		float pulse = (
			pulse_min
			+ (pulse_max - pulse_min) * (
				sin(TIME * pulse_speed * 5.0) * 0.5 + 0.5
			)
		);
		if (outline) {
			color = vec4(
				selected_outline.rgb,
				selected_outline.a * pulse * vertex_color.a
			);
		} else if (inside) {
			color.rgb = mix(
				color.rgb,
				selected_fill.rgb,
				selected_fill.a * pulse
			);
		}
	}
	COLOR = color;
}
