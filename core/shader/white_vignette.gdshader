shader_type canvas_item;

// White vignette: transparent in the center, fading to white toward the edges/corners.
uniform float inner : hint_range(0.0, 1.0) = 0.35;
uniform float outer : hint_range(0.0, 1.0) = 1.0;
uniform float strength : hint_range(0.0, 1.0) = 0.9;

void fragment() {
	// Normalize so a corner (distance ~0.707 from center) maps to 1.0.
	float d = distance(UV, vec2(0.5)) / 0.70710678;
	float a = smoothstep(inner, outer, d) * strength;
	COLOR = vec4(1.0, 1.0, 1.0, a);
}
