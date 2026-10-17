extends RefCounted
const OFFSETS: Dictionary = {
	"climb_down": [
		Vector2(19.0, 19.0), 
		Vector2(18.0, 19.0), 
		Vector2(19.0, 19.0), 
		Vector2(19.0, 19.0)
	], 
	"climb_up": [
		Vector2(19.0, 19.0), 
		Vector2(18.0, 18.5), 
		Vector2(19.0, 19.0), 
		Vector2(19.0, 19.0)
	], 
	"fall_front": [
		Vector2(19.0, 19.0), 
		Vector2(19.0, 19.0), 
		Vector2(19.0, 19.0), 
		Vector2(19.0, 19.0)
	], 
	"fall_left": [
		Vector2(20.0, 20.0), 
		Vector2(20.0, 20.0), 
		Vector2(20.0, 20.0), 
		Vector2(19.0, 20.0)
	], 
	"fall_right": [
		Vector2(18.0, 20.0), 
		Vector2(18.0, 20.0), 
		Vector2(18.0, 20.0), 
		Vector2(19.0, 20.0)
	], 
	"fly_up": [
		Vector2(19.0, 21.0), 
		Vector2(19.0, 20.0), 
		Vector2(19.0, 21.0), 
		Vector2(19.0, 20.0)
	], 
	"hanging_left": [
		Vector2(20.0, 20.0)
	], 
	"hanging_right": [
		Vector2(18.0, 20.0)
	], 
	"idle": [
		Vector2(19.0, 20.0), 
		Vector2(19.0, 21.0), 
		Vector2(19.0, 21.0), 
		Vector2(19.0, 21.0), 
		Vector2(19.0, 21.0), 
		Vector2(19.0, 21.0), 
		Vector2(18.5, 21.0), 
		Vector2(19.0, 20.0)
	], 
	"jump_left": [
		Vector2(18.0, 23.0), 
		Vector2(18.0, 22.0), 
		Vector2(19.0, 22.0), 
		Vector2(19.0, 22.0), 
		Vector2(19.0, 22.0)
	], 
	"jump_right": [
		Vector2(19.0, 23.0), 
		Vector2(19.0, 21.0), 
		Vector2(18.0, 22.0), 
		Vector2(18.0, 22.0), 
		Vector2(18.0, 22.0)
	], 
	"land_front": [
		Vector2(19.0, 20.0), 
		Vector2(18.0, 21.0), 
		Vector2(18.0, 22.0), 
		Vector2(18.0, 21.0), 
		Vector2(19.0, 21.0), 
		Vector2(19.0, 21.0)
	], 
	"land_left": [
		Vector2(19.0, 18.0), 
		Vector2(18.0, 19.0), 
		Vector2(20.0, 21.0), 
		Vector2(20.0, 23.0), 
		Vector2(19.0, 23.0), 
		Vector2(19.0, 22.0)
	], 
	"land_right": [
		Vector2(18.0, 18.0), 
		Vector2(19.0, 19.0), 
		Vector2(17.0, 21.0), 
		Vector2(17.0, 23.0), 
		Vector2(18.0, 23.0), 
		Vector2(18.0, 22.0)
	], 
	"landing_from_roll_left": [
		Vector2(19.0, 20.0), 
		Vector2(19.0, 19.5), 
		Vector2(18.0, 20.0), 
		Vector2(20.0, 20.0), 
		Vector2(20.0, 21.0), 
		Vector2(20.0, 23.0), 
		Vector2(19.0, 25.0), 
		Vector2(19.0, 25.0), 
		Vector2(19.0, 24.0)
	], 
	"landing_from_roll_right": [
		Vector2(18.0, 20.0), 
		Vector2(18.0, 19.5), 
		Vector2(19.0, 20.0), 
		Vector2(17.0, 20.0), 
		Vector2(17.0, 21.0), 
		Vector2(17.0, 23.0), 
		Vector2(18.0, 25.0), 
		Vector2(18.0, 25.0), 
		Vector2(18.0, 24.0)
	], 
	"roll_left": [
		Vector2(20.0, 18.0), 
		Vector2(18.0, 19.0), 
		Vector2(19.0, 19.0), 
		Vector2(18.0, 19.0)
	], 
	"roll_right": [
		Vector2(18.0, 18.0), 
		Vector2(19.0, 18.0), 
		Vector2(18.0, 19.0), 
		Vector2(19.0, 19.0)
	], 
	"run_left": [
		Vector2(19.0, 20.0), 
		Vector2(19.0, 20.0), 
		Vector2(19.0, 20.0), 
		Vector2(18.0, 22.0), 
		Vector2(18.0, 20.0), 
		Vector2(19.0, 20.0), 
		Vector2(19.0, 19.0), 
		Vector2(18.5, 21.0)
	], 
	"run_right": [
		Vector2(18.0, 20.0), 
		Vector2(18.0, 20.0), 
		Vector2(18.0, 20.0), 
		Vector2(19.0, 22.0), 
		Vector2(19.0, 20.0), 
		Vector2(18.0, 20.0), 
		Vector2(18.0, 19.0), 
		Vector2(18.5, 21.0)
	], 
	"shoot_hanging_left": [
		Vector2(20.0, 20.0), 
		Vector2(19.0, 20.0), 
		Vector2(20.0, 20.5), 
		Vector2(19.0, 21.0), 
		Vector2(19.0, 20.0)
	], 
	"shoot_hanging_right": [
		Vector2(18.0, 20.0), 
		Vector2(19.0, 20.0), 
		Vector2(18.0, 20.5), 
		Vector2(19.0, 21.0), 
		Vector2(19.0, 20.0)
	], 
	"side_left": [
		Vector2(17.0, 20.0)
	], 
	"side_right": [
		Vector2(21.0, 20.0)
	], 
	"slide_left": [
		Vector2(18.0, 21.0), 
		Vector2(18.0, 20.0), 
		Vector2(17.0, 20.5), 
		Vector2(17.0, 20.0)
	], 
	"slide_right": [
		Vector2(19.0, 21.0), 
		Vector2(19.0, 20.0), 
		Vector2(20.0, 20.5), 
		Vector2(20.0, 20.0)
	], 
	"throw_kunai_left": [
		Vector2(19.0, 20.0), 
		Vector2(19.0, 21.0), 
		Vector2(19.0, 21.0), 
		Vector2(17.0, 21.0), 
		Vector2(18.0, 21.0), 
		Vector2(16.0, 22.0)
	], 
	"throw_kunai_right": [
		Vector2(18.0, 20.0), 
		Vector2(18.0, 21.0), 
		Vector2(18.0, 21.0), 
		Vector2(20.0, 21.0), 
		Vector2(19.0, 21.0), 
		Vector2(21.0, 22.0)
	], 
	"throw_shuriken_left": [
		Vector2(17.0, 20.0), 
		Vector2(18.0, 21.0), 
		Vector2(19.0, 23.0), 
		Vector2(18.0, 22.0), 
		Vector2(19.0, 22.0)
	], 
	"throw_shuriken_right": [
		Vector2(21.0, 20.0), 
		Vector2(20.0, 21.0), 
		Vector2(19.0, 23.0), 
		Vector2(20.0, 22.0), 
		Vector2(19.0, 22.0)
	], 
	"default": [
		Vector2(24.0, 25.0), 
		Vector2(24.0, 25.0), 
		Vector2(24.0, 25.0), 
		Vector2(24.0, 26.0), 
		Vector2(24.0, 26.0), 
		Vector2(24.0, 26.0), 
		Vector2(24.0, 26.0), 
		Vector2(24.0, 25.0), 
	], 
	"face_left": [
		Vector2(23.0, 25.0), 
	], 
	"face_right": [
		Vector2(25.0, 25.0), 
	], 
	"jump_roll_left": [
		Vector2(23.0, 27.0), 
		Vector2(23.0, 30.0), 
		Vector2(23.0, 22.0), 
		Vector2(23.0, 25.0), 
		Vector2(22.0, 29.0), 
		Vector2(24.0, 32.0), 
		Vector2(29.0, 30.0), 
		Vector2(24.0, 26.0), 
		Vector2(20.0, 30.0), 
		Vector2(22.0, 26.0), 
		Vector2(24.0, 26.0), 
		Vector2(29.0, 25.0), 
		Vector2(27.0, 24.0), 
		Vector2(25.0, 25.0), 
	], 
	"jump_roll_right": [
		Vector2(26.0, 27.0), 
		Vector2(26.0, 29.0), 
		Vector2(32.0, 23.0), 
		Vector2(28.0, 25.0), 
		Vector2(29.0, 29.0), 
		Vector2(26.0, 32.0), 
		Vector2(22.0, 30.0), 
		Vector2(24.0, 26.0), 
		Vector2(29.0, 30.0), 
		Vector2(24.0, 26.0), 
		Vector2(25.0, 26.0), 
		Vector2(26.0, 25.0), 
		Vector2(25.0, 24.0), 
		Vector2(26.0, 25.0), 
	], 
	"ladder_climb": [
		Vector2(24.0, 25.0), 
		Vector2(24.0, 25.0), 
		Vector2(24.0, 25.0), 
		Vector2(24.0, 25.0), 
	], 
	"ladder_start_left": [
		Vector2(23.0, 25.0), 
		Vector2(23.0, 25.0), 
	], 
	"ladder_start_right": [
		Vector2(25.0, 25.0), 
		Vector2(27.0, 25.0), 
	], 
	"rope_shoot_left": [
		Vector2(24.0, 27.0), 
		Vector2(23.0, 22.0), 
		Vector2(23.0, 21.0), 
		Vector2(23.0, 23.0), 
		Vector2(23.0, 27.0), 
		Vector2(23.0, 25.0), 
		Vector2(23.0, 24.0), 
	], 
	"rope_shoot_right": [
		Vector2(24.0, 27.0), 
		Vector2(24.5, 24.0), 
		Vector2(25.0, 21.0), 
		Vector2(25.0, 23.0), 
		Vector2(25.0, 27.0), 
		Vector2(25.0, 25.0), 
		Vector2(25.0, 24.0), 
	], 
	"rope_swing_left": [
		Vector2(23.0, 24.0), 
	], 
	"rope_swing_right": [
		Vector2(25.0, 24.0), 
	], 
	"run_hard_stop_left": [
		Vector2(23.0, 26.0), 
		Vector2(23.0, 27.0), 
	], 
	"run_hard_stop_right": [
		Vector2(25.0, 26.0), 
		Vector2(25.0, 27.0), 
	], 
	"run_stop_left": [
		Vector2(23.0, 27.0), 
		Vector2(25.0, 27.0), 
		Vector2(28.0, 25.0), 
		Vector2(27.0, 25.0), 
	], 
	"run_stop_right": [
		Vector2(23.0, 27.0), 
		Vector2(21.0, 27.0), 
		Vector2(18.0, 25.0), 
		Vector2(19.0, 25.0), 
	], 
}
