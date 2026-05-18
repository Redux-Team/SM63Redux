shader_type canvas_item;

uniform float flow_speed = 1.2;
uniform float flow_amplitude = 3.0;
uniform float flow_frequency = 2.5;

uniform vec2 ripple_origin = vec2(0.0, 0.0);
uniform float ripple_strength = 0.0;
uniform float ripple_frequency = 8.0;
uniform float ripple_decay = 3.0;
uniform float ripple_speed = 6.0;
uniform float ripple_time = 0.0;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);


void vertex() {
	float world_x = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).x;
	
	float flow = sin(world_x * flow_frequency + TIME * flow_speed) * flow_amplitude;
	
	float dist = abs(world_x - ripple_origin.x);
	float envelope = exp(-dist * ripple_decay * 0.01) * exp(-ripple_time * 1.5);
	float ripple = sin(dist * ripple_frequency - ripple_time * ripple_speed) * envelope * ripple_strength;
	
	VERTEX.y += flow + ripple;
}


void fragment() {
	COLOR = line_color * COLOR;
}