shader_type canvas_item;
//#TODO: CONVERSION, double check
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	// https://en.wikipedia.org/wiki/Blend_modes
	
	vec4 fg = texture(TEXTURE, UV);
	vec4 bg = texture(SCREEN_TEXTURE, SCREEN_UV);

	vec4 value = step(bg, vec4(0.5));
	vec4 left = vec4(2.0) * bg * fg * value;
	vec4 right = (vec4(1.0) - vec4(2.0) * (vec4(1.0) - bg) * (vec4(1.0) - fg)) * (1.0-value);
	COLOR = left + right;
}