extends Object
class_name Keeper3GameplaySettings


const MOVE_SPEED: int = 5800
const LADDER_MOVE_SPEED: int = 4500
const GRAVITY: int = 400
const MAX_SPEED: int = 500
const AIR_ROLL_SPEED_THRESHOLD: float = 200.0
const ANIMATION_HORIZONTAL_SPEED_DEADZONE: float = 10.0
const MAX_FALL_SPEED: int = 200
const FRICTION_GROUND: float = 0.95
const AUTO_CARRYABLE_PICKUP_RADIUS: float = 10.0
const MANUAL_PICKUP_RADIUS: float = AUTO_CARRYABLE_PICKUP_RADIUS * 3.0
const CARRIER_PICKUP_RADIUS: float = 40.0
const DROP_CARRY_AIM_TOLERANCE_DEGREES: float = 30.0
const DROP_CARRY_PICKUP_BLOCK_DURATION: float = 0.5
const ROPE_GRAVITY: float = 400.0
const AIR_INPUT_DEADZONE: float = 0.1
const AIR_INPUT_ACCELERATION: float = 1000.0
const AIR_INPUT_BRAKE: float = 2400.0
const GROUND_INPUT_ACCELERATION: float = 600.0
const GROUND_INPUT_BRAKE: float = 3600.0
const GROUND_PASSIVE_BRAKE: float = 4000.0
const AIR_OPPOSITE_DECEL: float = 1500.0
const AIR_FALL_SPEED_UP_MODIFIER: float = 0.88
const AIR_FALL_SPEED_DOWN_MODIFIER: float = 1.6
const STEP_INTERVAL: float = 0.3
const CLIMB_STEP_INTERVAL: float = 0.2
const STEP_LADDER_INTERVAL: float = 0.2
const OFF_FLOOR_JUMP_GRACE: float = 0.2
const JUMP_PROFILES: = [
	{
		"impulse": 145.0, 
		"min_hold": 0.06, 
		"max_hold": 0.2, 
		"hold_gravity_scale": 0.45, 
		"release_gravity_scale": 1.0, 
		"fall_gravity_scale": 1.45, 
		"vfx_multiplier": 1.0, 
		"sfx_boost_db": 0.0, 
		"shake_strength": 0.0, 
		"shake_duration": 0.0, 
		"shake_frequency": 0.0, 
	}, 
	{
		"impulse": 155.0, 
		"min_hold": 0.06, 
		"max_hold": 0.2, 
		"hold_gravity_scale": 0.42, 
		"release_gravity_scale": 1.05, 
		"fall_gravity_scale": 1.5, 
		"vfx_multiplier": 1.35, 
		"sfx_boost_db": 2.0, 
		"shake_strength": 0.0, 
		"shake_duration": 0.0, 
		"shake_frequency": 0.0, 
	}, 
	{
		"impulse": 175.0, 
		"min_hold": 0.06, 
		"max_hold": 0.2, 
		"hold_gravity_scale": 0.38, 
		"release_gravity_scale": 1.1, 
		"fall_gravity_scale": 1.55, 
		"vfx_multiplier": 1.75, 
		"sfx_boost_db": 4.0, 
		"shake_strength": 28.0, 
		"shake_duration": 0.18, 
		"shake_frequency": 12.0, 
	}
]


const HORIZONTAL_CONTROL_FORCE: float = 5.0
const PROPULSION_DETACHED_CONTROL_FORCE: float = HORIZONTAL_CONTROL_FORCE / 3.0
const WALL_SLIDE_SPEED: float = 35.0
const WALL_SLIDE_SPEED_SLOW: float = 0.0
const WALL_SLIDE_SPEED_FAST: float = 95.0
const WALL_SLIDE_BLOCK_TIME: float = 0.1
const WALL_SLIDE_AUTO_WINDOW: float = 0.25
const WALL_SLIDE_STICK_FORCE: float = 80.0
const WALL_SLIDE_CORNER_CLIMB_DISTANCE: float = 9.0
const WALL_SLIDE_CORNER_CLIMB_SPEED: float = 80.0
const WALL_SLIDE_CORNER_CLIMB_DELAY: float = 0.1
const WALL_JUMP_LAUNCH_SPEED: float = 150.0
const WALL_JUMP_LAUNCH_ANGLE_DEGREES: float = 55.0
const WALL_JUMP_INPUT_LOCKOUT: float = 0.12
const PROP_ANCHOR_REACH_RADIUS: float = 8.0
const PROPEL_MOMENTUM_HOLD_DURATION: float = 0.25


const CHAIN_MAX_SPEED: float = 320.0
const CHAIN_HANG_MAX_SPEED: float = 160.0
const CHAIN_HANG_DAMP_FACTOR: float = 1
const CHAIN_HANG_MOMENTUM_DECAY: float = 0.99
const CHAIN_HANG_CLIMB_MOMENTUM_DECAY: float = CHAIN_HANG_MOMENTUM_DECAY
const CHAIN_HANG_GRAVITY_SCALE: float = 1.0
const CHAIN_GRAVITY: float = GRAVITY / 5.0
const CHAIN_GRAVITY_MULTIPLIER: float = 1.6
const CHAIN_JUMP_DIRECTIONAL_FORCE_SCALE: float = 0.5
const CHAIN_HANG_CLIMB_SPEED: float = 80.0
const CHAIN_HANG_EXTEND_SPEED: float = 80.0
const MAX_CARRY_LINE_LENGTH: float = 50.0

const CHAIN_HANG_WALL_COLLISION_DAMPING: float = 0.3
const CHAIN_HANG_WALL_COLLISION_NORMAL_DAMPING: float = 0.1
const CHAIN_HANG_WALL_COLLISION_MIN_SPEED: float = 30.0


const HOOK_ROTATION_VELOCITY_EPS: float = 0.0001
const HOOK_STICK_Z_INDEX: int = -5
const HOOK_COLLISION_RADIUS: float = 1.0
const HOOK_RETRACTION_DELAY: float = 0.0


const KUNAI_COOLDOWN_MIN_MULTIPLIER: float = 0.3
const KUNAI_EXPLODE_DELAY: float = 0.3
const KUNAI_TILE_SAMPLE_EPS: float = 0.1
const KUNAI_COLLISION_RADIUS: float = 1.0
const KUNAI_ROTATION_VELOCITY_EPS: float = 0.0001
const KUNAI_STICK_Z_INDEX: int = -5
const KUNAI_STAR_SPIN_SPEED: float = 20.0
const KUNAI_BOUNCE_MIN_ANGLE_DEGREES: float = 55.0
const KUNAI_BOUNCE_DAMPING: float = 0.85
const KUNAI_BOUNCE_MAX_COUNT: int = 3
const KUNAI_BOUNCE_COLLIDE_DELAY: float = 0.045
const KUNAI_BOUNCE_SEPARATION: float = 0.6
const KUNAI_BOUNCE_FORWARD_OFFSET: float = 0.5
const KUNAI_MIN_BOUNCE_SPEED: float = 40.0
const KUNAI_MAX_DISTANCE: float = 400.0


const HOOK_CAMERA_MIN_DISTANCE: float = 0.0
const HOOK_CAMERA_POSITION_SPEED: float = 4.0
const HOOK_CAMERA_VELOCITY_LEAD: float = 1
const HOOK_CAMERA_RAMP_SPEED: float = 2.8
const HOOK_CAMERA_SMOOTHING: float = 5.0
