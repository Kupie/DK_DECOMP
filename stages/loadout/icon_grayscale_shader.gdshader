shader_type canvas_item;

varying flat vec4 modulate;

void vertex() {
    modulate = COLOR;
}

void fragment() {
	vec4 input = texture(TEXTURE, UV);
	COLOR = vec4(vec3(0.299 * input.r + 0.587 * input.g + 0.114 * input.b), input.a) * modulate;
}