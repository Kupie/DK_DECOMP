shader_type canvas_item;
//#TODO: CONVERSION, double check
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	// https://en.wikipedia.org/wiki/Blend_modes
	
	vec4 fg = texture(TEXTURE, UV);
	vec4 bg = texture(SCREEN_TEXTURE, SCREEN_UV);

	COLOR.rgb = bg.rgb / (vec3(1.0)-fg.rgb);
}