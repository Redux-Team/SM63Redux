shader_type canvas_item;

uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	COLOR = vec4(fade_color.rgb, fade_color.a * fade);
}
