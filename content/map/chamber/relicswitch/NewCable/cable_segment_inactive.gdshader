shader_type canvas_item;
render_mode blend_mix;

const float start_r = 0.5 / float(32);
const float start_b = 0.5 / float(12);

uniform sampler2D palette : source_color, filter_nearest;
uniform sampler2D gradient : source_color;
uniform sampler2D color : source_color, filter_nearest;
uniform sampler2D glow : source_color, filter_nearest, repeat_enable;

varying flat vec4 MODULATE;
void vertex() {
    MODULATE = COLOR;
}

void fragment() {
	float fade_vertical = abs(1.0-sin(UV.y*PI))*0.5;
	float grad = texture(gradient, vec2(UV.x, 0.0)).r;
	float mod_r = MODULATE.g * 4.8;
	vec4 input = texture(color, vec2(mod_r * grad - fade_vertical, 0.0));
	vec4 output = texture(palette, vec2(start_r + input.r, start_b+input.b));
	COLOR = output;
}