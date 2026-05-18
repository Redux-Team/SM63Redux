shader_type canvas_item;

uniform vec4 water_color : source_color = vec4(0.0, 0.3, 0.6, 1.0);
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D water_deform : repeat_enable, filter_nearest;
uniform float warp_strength : hint_range(0.0, 0.05) = 0.003;
uniform float wave_speed : hint_range(0.0, 5.0) = 0.06;
uniform float deform_scale : hint_range(0.001, 0.1) = 0.003;


void fragment() {
	vec2 world_uv = VERTEX * deform_scale;

	vec2 rg = texture(water_deform, world_uv + vec2(TIME * wave_speed, 0.0)).rg;
	vec2 offset = (rg - 0.5) * 2.0 * warp_strength;

	vec4 pixel = texture(screen_tex, SCREEN_UV + offset);

	COLOR = mix(pixel, water_color, water_color.a);
	COLOR.a = 1.0;
}