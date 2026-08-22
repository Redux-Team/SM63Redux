shader_type canvas_item;

uniform sampler2D grid_bg_texture : repeat_enable, filter_nearest;
uniform sampler2D grid_origin_texture : repeat_enable, filter_nearest;
uniform vec4 grid_bg_modulate : source_color = vec4(1.0);
uniform vec4 grid_origin_modulate : source_color = vec4(1.0);

uniform vec2 camera_position = vec2(0.0);
uniform vec2 camera_zoom = vec2(1.0);
uniform vec2 screen_size = vec2(640.0, 360.0);
// Where the active layer's own coordinates sit in the world, and how big they are. Reading the
// layer's live transform is what lets the grid ride along with a parallaxing layer and stretch
// with a scaled one, instead of drawing a fixed grid the layer's contents slide across.
uniform vec2 grid_offset = vec2(0.0);
uniform vec2 grid_scale = vec2(1.0);
uniform float grid_fade_threshold : hint_range(0.0, 4.0) = 2.0;

void fragment() {
	vec2 tex_size = vec2(textureSize(grid_bg_texture, 0));

	vec2 world_pos = (UV * screen_size) / camera_zoom + camera_position - (screen_size * 0.5) / camera_zoom;
	vec2 layer_pos = (world_pos - grid_offset) / grid_scale;
	vec2 offset_pos = layer_pos + tex_size;
	vec2 tiled_uv = offset_pos / tex_size;

	vec2 cell = floor(offset_pos / tex_size);
	bool near_origin = (cell == vec2(0.0));

	// A scaled-down layer draws a scaled-down grid, so it should thin out at the zoom its own
	// cells become too small to read at, not the one the world grid would.
	float bg_alpha = smoothstep(0.0, grid_fade_threshold, camera_zoom.x * grid_scale.x);
	vec4 bg = texture(grid_bg_texture, tiled_uv) * grid_bg_modulate * vec4(1.0, 1.0, 1.0, bg_alpha);
	vec4 origin = texture(grid_origin_texture, tiled_uv) * grid_origin_modulate;
	
	COLOR = mix(bg, origin, float(near_origin) * origin.a);
}