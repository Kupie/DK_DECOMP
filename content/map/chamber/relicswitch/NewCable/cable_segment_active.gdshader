shader_type canvas_item;
render_mode blend_mix;

const float start_r = 0.5 / float(32);
const float start_b = 0.5 / float(12);

uniform sampler2D palette : source_color, filter_nearest;
uniform sampler2D gradient : source_color;
uniform sampler2D color : source_color, filter_nearest;
uniform sampler2D glow : source_color, filter_nearest, repeat_enable;
uniform float activation_power = 0.0;

varying flat vec4 MODULATE;
void vertex() {
    MODULATE = COLOR;
	vec2 direction = vec2(cos(MODULATE.r), sin(MODULATE.r));
	VERTEX += direction*sin(TIME*4.0+VERTEX.x*0.1)*2.0 * sin(UV.x * PI) * activation_power;
}

void fragment() {
	float fade_vertical = abs(1.0-sin(UV.y*PI))*0.5;
	float grad = texture(gradient, vec2(UV.x, 0.0)).r;
	float mod_r = MODULATE.g * 4.8;
	vec4 input = texture(color, vec2(mod_r * grad - fade_vertical, 0.0));
	vec4 output = texture(palette, vec2(start_r + input.r, start_b+input.b));
	COLOR = output;
	
	
	vec4 input_glow = texture(glow, vec2((((MODULATE.b/MODULATE.g) + UV.x) - TIME/MODULATE.g)*MODULATE.g, 0.0));
	vec4 output_glow = texture(palette, vec2(start_r + input.r, start_b+input.b));
	COLOR.rgb = mix(output.rgb, output.rgb+output_glow.rgb, input_glow.a*smoothstep(0.9, 0.3, MODULATE.a));
}