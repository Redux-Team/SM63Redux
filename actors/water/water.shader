shader_type canvas_item;

uniform vec2 object_pos = vec2(0, 0);
uniform float wave_speed = 0.1f; //how many waves per second
uniform float wave_length = 500f; //waves per horizontal line
uniform float wave_height = 5f; //waves per vertical line
uniform vec3 reflectancy = vec3(0.7f, 0f, 0.25f); // REFLECTANCY | START | END
uniform vec3 transparency = vec3(0.8f, 0.5f, 1f); // TRANSPARENCY | START | END
uniform bool enable_animation = true;
uniform vec4 water_color : hint_color = vec4(0, 0.7, 1, 0.85);

const float PI = 3.141592653589793238462643383279502884197;
const float PI2 = PI * 2f;

void fragment() {
	vec2 pos = vec2(SCREEN_UV.x, 2f * object_pos.y - SCREEN_UV.y); //get the position to the top pixel
	
	//get the wave effect going
	float t = mod(TIME, 1f / wave_speed) * PI2 * wave_speed;
	pos.x += float(enable_animation) * (sin(t + UV.y * PI2 * wave_height) / wave_length);
	
	vec4 reflect_color = texture(SCREEN_TEXTURE, pos);
	float real_refl = clamp(1f / (reflectancy.y - reflectancy.z) * (UV.y - reflectancy.z), 0, 1) * reflectancy.x;
	vec4 wat_col = reflect_color * real_refl + water_color * (1f - real_refl); //merge the reflection with water color
	float real_trans = 1f - clamp(1f / (transparency.y - transparency.z) * (-UV.y + transparency.y), 0, 1) * transparency.x;
	wat_col.a *= real_trans;
	//wat_col.a *= min(-transparency_size * UV.y + transparency_size, 1) * transparency + (1f - transparency); //set alpha
	COLOR = wat_col;
}
