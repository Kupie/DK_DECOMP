shader_type canvas_item;

uniform float blend_left = 0.0;
uniform float blend_right = 0.0;


void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE;
	COLOR.a = smoothstep(-0.0001, size.x*max(blend_left, 0.0), UV.x) * smoothstep(1.0001, 1.0-size.x*max(blend_right, 0.0), UV.x);
}