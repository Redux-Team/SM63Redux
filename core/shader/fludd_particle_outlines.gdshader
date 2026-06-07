shader_type canvas_item;
render_mode unshaded;


uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap;
uniform vec4 fill_color: source_color = vec4(0.54, 0.70, 0.83, 0.63);
uniform vec4 outline_color: source_color = vec4(0.47, 0.59, 0.81, 0.63);
uniform float outline_width: hint_range(0.0, 20.0) = 4.0;
uniform float outline_softness: hint_range(0.0, 1.0) = 0.5;


void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * outline_width;
	float a = texture(SCREEN_TEXTURE, SCREEN_UV).a;
	
	if (a < 0.01) {
		float neighbor = 0.0;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(px.x, 0.0)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(px.x, 0.0)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, px.y)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(0.0, px.y)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(px.x, px.y)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(px.x, px.y)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(px.x, -px.y)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-px.x, px.y)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(px.x * 2.0, 0.0)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(px.x * 2.0, 0.0)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, px.y * 2.0)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(0.0, px.y * 2.0)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(px.x * 2.0, px.y * 2.0)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(px.x * 2.0, px.y * 2.0)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(px.x * 2.0, -px.y * 2.0)).a;
		neighbor += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-px.x * 2.0, px.y * 2.0)).a;
		float outline_a = smoothstep(0.0, 16.0 * outline_softness, neighbor);
		COLOR = vec4(outline_color.rgb, outline_color.a * outline_a);
	} else {
		COLOR = vec4(fill_color.rgb, fill_color.a * a);
	}
}