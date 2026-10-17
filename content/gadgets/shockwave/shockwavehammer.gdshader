shader_type canvas_item;

uniform float flash_rate = 0.f;
uniform float flash_magnitude = 0.f;
uniform sampler2D palette;
const float start_r = 0.5 / float(32);
const float start_b = 0.5 / float(12);

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec4 input = texture(palette, vec2(start_r + t.r, start_b+t.b));
	float flash_freq = TIME*flash_rate*6.2831853;
	float flash_val = flash_magnitude * 0.5*(sin(flash_freq)+0.8);
	input.rgb = input.rgb + vec3(1.0,1.0,1.0) * flash_val;
	
	input.a = t.a;
	COLOR = input;
}