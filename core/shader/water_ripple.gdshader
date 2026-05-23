shader_type canvas_item;

uniform sampler2D wave_texture : repeat_enable, filter_nearest;
uniform float wave_speed : hint_range(0.0, 5.0) = 0.8;
uniform float wave_amplitude : hint_range(0.0, 64.0) = 6.0;
uniform float wave_frequency : hint_range(0.0, 10.0) = 2.0;
uniform float texture_scale : hint_range(0.1, 16.0) = 4.0;
uniform vec4 wave_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_length = 1.0;

uniform int splash_count = 0;
uniform vec2 splash_positions[8];
uniform float splash_ages[8];
uniform float splash_max_age : hint_range(0.1, 5.0) = 1.2;
uniform float splash_amplitude : hint_range(0.0, 128.0) = 18.0;
uniform float splash_radius : hint_range(1.0, 1024.0) = 120.0;

varying float v_is_outer;
varying float v_arc;
varying vec2 v_normal;


void vertex() {
	v_is_outer = UV.y < 0.5 ? 1.0 : 0.0;
	v_arc = UV.x;
	v_normal = vec2(COLOR.r * 2.0 - 1.0, COLOR.g * 2.0 - 1.0);
	float v_seg_t = COLOR.b;

	float disp = 0.0;

	if (v_is_outer > 0.5) {
		float u_norm = v_arc / max(outline_length, 1.0);
		disp += sin(u_norm * wave_frequency * TAU + TIME * wave_speed) * wave_amplitude;

		for (int i = 0; i < 8; i++) {
			if (i >= splash_count) {
				break;
			}
			float t = clamp(splash_ages[i] / splash_max_age, 0.0, 1.0);
			float decay = (1.0 - t) * (1.0 - t);
			float arc_dist = v_arc - splash_positions[i].x;
			float r = splash_radius * (0.3 + t * 0.7);
			float envelope = exp(-(arc_dist * arc_dist) / (2.0 * r * r));
			float ripple = sin((arc_dist / max(r, 0.001)) * TAU * 2.0 - t * TAU * 4.0);
			disp += splash_amplitude * decay * envelope * ripple;
		}

		float fade = sin(v_seg_t * PI);
		disp *= fade;
	}

	VERTEX += v_normal * disp;
}

void fragment() {
	vec2 tex_size = vec2(1.0) / TEXTURE_PIXEL_SIZE;
	vec2 tex_uv = vec2(v_arc / (tex_size.x * texture_scale), UV.y);
	vec4 tex = texture(wave_texture, tex_uv);
	COLOR = tex * wave_color;
}