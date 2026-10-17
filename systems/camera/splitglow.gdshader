shader_type canvas_item;
render_mode blend_mix;

uniform float blend_left = 0.0;
uniform float blend_right = 0.0;
uniform float blend_top = 0.0;
uniform float blend_bottom = 0.0;

uniform sampler2D palette;
uniform float i_r = 3.5;
const float i_b = 2.5 / float(12);

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE;
	COLOR.rgba = texture(palette, vec2(i_r, i_b));
	float alpha = smoothstep(-0.0001, size.x*max(blend_left, 0.0), UV.x) * smoothstep(1.0001, 1.0-size.x*max(blend_right, 0.0), UV.x);
	alpha *= smoothstep(-0.0001, size.y*max(blend_top, 0.0), UV.y) * smoothstep(1.0001, 1.0-size.y*max(blend_bottom, 0.0), UV.y);
	COLOR.a = 1.0 - pow(alpha, 0.3);
}