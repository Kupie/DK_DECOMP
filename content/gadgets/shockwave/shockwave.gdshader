shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D tex : repeat_enable, filter_nearest;

uniform float radius = 50;
uniform float floorHeight;
uniform float strength = 1.0;

float random (vec2 uv) {
    return fract(sin(dot(uv.xy,
        vec2(12.9898,78.233))) * 43758.5453123);
}

float random01(vec2 uv, float v){
	return clamp(ceil(random(uv) - v),0.0,1.0);
}

void fragment() {
	
	vec2 uv = UV;
	uv -= vec2(0.5,0.5);
	uv *= 2.0;
	float len = length(uv);
	if(len > 1.0)
	{
		discard;
	}
	
	//below floor
	if (-uv.y * radius < floorHeight){
		discard;
	}
		
	//distortion
	float offset =  len;
	//offset = 1.0 - 2.0* abs(offset) ;
	offset = pow(offset,8);
	vec2 suv = SCREEN_UV;
	suv += uv * -offset * SCREEN_PIXEL_SIZE * 100.0;
	vec4 distort = texture(SCREEN_TEXTURE, suv);
	COLOR.rgb = distort.rgb;
	
	//white lines
	vec2 uvw = floor(uv*radius*0.5);
	float val = random01(floor(normalize(uvw)*360.0), 0.93);
	float p = length(uvw*2.0)/radius;
	val *= p*p*p;
	val -= 0.5;
	val *= 2.0;
	val = clamp(val,0.0,1.0);
	COLOR.rgb += (val * p * 0.6);
	
	COLOR.a = strength;
}
