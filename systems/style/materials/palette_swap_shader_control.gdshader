shader_type canvas_item;

uniform sampler2D palette : source_color, filter_nearest;
const float start_r = 0.5 / 32.0;
const float start_b = 0.5 / 32.0;

void fragment() {
	vec4 input = COLOR;
	vec4 output = texture(palette, vec2(start_r + input.r, start_b+input.b));
	output.a = input.a;
	COLOR.rgba = output;
}