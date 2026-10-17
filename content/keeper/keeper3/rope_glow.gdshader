shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 10.0) = 4.0;  // MAX GLOW
uniform float pulse_speed : hint_range(0.0, 20.0) = 8.0;      // FAST PULSE
uniform float pulse_strength : hint_range(0.0, 5.0) = 2.5;    // DEEP OSCILLATION

void fragment() {
	// Generate pulse from TIME
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_strength;

	// Supercharged red glow
	vec3 glow_color = vec3(2.0, 0.0, 0.0); // Bright red beyond normal 1.0 RGB

	// Apply glowing pulse on top of existing color
	COLOR.rgb += glow_color * glow_intensity * pulse;
}