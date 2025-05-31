shader_type canvas_item;

uniform sampler2D texture_albedo : source_color;
uniform float scale : hint_range(0.0, 10.0) = 1.0;

void fragment() {
	vec2 texture_size = vec2(textureSize(texture_albedo, 0));
	
	float texture_aspect = texture_size.x / texture_size.y;
	float canvas_aspect = 1.0 / SCREEN_PIXEL_SIZE.x * SCREEN_PIXEL_SIZE.y;
	
	vec2 uv_scale;
	if (texture_aspect > canvas_aspect) {
		uv_scale = vec2(1.0, canvas_aspect / texture_aspect);
	} else {
		uv_scale = vec2(texture_aspect / canvas_aspect, 1.0);
	}
	
	vec2 scaled_uv = (UV - 0.5) / (uv_scale * scale) + 0.5;
	
	if (scaled_uv.x < 0.0 || scaled_uv.x > 1.0 || scaled_uv.y < 0.0 || scaled_uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		float mask = texture(texture_albedo, scaled_uv).a;
		if (mask > 0.1) {
			discard;
		}
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
}