// NOTE: Shader automatically converted from Godot Engine 4.3.1.rc's CanvasItemMaterial.

shader_type canvas_item;
render_mode blend_mix;
uniform int particles_anim_h_frames;
uniform int particles_anim_v_frames;
uniform bool particles_anim_loop;

uniform sampler2D palette;
const float start_r = 0.5 / float(32);
const float start_b = 0.5 / float(12);

void vertex() {
	float h_frames = float(particles_anim_h_frames);
	float v_frames = float(particles_anim_v_frames);
	VERTEX.xy /= vec2(h_frames, v_frames);
	float particle_total_frames = float(particles_anim_h_frames * particles_anim_v_frames);
	float particle_frame = floor(INSTANCE_CUSTOM.z * float(particle_total_frames));
	if (!particles_anim_loop) {
		particle_frame = clamp(particle_frame, 0.0, particle_total_frames - 1.0);
	} else {
		particle_frame = mod(particle_frame, particle_total_frames);
	}	UV /= vec2(h_frames, v_frames);
	UV += vec2(mod(particle_frame, h_frames) / h_frames, floor((particle_frame + 0.5) / h_frames) / v_frames);
}

void fragment() {
	vec4 t = COLOR;
	vec2 uv = UV;
	uv.y += sin(uv.x + TIME * 50.0) * 0.04 + sin(uv.x * 3.3 + TIME * 80.0) * 0.02;
	vec4 input = texture(TEXTURE, uv);
	vec4 output = texture(palette, vec2(start_r + input.r, start_b+input.b));
	output.a = input.a * t.a;
	COLOR.rgba = output;
}