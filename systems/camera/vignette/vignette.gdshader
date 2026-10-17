shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D light_cutouts : source_color, filter_nearest, repeat_disable;
uniform vec2 zoom = vec2(1.f);
uniform vec3 color_conversion = vec3(0.7, 0.7, 0.7);
uniform float vignette_alpha = 1.f;
uniform vec2 light_cutout_offset = vec2(0.0);
uniform vec2 light_cutout_scale = vec2(1.0);
uniform float aspect_ratio = 1.777;
uniform int nmb_of_targets = 1;
// vec4 array: vec4(offset_x, offset_y, strength, unused_value)
// (only float and vec4 arrays supported on consoles in Godot 4.3)
uniform vec4 target_center_offsets_and_strengths[8];
uniform float brightness_bias = 3.0f;
uniform int brightness_bands = 3;

vec3 target_vignette(vec2 target_offset, vec2 suv, vec2 screen_pixel_size, float zoom_factor, float strength) {
	
	// Distance from center
	vec2 center_point = vec2(0.5) + target_offset;
	float dist = distance(suv * vec2(aspect_ratio, 1.0), center_point * vec2(aspect_ratio, 1.0)) * zoom_factor;

	// Banding
	int bands = 3;
	float size = strength * 0.1;
	float t = TIME * 5.f;
	float magnitude = 0.003;
	float alpha = 0.5f;
	float size_offset = sin(t) * magnitude;
	vec3 mask = vec3(step(dist, size + size_offset));
	for(int i = 0; i < bands; i++) {
		size_offset = (pow(float(i)/10.f, 0.8f)) + sin(t + 2.f * float(i)) * magnitude;
		mask += vec3(step(dist, size + size_offset)) * alpha;
	}
	mask += vec3(1.f) * alpha * brightness_bias;
	mask /= (1.f + float(bands + brightness_bands) * alpha);
	return mask;
}

void fragment() {
	vec2 screen_pixel_size = SCREEN_PIXEL_SIZE;
	float zoom_factor = zoom.x * 4.0f;

	// Get screen color
	vec4 screen_tex = texture(SCREEN_TEXTURE, SCREEN_UV);

	vec2 suv = SCREEN_UV / (screen_pixel_size / zoom);
	suv = floor(suv);
	suv *= (screen_pixel_size / zoom);

	vec3 mask_max = vec3(0.0f);
	for (int target_idx = 0; target_idx < nmb_of_targets; target_idx++) {
		vec2 target_offset = target_center_offsets_and_strengths[target_idx].xy;
		float strength = target_center_offsets_and_strengths[target_idx].z;
		vec3 mask = target_vignette(target_offset, suv, screen_pixel_size, zoom_factor, strength);
		mask_max = max(mask_max, mask);
	}

	// Vignette
	screen_tex.rgb *= mask_max;
	float w = clamp(2.0f * (1.0f - mask_max.r), 0.0f, 1.0f);
	vec3 influence = mix(screen_tex.rgb, screen_tex.ggg * color_conversion, w);
	COLOR.rgb += influence;
	COLOR.a = clamp(vignette_alpha - step(0.05,texture(light_cutouts, (SCREEN_UV*light_cutout_scale)+light_cutout_offset).a), 0.0, 1.0);
}