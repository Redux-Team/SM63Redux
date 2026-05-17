shader_type canvas_item;

uniform vec4 modulate_color : source_color = vec4(1.0);
uniform sampler2D health_texture : source_color, filter_nearest;
uniform int total_slices = 8;
uniform int filled_slices = 8;
uniform float start_angle_degrees = 0.0;
uniform vec4 divider_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);


void fragment() {
	vec2 tex_size = vec2(textureSize(health_texture, 0));
	vec2 pixel_uv = floor(UV * tex_size) / tex_size;
	vec2 centered = pixel_uv - vec2(0.5);
	float angle = atan(centered.x, -centered.y);
	
	float start_rad = start_angle_degrees * (PI / 180.0);
	angle = mod(angle - start_rad + TAU, TAU);
	
	float slice_angle = TAU / float(total_slices);
	float quantized = floor(angle / slice_angle);
	int slice_index = int(quantized);
	
	vec4 tex_color = texture(health_texture, UV);
	
	if (slice_index >= filled_slices) {
		tex_color.a = 0.0;
	}
	
	if (total_slices > 1) {
		float pixel_size = 1.0 / tex_size.x;
		float half_width = pixel_size * 1.0;
		float dist = length(centered);
		
		for (int i = 0; i < total_slices; i++) {
			float line_angle = start_rad + float(i) * slice_angle;
			vec2 line_dir = vec2(sin(line_angle), -cos(line_angle));
			float cross_dist = abs(centered.x * line_dir.y - centered.y * line_dir.x);
			float along = dot(centered, line_dir);
			
			if (cross_dist < half_width && along > 0.0 && dist < 0.5) {
				if (i + 1 < filled_slices + 2) {
					tex_color = mix(tex_color, divider_color, divider_color.a);
				}
			}
		}
	}
	
	COLOR = tex_color * modulate_color;
}