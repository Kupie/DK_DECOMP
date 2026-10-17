shader_type canvas_item;

uniform sampler2D palette : source_color;
// this was start_r (0.5 / float(32)) and start_b (0.5 / float(12))
const vec3 start = vec3(0.5 / 32.0, 0.0, 0.5 / 12.0);
varying flat vec4 modulate;

void vertex() {
    modulate = COLOR;
}

void fragment() {
	vec4 input = texture(TEXTURE, UV);
	vec4 output = texture(palette, vec2(start.r + input.r, start.b + input.b));
	output.a = COLOR.a;
	output.rgb = vec3(0.299 * output.r + 0.587 * output.g + 0.114 * output.b);
	COLOR = output * modulate;
}