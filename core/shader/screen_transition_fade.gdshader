shader_type canvas_item;

// Simple fade: the rect's color faded in/out by `fade` (0 = clear, 1 = fully covered).
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	COLOR = vec4(fade_color.rgb, fade_color.a * fade);
}
