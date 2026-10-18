uniform float outline_width : hint_range(0.5, 4.0, 0.5) = 2.0;
uniform float fill_top : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float fill_bottom : hint_range(0.0, 1.0, 0.001) = 1.0;
group_uniforms metal;
uniform float metal_progress : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform sampler2D metal_ramp : source_color, filter_linear, repeat_disable;
uniform vec4 metal_tint : source_color = vec4(0.85, 0.9, 1.0, 1.0);
uniform vec4 metal_outline : source_color = vec4(0.12, 0.13, 0.17, 1.0);
uniform float metal_contrast : hint_range(0.5, 3.0, 0.05) = 1.3;
uniform float metal_sheen : hint_range(0.0, 1.0, 0.05) = 0.35;
uniform float metal_sheen_width : hint_range(1.0, 32.0, 1.0) = 4.0;
uniform float metal_sheen_interval = 720.0;
uniform float metal_sheen_speed = 120.0;
group_uniforms ghost;
uniform float ghost_progress : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform vec4 ghost_tint : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform vec4 ghost_outline : source_color = vec4(0.88, 0.96, 1.0, 1.0);
uniform float ghost_tint_strength : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float ghost_alpha : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float ghost_stripe_alpha : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float ghost_stripe_spacing : hint_range(2.0, 16.0, 1.0) = 3.0;
uniform float ghost_stripe_speed = 10.0;
group_uniforms;


float hud_luminance(vec3 col) {
	return dot(col, vec3(0.299, 0.587, 0.114));
}


float hud_radial_mask(vec2 offset, float progress) {
	float angle = mod(atan(-offset.x, -offset.y) + TAU, TAU);
	return step(angle, progress * TAU) * step(0.0001, progress);
}


float hud_ray(vec2 offset, float angle) {
	vec2 direction = vec2(-sin(angle), -cos(angle));
	float cross_distance = abs(offset.x * direction.y - offset.y * direction.x);
	return step(cross_distance, outline_width * 0.5) * step(0.0, dot(offset, direction));
}


float hud_radial_edge(vec2 offset, float progress) {
	if (progress <= 0.0001 || progress >= 0.9999) {
		return 0.0;
	}
	
	return max(hud_ray(offset, 0.0), hud_ray(offset, progress * TAU));
}


float hud_vertical_depth(vec2 pixel, float height, float progress) {
	float bottom = fill_bottom * height;
	return pixel.y + 0.5 - (bottom - progress * (bottom - fill_top * height));
}


float hud_vertical_mask(vec2 pixel, float height, float progress) {
	return step(0.0, hud_vertical_depth(pixel, height, progress)) * step(0.0001, progress);
}


float hud_vertical_edge(vec2 pixel, float height, float progress) {
	if (progress <= 0.0001 || progress >= 0.9999) {
		return 0.0;
	}
	
	float depth = hud_vertical_depth(pixel, height, progress);
	return step(0.0, depth) * (1.0 - step(outline_width, depth));
}


vec4 hud_apply_caps(vec4 col, vec2 pixel, vec2 center, vec2 size) {
	vec2 offset = pixel + 0.5 - center;
	vec4 result = col;
	
	float lum = clamp((hud_luminance(col.rgb) - 0.5) * metal_contrast + 0.5, 0.0, 1.0);
	vec3 metal = texture(metal_ramp, vec2(lum, 0.5)).rgb * metal_tint.rgb;
	float band = pixel.x + pixel.y * 0.6 - TIME * metal_sheen_speed;
	float sheen = 1.0 - smoothstep(0.0, metal_sheen_width, abs(mod(band, metal_sheen_interval) - metal_sheen_interval * 0.5));
	metal = min(metal + sheen * metal_sheen, vec3(1.0));
	result.rgb = mix(result.rgb, metal, hud_vertical_mask(pixel, size.y, metal_progress));
	
	float stripe = step(ghost_stripe_spacing - 1.0, mod(pixel.y + floor(TIME * ghost_stripe_speed), ghost_stripe_spacing));
	vec3 ghost = mix(result.rgb, ghost_tint.rgb * (0.5 + hud_luminance(result.rgb)), ghost_tint_strength);
	ghost = mix(ghost, vec3(1.0), stripe * 0.35);
	vec4 ghosted = vec4(ghost, result.a * (ghost_alpha + stripe * ghost_stripe_alpha));
	result = mix(result, ghosted, hud_radial_mask(offset, ghost_progress));
	
	result.rgb = mix(result.rgb, metal_outline.rgb, hud_vertical_edge(pixel, size.y, metal_progress) * metal_outline.a);
	result = mix(result, vec4(ghost_outline.rgb, col.a), hud_radial_edge(offset, ghost_progress) * ghost_outline.a);
	return result;
}
