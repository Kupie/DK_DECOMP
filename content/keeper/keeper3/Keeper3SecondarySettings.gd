extends Object
class_name Keeper3SecondarySettings


const KUNAI_BACK_OFFSETS: Dictionary = preload("res://content/keeper/keeper3/KunaiBackOffsets.gd").OFFSETS
const KUNAI_ANCHOR_DEFAULT_ANIMATION: = "idle"


const HOOK_SCENE: PackedScene = preload("res://content/keeper/keeper3/Hook.tscn")
const HOOK_TILE_BURST_VFX: PackedScene = preload("res://content/keeper/keeper3/KunaiImpactBurst.tscn")
const HOOK_CHAIN_ROPE_SCRIPT: = preload("res://content/keeper/keeper3/ChainRope.gd")
const KUNAI_TILE_BURST_VFX: PackedScene = preload("res://content/keeper/keeper3/KunaiImpactBurst.tscn")
const KUNAI_BOUNCE_VFX: PackedScene = preload("res://content/gadgets/drillbot/FootstepDust.tscn")
const KUNAI_BOUNCE_SFX: AudioStream = preload("res://content/sounds/Weapons/Sword/Sword_Deflect.wav")


const WALL_SLIDE_DUST_INTERVAL: float = 0.12
const WALL_SLIDE_DUST_OFFSET: float = 8.0
const WALL_JUMP_DUST_FORWARD_OFFSET: float = 10.0
const WALL_JUMP_DUST_VERTICAL_OFFSET: float = -8.0
const WALL_JUMP_DUST_COLLISION_PUSH: float = 2.0


const CHAIN_LINK_SCENE: PackedScene = preload("res://content/keeper/keeper3/ChainLink.tscn")
const CHAIN_MIN_LINKS: int = 2
const CHAIN_MAX_LINKS: int = 40
const CHAIN_LINK_LENGTH: float = 5.0
const CHAIN_SOLVER_ITERATIONS: int = 10
const CHAIN_DAMPING: float = 0.97
const CHAIN_KEEPER_INV_MASS: float = 0.5
const CHAIN_RETRACTION_SPEED_DEFAULT: float = 320.0
const CHAIN_VISUAL_RETURN_SPEED: float = 520.0
const CHAIN_VISUAL_RETURN_REMOVE_DISTANCE: float = 6.0
const CHAIN_RETRACTION_DELAY_DEFAULT: float = 0.0
const CHAIN_RETRACTION_STOP_DISTANCE: float = 30.0
const CHAIN_TOTAL_SLACK: float = 25.0
const CHAIN_MAX_TRAVEL_DISTANCE: float = 350.0
const CHAIN_VISUAL_LINK_SPACING: float = 5.0
const CHAIN_MAX_VISUAL_LINKS: int = 200
const CHAIN_CURVE_BAKE_INTERVAL: float = 3.0
const CHAIN_TANGENT_SAMPLE_OFFSET: float = 1.0
const CHAIN_VISUAL_CURVE_TENSION: float = 0.4
const CHAIN_VISUAL_CURVE_ENDPOINT_FACTOR: float = 1.0
const CHAIN_MODE_TRAVEL: int = 0
const CHAIN_MODE_RETRACT: int = 1
const CHAIN_ATTACHMENT_SCRIPT: = preload("res://content/keeper/keeper3/ChainAttachment.gd")
const CHAIN_USAGE_HOOK: int = 0
const CHAIN_USAGE_CARRY: int = 1
const CARRY_CHAIN_LINK_LENGTH = 7
const CARRY_CHAIN_LINK_COUNT: int = 2
const CARRY_CHAIN_BASE_INV_MASS: float = 0.0
const CARRY_FOLLOW_REST_DISTANCE: float = CARRY_CHAIN_LINK_LENGTH * float(CARRY_CHAIN_LINK_COUNT)
const CARRY_CHAIN_VISUAL_MAX_STRETCH: float = CARRY_FOLLOW_REST_DISTANCE * 1.3
const CARRY_CARRIED_GRAVITY_SCALE: float = 2.8
const CARRY_SPRING_STIFFNESS: float = 550.0
const CARRY_SPRING_DAMPING: float = 18.0
const CARRY_ORBITAL_DAMPING: float = 4.0
const CARRY_CHAIN_STRAIGHTENING_FORCE: float = 0.02
const CARRY_CHAIN_ATTACHED_STRAIGHTENING_MULTIPLIER: float = 0.0
const CARRY_CHAIN_BLOCKED_FOLLOW_FORCE: float = 0.5
const CARRY_KUNAI_CARRIED_BOUNCE: float = 0.0
const CARRY_CARRIER_DETACH_FALL_VELOCITY: float = 10.0
const CARRY_CARRIER_DETACH_FALL_HORIZONTAL: float = 15.0
const GADGET_THROW_IMPULSE: float = 45.0
const DROP_CARRY_PUSH_IMPULSE: float = 30.0
const TELEPORTER_THROW_IMPULSE: float = 0.0


const CARRIER_ROTATION_VELOCITY_EPS: float = 0.0001
const CARRIER_STICK_Z_INDEX: int = -5
const CARRIER_COLLISION_RADIUS: float = 1
const CARRIER_CORNER_MARGIN: float = 4.0
const CARRIER_TILE_BURST_VFX: PackedScene = preload("res://content/keeper/keeper3/KunaiImpactBurst.tscn")
const CARRIER_CHAIN_SCENE: PackedScene = preload("res://content/keeper/keeper3/Keeper3CarryChain.tscn")
const CARRIER_CHAIN_LINK_SPACING: float = 5.0
const CARRIER_CHAIN_MAX_LINKS: int = 64
const CARRIER_CHAIN_Z_INDEX: int = 24
const CARRY_CHAIN_LINK_Z_INDEX: int = 9

const LIFT_DOCK_X_THRESHOLD: float = 2.0
const LIFT_COMPRESSION_IMPULSE: float = 50.0
const LIFT_RELEASE_UPWARD_IMPULSE: float = 100.0
const LIFT_COMPRESSION_SETTLE_DISTANCE: float = 20.0
const LIFT_COMPRESSION_SETTLE_VELOCITY: float = 15.0
