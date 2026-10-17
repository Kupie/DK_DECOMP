shader_type canvas_item;

uniform sampler2D texture_albedo;
uniform float repeat_factor = 1.0;
uniform float pulse_strength = 0.0;
uniform float flash_strength = 0.0;

// Colors to blend between
uniform vec4 pulse_color_1 : source_color = vec4(1.0, 1.0, 0.2, 1.0); // Yellow
uniform vec4 pulse_color_2 : source_color = vec4(0.2, 0.8, 1.0, 1.0); // Electric blue

void fragment() {
	vec2 uv = UV;
	uv.x *= repeat_factor;

	vec4 tex_color = texture(texture_albedo, uv);

	// Pulse color shifts over time
	float pulse_wave = sin(TIME * 8.0) * 0.5 + 0.5;
	vec4 pulse_color = mix(pulse_color_1, pulse_color_2, pulse_wave);

	// Blend pulse color and modulate brightness
	float brightness = mix(1.0, 2.5, pulse_strength);
	vec4 final_color = tex_color * pulse_color * brightness;

	// Flash override
	float flash = mix(1.0, 5.0, flash_strength);
	COLOR = final_color * flash;
}

//shader_type canvas_item;
//
//uniform sampler2D texture_albedo;
//uniform float repeat_factor = 1.0;
//
//void fragment() {
	//vec2 uv = UV;
	//uv.x *= repeat_factor;
	//COLOR = texture(texture_albedo, uv);
//}