extends Keeper
class_name Keeper3

enum HookState{Idle, Traveling, Attached, Detached}

const SPECIAL_KUNAI_BASE_COOLDOWN: = 5.0
const CHAIN_FLY_MIN_ANGLE_DEGREES: = 75.0
const LANDING_PREDICT_DISTANCE: = 200.0
const LANDING_MIN_VERTICAL_SPEED: = 30.0
const LANDING_LEAD_TIMES: = {
	"land_front": 0.18, 
	"land_left": 0.18, 
	"land_right": 0.18, 
	"landing_from_roll_left": 0.55, 
	"landing_from_roll_right": 0.55, 
}
const FLOOR_SUPPORT_PROBE_DISTANCE: = 4.0
const FLOOR_SUPPORT_PROBE_DISTANCE_DOME: = 8.0
const FLOOR_MAX_ANGLE_DEFAULT: = 0.15708
const FLOOR_MAX_ANGLE_DOME: = 0.2618
const FLOOR_SNAP_LENGTH_DEFAULT: = 0.0
const FLOOR_SNAP_LENGTH_DOME: = 2.0
const KEEPER3_MOUSE_TOO_CLOSE_THRESHOLD: = 5


@onready var cooldownManager: = CooldownManager.new()
@onready var specialKunaiStar: Node2D = $SpecialKunaiStar
@onready var specialKunaiReadyVfx: GPUParticles2D = $SpecialKunaiStar / SpecialKunaiReadyVfx
@onready var chainSpawnPivot: Node2D = $ChainSpawnPivot
@onready var wallSlideDust: GPUParticles2D = $WallSlideDust
@onready var wallSlidingSound = $WallSliding
@onready var wallJumpSound = get_node_or_null("WallJumpSound")
@onready var wallGrabSound = get_node_or_null("WallgrabSound")
@onready var rayCastLeft: RayCast2D = $RayCastLeft
@onready var rayCastRight: RayCast2D = $RayCastRight
@onready var trajectoryPredictor: Node2D = $KunaiTrajectoryPredictor
@onready var spriteNode: AnimatedSprite2D = $Visuals / Sprite2D
@onready var aimIndicator: Node2D = $AimIndicator



var last_throw_click_time: = 0.0
var double_click_threshold: = 0.3
var single_click_timer: Timer
var was_double_click: = false
var autoShoot: = false

var kunaiSpeed: float = 500.0
var kunaiCarrierSpeed: float = 500.0
var specialKunaiCount: int = 0
var maxSpecialKunaiCount: int = 0


var rope_cooldown: float = 0.3
var hookSpeed: float = 900.0
var propelGraceLeft: = 0.0
var isPropelling: bool = false
var lastAnchor: Vector2 = Vector2(0, 0)
var propelInitialDistance: float = 0.0
var propelInitialSpeed: float = 0.0
var hook: HookKunai


var landingAnticipationActive: = false
var landingAnticipationAnimation: StringName = StringName("")
var hookState: int = HookState.Idle
var inheritedPropelHorizontalSpeed: float = 0.0
var inheritedPropelMomentumTimer: float = 0.0
var chainRopeNode: ChainRope
var chainBall: ChainAttachment
var chainActive: bool = false
var chainPulling: bool = false
var chainHanging: bool = false
var _hanging_effective_climb: int = 0
var chainHangJumpReady: bool = false
var chainGravityVelocity: float = 0.0
var chainStuckTimer: float = 0.0
var chainStuckThreshold: float = 0.3
var previousChainDistance: float = 0.0
var chainStuckPosition: Vector2 = Vector2.ZERO
var chainStuckCount: int = 0


var jumpCount: = 0
var firstJumpGraceActive: = true
var firstJumpGraceTimer: = Keeper3GameplaySettings.OFF_FLOOR_JUMP_GRACE
var jumpAscending: = false
var jumpHoldTimer: = 0.0
var currentJumpProfileIndex: = -1
var lastFacingRight: = true

var wallSlideActive: bool = false
var wallSlideDirection: int = 0
var wallSlideDustTimer: float = 0.0
var wallSlideBlockTimer: float = 0.0
var wallJumpInputLockTimer: float = 0.0
var wallSlideActiveTimer: float = 0.0
var cornerClimbActive: bool = false

var chainVelocity: = Vector2(0, 0)
var escapeVelocity: = Vector2(0, 0)
var pressingDown = false
var pressingUp = false
var justPressedUp = false
var justPressedUpThisFrame: = false
var pressingThrow = false
var wasOnRope = false
var wasGrounded = true
var airOppositeInputActive: bool = false
var airIgnoreInputUntilRelease: bool = false
var airReleaseDecelActive: bool = false
var lastAirHadInput: bool = false
var lastAirInputDirection: float = 0.0
var lastAirVelocityDirection: float = 0.0
var stepTimer = 0
var climbStepTimer = 0
var pendingRollLanding: = false
var lastFallAnimation: StringName = StringName("")


var loadoutClimbingMode: = false

var drillClimbActive: = false
var _drill_climb_ref: SideDriller = null


var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")


var _specialKunaiCooldownDuration: = 0.0
var _specialKunaiIsReady: = false
var _specialKunaiStarBaseOffset: Vector2 = Vector2.ZERO
var _specialKunaiAnchorReference: Vector2 = Vector2.ZERO
var _specialKunaiStarSuppressed: = false

var _jumpSoundBaseDb: = 0.0
var _jumpVfxBaseAmount: = 1
var _jumpVfxBaseSpeedScale: = 1.0
var _wallJumpSoundBaseDb: = 0.0

var chainManager: ResourceChainManager

var _hookCameraPositionOffset: = Vector2.ZERO
var _hookCameraRamp: = 0.0

var _frame_speed_buff: = 0.0
var _frame_drill_buff: = 0.0
var _frame_slide_control: = 0.0
var _frame_max_jumps: = 0
var _frame_jump_amplification: = 0.0
var _frame_air_control: = 0.0
var _fastFallActive: = false
var _moveShurikenSoundGrace: = 0.0
var _frame_carry_limit: = 0
var _frame_bounce_preview: = false
var _frame_lift_upwards_speed: = 0.0
var _frame_kunai_cooldown_level: = 0

var _physics_frame_id: = 0
var _wall_touch_cache_frame: = -1
var _wall_touch_cache: = {-1: false, 1: false}

var _allowHookDetach: bool = true

var dropCarryablesLatched: = false
var disable_auto_pickup_until: = 0.0
var _carrier_pickup_overlaps: Array[KunaiCarrier] = []

var downwardsDropCount: = 0
var kunaiCarrierDeployCount: = 0

func init():
	super.init()

	var sprite: = get_node_or_null("Sprite2D") as AnimatedSprite2D
	if is_instance_valid(sprite):
		sprite.frame = 0
	focussedUsable = null
	focussedCarryable = null

	Style.init(self)

	Level.addTutorial(self, "ninja_intro", playerId)
	Level.addTutorial(self, "infiltrator_drop", playerId)
	Level.addTutorial(self, "infiltrator_carry", playerId)
	Level.addTutorial(self, "infiltrator_mining", playerId)
	Level.addTutorial(self, "infiltrator_jumping", playerId)
	Level.addTutorial(self, "infiltrator_pickup", playerId)
	Level.addTutorial(self, "infiltrator_rope", playerId)
	Level.addTutorial(self, "infiltrator_shuriken", playerId)

	_update_frame_cache()

func getChainSpawnNode() -> Node2D:
	return chainSpawnPivot

func updateCarryables():
	if not is_multiplayer_authority():
		return

	if not is_instance_valid(focussedCarryable):
		focussedCarryable = null

	if focussedCarryable:
		if not focussedCarryable.canFocusCarry()\
		or not carryables.has(focussedCarryable)\
		or carriedCarryables.has(focussedCarryable)\
		or (focussedCarryable.is_in_group("usables") and not usables.has(focussedCarryable.get_meta("usable"))):
			focussedCarryable.unfocusCarry(self)
			focussedCarryable = null


	var closest_carryable = null
	var closest_distance_sq: float = INF
	var max_distance_sq: = Keeper3GameplaySettings.MANUAL_PICKUP_RADIUS * Keeper3GameplaySettings.MANUAL_PICKUP_RADIUS
	var carrier_max_distance_sq: = Keeper3GameplaySettings.CARRIER_PICKUP_RADIUS * Keeper3GameplaySettings.CARRIER_PICKUP_RADIUS
	for carryable in carryables:
		if not is_instance_valid(carryable):
			continue
		if carriedCarryables.has(carryable):
			continue
		if carryable.isCarried():
			continue
		if not carryable.canFocusCarry(teamId):
			continue
		if pickupType != "" and pickupType != carryable.carryableType:
			continue
		if carryable.is_in_group("usables") and not usables.has(carryable.get_meta("usable")):
			continue
		var distance_sq: float = carryable.global_position.distance_squared_to(global_position)
		if distance_sq > (carrier_max_distance_sq if carryable is KunaiCarrier else max_distance_sq):
			continue
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest_carryable = carryable

	if closest_carryable == null:
		return

	if focussedCarryable == closest_carryable:
		return
	if focussedCarryable:
		focussedCarryable.unfocusCarry(self)
	focussedCarryable = closest_carryable
	focussedCarryable.focusCarry(self)

func has_focus() -> bool:
	return (focussedUsable != null and is_instance_valid(focussedUsable)) or (focussedCarryable != null and is_instance_valid(focussedCarryable))

func has_meaningful_focus() -> bool:
	if drillClimbActive:
		return true
	if focussedUsable != null and is_instance_valid(focussedUsable):
		return true
	if focussedCarryable != null and is_instance_valid(focussedCarryable):
		var carryable_type: String = focussedCarryable.carryableType if "carryableType" in focussedCarryable else "unknown"
		if carryable_type == "resource":
			return false
		return true
	return false

func try_pickup_focussed() -> bool:
	if not focussedCarryable or not is_instance_valid(focussedCarryable):
		return false
	if focussedCarryable is KunaiCarrier:
		if carriedCarryables.size() >= _frame_carry_limit:
			return false
		Level.drops.network_request_transfer_kunai_carrier(playerId, focussedCarryable.UID)
		return true
	if focussedCarryable.has_method("isCarried") and focussedCarryable.isCarried() and not focussedCarryable.isCarriedBy(self):
		return false
	if focussedCarryable.has_meta("kunai_carrier") and focussedCarryable.get_meta("kunai_carrier") != null:
		return false

	if carriedCarryables.size() >= _frame_carry_limit:
		dropCarry(carriedCarryables.back())

	attachCarry(focussedCarryable)
	focussedCarryable = null
	return true

func pickupHold():
	if isInsideStation or disabled:
		return false

	updateCarryables()
	try_pickup_focussed()
	if focussedCarryable:
		pickupType = focussedCarryable.carryableType

func pickupHoldStopped():
	pickupType = ""

func pickupHit():
	if isInsideStation or disabled:
		return false

	updateCarryables()
	try_pickup_focussed()

func interact_tap() -> bool:


	if focussedUsable and is_instance_valid(focussedUsable):
		if focussedUsable.has_method("useHit"):
			if focussedUsable.useHit(self):
				return true


	if focussedCarryable and is_instance_valid(focussedCarryable):
		return try_pickup_focussed()

	return false

func interact_hold() -> bool:

	if focussedCarryable and is_instance_valid(focussedCarryable):
		return try_pickup_focussed()
	return false

func _ready():
	super._ready()

	if StageManager.isInDeviceSelection() or StageManager.isInLoadout():
		loadoutClimbingMode = true

	add_child(cooldownManager)
	cooldownManager.connect("cooldown_ready", on_cooldown_ready)

	chainManager = ResourceChainManager.new()
	chainManager.set_name("ResourceChainManager")
	chainManager.carrier = self
	chainManager.carriedCarryables = carriedCarryables
	add_child(chainManager)
	if has_node("Jumpsound"):
		var jump_sound = $Jumpsound
		_jumpSoundBaseDb = jump_sound.volume_db
	if is_instance_valid(wallJumpSound):
		_wallJumpSoundBaseDb = wallJumpSound.volume_db
	if has_node("StepDust"):
		var dust: GPUParticles2D = $StepDust
		_jumpVfxBaseAmount = int(max(dust.amount, 1))
		_jumpVfxBaseSpeedScale = float(max(dust.speed_scale, 0.01))

	if has_node("Visuals/Sprite2D"):
		$Visuals / Sprite2D.animation_changed.connect(_on_sprite_animation_changed)
	if is_instance_valid(wallSlideDust):
		wallSlideDust.emitting = false
		wallSlideDustTimer = 0.0
	if is_instance_valid(rayCastLeft):
		rayCastLeft.enabled = true
	if is_instance_valid(rayCastRight):
		rayCastRight.enabled = true

	if is_instance_valid(specialKunaiStar):
		if is_instance_valid(spriteNode):
			_specialKunaiStarBaseOffset = specialKunaiStar.position - spriteNode.position
	var default_offsets: Array = Keeper3SecondarySettings.KUNAI_BACK_OFFSETS.get(Keeper3SecondarySettings.KUNAI_ANCHOR_DEFAULT_ANIMATION, [])
	if not default_offsets.is_empty():
		var default_anchor = default_offsets[0]
		if default_anchor is Vector2:
			_specialKunaiAnchorReference = default_anchor
	var has_special_kunai: = bool(Data.ofOr(playerId + ".keeper3.hasshuriken", false))
	_specialKunaiCooldownDuration = 0.0
	if has_special_kunai:
		_specialKunaiCooldownDuration = float(Data.ofOr(playerId + ".keeper3.shurikencooldown", SPECIAL_KUNAI_BASE_COOLDOWN))
	_sync_special_kunai_star_with_cooldown()

	single_click_timer = Timer.new()
	single_click_timer.one_shot = true
	single_click_timer.wait_time = double_click_threshold
	single_click_timer.connect("timeout", Callable(self, "_on_single_click_confirmed"))
	add_child(single_click_timer)

	if is_instance_valid(spriteNode):
		spriteNode.connect("frame_changed", Callable(self, "_update_special_kunai_star_position"))
		spriteNode.connect("animation_changed", Callable(self, "_update_special_kunai_star_position"))
		_update_special_kunai_star_position()

func _update_frame_cache() -> void :
	_frame_speed_buff = float(Data.ofOr(playerId + ".keeper.speedbuff", 0.0))
	_frame_drill_buff = float(Data.ofOr(playerId + ".keeper.drillbuff", 0.0))
	_frame_slide_control = float(Data.of(playerId + ".keeper3.slidecontrol"))
	_frame_max_jumps = int(Data.of(playerId + ".keeper3.maxjumps"))
	_frame_jump_amplification = float(Data.of(playerId + ".keeper3.jumpamplification"))
	_frame_air_control = float(Data.of(playerId + ".keeper3.aircontrol"))
	_frame_carry_limit = int(Data.of(playerId + ".keeper3.carrylimit"))
	_frame_bounce_preview = bool(Data.of(playerId + ".keeper3.bouncepreview"))
	_frame_lift_upwards_speed = float(Data.ofOr(playerId + ".keeper.additionalupwardsspeed", 0))
	var kcl: = 0
	if GameWorld.boughtUpgrades.has(playerId + ".keeper3kunaicooldown3"):
		kcl = 3
	elif GameWorld.boughtUpgrades.has(playerId + ".keeper3kunaicooldown2"):
		kcl = 2
	elif GameWorld.boughtUpgrades.has(playerId + ".keeper3kunaicooldown1"):
		kcl = 1
	_frame_kunai_cooldown_level = kcl

func _start_special_kunai_cooldown(duration: float) -> void :
	if not is_instance_valid(specialKunaiStar):
		return
	_specialKunaiCooldownDuration = max(duration, 0.001)
	_apply_special_kunai_star_visibility(true)
	_set_special_kunai_star_progress(0.0)
	if is_instance_valid(specialKunaiReadyVfx):
		specialKunaiReadyVfx.emitting = false
	_specialKunaiIsReady = false
	$MoveShurikenSound.stopIfPlaying()

func _set_special_kunai_star_progress(progress: float) -> void :
	if not is_instance_valid(specialKunaiStar):
		return
	specialKunaiStar.visible = not _specialKunaiStarSuppressed and progress >= 1.0
	if is_instance_valid(specialKunaiReadyVfx):
		var was_ready: = _specialKunaiIsReady
		_specialKunaiIsReady = progress >= 0.999
		if _specialKunaiIsReady:
			if not was_ready and not _specialKunaiStarSuppressed:
				specialKunaiReadyVfx.emitting = false
				specialKunaiReadyVfx.emitting = true
				$SpecialKunaiStar / ShurikenReadySound.startSound()
				specialKunaiReadyVfx.restart()
		else:
			specialKunaiReadyVfx.emitting = false

func _sync_special_kunai_star_with_cooldown() -> void :
	if not is_instance_valid(specialKunaiStar):
		return
	var has_special: = bool(Data.ofOr(playerId + ".keeper3.hasshuriken", false))
	_apply_special_kunai_star_visibility(has_special)
	if not has_special:
		if is_instance_valid(specialKunaiReadyVfx):
			specialKunaiReadyVfx.emitting = false
		_specialKunaiIsReady = false
		$MoveShurikenSound.stopIfPlaying()
		return
	var remaining: float = cooldownManager.get_remaining("kunai_special")
	if cooldownManager.is_ready("kunai_special"):
		_set_special_kunai_star_progress(1.0)
		return
	var duration: float = _specialKunaiCooldownDuration
	if duration <= 0.0:
		duration = max(float(Data.ofOr(playerId + ".keeper3.shurikencooldown", SPECIAL_KUNAI_BASE_COOLDOWN)), 0.001)
		_specialKunaiCooldownDuration = duration
	var progress: float = 1.0 - (remaining / duration)
	_set_special_kunai_star_progress(progress)

func _apply_special_kunai_star_visibility(should_show: bool) -> void :
	if not is_instance_valid(specialKunaiStar):
		return
	var show_star: = should_show and not _specialKunaiStarSuppressed
	specialKunaiStar.visible = show_star
	if not show_star and is_instance_valid(specialKunaiReadyVfx):
		specialKunaiReadyVfx.emitting = false

func _set_special_kunai_star_suppressed(suppressed: bool) -> void :
	if _specialKunaiStarSuppressed == suppressed:
		return
	_specialKunaiStarSuppressed = suppressed
	if suppressed:
		_specialKunaiIsReady = false
		$MoveShurikenSound.stopIfPlaying()
		_apply_special_kunai_star_visibility(false)
	else:
		_sync_special_kunai_star_with_cooldown()

func _resolve_kunai_animation_key(animation_name: String) -> String:
	if Keeper3SecondarySettings.KUNAI_BACK_OFFSETS.has(animation_name):
		return animation_name
	var idx: = animation_name.rfind("_")
	while idx != -1:
		var candidate: = animation_name.substr(0, idx)
		if Keeper3SecondarySettings.KUNAI_BACK_OFFSETS.has(candidate):
			return candidate
		idx = animation_name.rfind("_", idx - 1)
	return Keeper3SecondarySettings.KUNAI_ANCHOR_DEFAULT_ANIMATION

func _update_special_kunai_star_position(_unused = null) -> void :
	if not is_instance_valid(specialKunaiStar):
		return
	if not is_instance_valid(spriteNode):
		return
	var animation_name: = String(spriteNode.animation)
	_update_special_kunai_star_z_order(animation_name)
	var target_offset: Vector2 = _specialKunaiStarBaseOffset
	if not animation_name.is_empty():
		var resolved: = _resolve_kunai_animation_key(animation_name)
		var offsets: Array = Keeper3SecondarySettings.KUNAI_BACK_OFFSETS.get(resolved, [])
		if not offsets.is_empty():
			var frame_index: int = clampi(spriteNode.frame, 0, offsets.size() - 1)
			var candidate = offsets[frame_index]
			if candidate is Vector2:
				target_offset = _specialKunaiStarBaseOffset + (candidate - _specialKunaiAnchorReference)
	specialKunaiStar.position = spriteNode.position + target_offset

func _update_special_kunai_star_z_order(animation_name: String) -> void :
	if not is_instance_valid(specialKunaiStar):
		return
	var should_be_in_front: = animation_name.begins_with("climb_")
	var desired_z: = 1 if should_be_in_front else -1
	if specialKunaiStar.z_index != desired_z:
		specialKunaiStar.z_index = desired_z

func useHold() -> bool:
	if isInsideStation or disabled:
		return false
	if drillClimbActive and is_instance_valid(_drill_climb_ref):
		_drill_climb_ref.useHold(self)
		return true
	if not drillClimbActive and focussedUsable and is_instance_valid(focussedUsable):
		var usable_parent = focussedUsable.get_parent()
		if usable_parent is SideDriller and not (usable_parent as SideDriller).grabbed:
			_enter_drill_climb(usable_parent as SideDriller)
	return super.useHold()

func enterStation(station, dropResources: = true):
	aimIndicator.modulate.a = 0.0
	if drillClimbActive:
		_exit_drill_climb(false)
	super.enterStation(station, dropResources)
	releaseHookInput()
	_set_special_kunai_star_suppressed(true)

func startTeleportation(source, duration: float, fromPos: Vector2, goalPos: Vector2, allowCarryableTeleportation: bool, allowLargeDropTeleportation: = false):
	releaseHookInput()
	super.startTeleportation(source, duration, fromPos, goalPos, allowCarryableTeleportation, allowLargeDropTeleportation)
	var fall_anim: String = ("fall_right" if lastFacingRight else "fall_left") + animationSuffix
	spriteNode.play(fall_anim)

func exitStation():
	super.exitStation()
	aimIndicator.modulate.a = 1.0
	_set_special_kunai_star_suppressed(false)

func pauseChanged():
	super.pauseChanged()
	if GameWorld.paused:
		spriteNode.pause()
	else:
		spriteNode.play()
		chainManager.release_pause_lock()

func _physics_process(delta: float) -> void :
	var was_inside_dome: = isInsideDome
	super._physics_process(delta)

	if not was_inside_dome and isInsideDome and not carriedCarryables.is_empty() and not isInsideStation and multiplayer.is_server():
		_auto_deploy_carrier_on_dome_entry()

	_physics_frame_id += 1

	_update_frame_cache()
	%BuffedSprite.visible = (_frame_speed_buff > 0 or _frame_drill_buff > 0) and not isInsideStation


	if isInsideDome:
		floor_max_angle = FLOOR_MAX_ANGLE_DOME
		floor_snap_length = FLOOR_SNAP_LENGTH_DOME
	else:
		floor_max_angle = FLOOR_MAX_ANGLE_DEFAULT
		floor_snap_length = FLOOR_SNAP_LENGTH_DEFAULT

	_sync_special_kunai_star_with_cooldown()
	chainManager.update_chain_visuals()
	if isInsideStation or GameWorld.paused or disabled:
		if GameWorld.paused:
			chainManager.lock_carried_bodies_for_pause()
		if disable_source is OneWayTeleporter:

			chainManager.update_chains(delta)
		return


	wallJumpInputLockTimer = max(wallJumpInputLockTimer - delta, 0.0)

	updateInteractables()
	if input_settings.auto_pickup:
		automaticPickup()
	updateCarry()
	chainManager.update_chains(delta)

	if autoShoot and cooldownManager.is_ready("kunai") and checkGenCanThrow():
		_handle_auto_kunai_ready()

	inheritedPropelMomentumTimer = max(inheritedPropelMomentumTimer - delta, 0.0)
	if inheritedPropelMomentumTimer <= 0.0:
		inheritedPropelHorizontalSpeed = 0.0

	if hookState == HookState.Attached and is_instance_valid(hook) and is_instance_valid(hook.attached_target):
		var target_parent: Node = hook.attached_target.get_parent()
		if target_parent is SideDriller and (target_parent as SideDriller).timeSinceTouch >= 0.0:
			releaseHookInput()

	if not loadoutClimbingMode and not drillClimbActive:
		_update_jump_state(delta)
		_update_hook_camera(delta)

	if not isInsideStation:
		keeperMovement(delta)
	if not loadoutClimbingMode and not drillClimbActive:
		_update_trajectory_prediction()
		_update_aim_indicator(delta)

func _update_aim_indicator(delta: float) -> void :

	var aimDirection = getAimDirection("rope_snap")

	if aimDirection.length() == 0:
		aimIndicator.modulate.a = 0
	else:
		if aimIndicator.modulate.a == 0:
			aimIndicator.rotation = aimDirection.angle()
		else:
			aimIndicator.rotation = lerp_angle(aimIndicator.rotation, aimDirection.angle(), delta * 30.0)
		aimIndicator.modulate.a = 1

func _update_jump_state(delta: float) -> void :
	if jumpAscending:
		jumpHoldTimer += delta
	var on_floor_now: = _is_grounded()
	if on_floor_now:
		firstJumpGraceActive = true
		firstJumpGraceTimer = Keeper3GameplaySettings.OFF_FLOOR_JUMP_GRACE
	else:
		if firstJumpGraceActive:
			firstJumpGraceTimer = max(firstJumpGraceTimer - delta, 0.0)
			if firstJumpGraceTimer == 0.0:
				firstJumpGraceActive = false
				if jumpCount == 0:
					jumpCount = 1

func _is_grounded() -> bool:
	if not is_on_floor():
		return false
	var probe_distance: float = FLOOR_SUPPORT_PROBE_DISTANCE_DOME if isInsideDome else FLOOR_SUPPORT_PROBE_DISTANCE
	return test_move(global_transform, Vector2.DOWN * probe_distance)


func keeperMovement(delta):

	checkPressedInput()

	var _keepMoveShurikenSound: bool = (_is_grounded() and abs(_effective_move_input().x) >= 0.1) or (wallSlideActive and _specialKunaiIsReady and abs(velocity.y) >= 1.0)
	if _keepMoveShurikenSound:
		_moveShurikenSoundGrace = 0.0
		if _specialKunaiIsReady and not $MoveShurikenSound.shouldPlay:
			$MoveShurikenSound.startSound()
	elif _moveShurikenSoundGrace > 0.0:
		_moveShurikenSoundGrace -= delta
	else:
		$MoveShurikenSound.stopIfPlaying()


	if loadoutClimbingMode:
		_handle_loadout_climbing(delta)
		return

	if drillClimbActive:
		if is_multiplayer_authority():
			_handle_drill_climb(delta)
		else:
			var observer_input: = moveDirectionInput
			observer_input.x = 0.0
			_apply_drill_climb_animation(observer_input)
		return

	if chainActive:
		_clear_landing_anticipation()
		if justPressedUp and _attempt_chain_jump():
			return
		_update_chain_motion(delta)
		return

	if isPropelling:
		_clear_landing_anticipation()
		if hookState == HookState.Detached:
			var jump_from_propel: = _attempt_jump(true)
			if jump_from_propel and not isPropelling:
				$Visuals / Sprite2D.rotation = 0
				return
		propelGraceLeft -= delta

		$Visuals / Sprite2D.rotation += 10 * delta
		$Visuals / Sprite2D.play("roll_left" + animationSuffix)

		var previous_velocity: = velocity

		velocity.y += Keeper3GameplaySettings.GRAVITY * delta

		var displacement: Vector2 = lastAnchor - global_position
		var desired_speed: float = propelInitialSpeed
		var direction: Vector2 = velocity
		if direction.length_squared() <= 0.0001:
			direction = displacement
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
		direction = direction.normalized()
		if hookState == HookState.Detached:
			var horizontal_input: float = moveDirectionInput.x
			if abs(horizontal_input) > 0.01:
				var steer: Vector2 = Vector2(horizontal_input, 0.0) * Keeper3GameplaySettings.PROPULSION_DETACHED_CONTROL_FORCE * delta
				var steered_direction: Vector2 = direction + steer
				if steered_direction.length_squared() > 0.0001:
					direction = steered_direction.normalized()
		velocity = direction * desired_speed

		var desired_velocity: Vector2 = velocity
		var remaining_motion: Vector2 = desired_velocity * delta
		var blocking_collision: = false
		var touched_floor: = false
		var iteration: = 0
		while remaining_motion.length_squared() > 0.0001 and iteration < 4:
			var collision: KinematicCollision2D = move_and_collide(remaining_motion)
			if collision:
				var normal: Vector2 = collision.get_normal()
				if normal.dot(Vector2.UP) > 0.6:
					touched_floor = true
					blocking_collision = true
					break
				if hookState == HookState.Attached:
					var remainder: = collision.get_remainder()
					remainder = remainder.slide(normal)
					if remainder.length_squared() <= 0.0001:
						blocking_collision = true
						break
					remaining_motion = remainder
					iteration += 1
					continue
				blocking_collision = true
				break
			else:
				break

		var close_to_anchor: = global_position.distance_to(lastAnchor) < Keeper3GameplaySettings.PROP_ANCHOR_REACH_RADIUS
		var can_collision_stop: = hookState != HookState.Attached
		if close_to_anchor or touched_floor or (blocking_collision and can_collision_stop):
			isPropelling = false
			velocity = previous_velocity.move_toward(Vector2.ZERO, 1500 * delta)
			$Visuals / Sprite2D.rotation = 0
		return

	if externallyMoved:
		if $Visuals / Sprite2D.animation != "idle":
			$Visuals / Sprite2D.play("idle")
		return

	if wasOnRope:
		fallingFromRopeMovement(delta)
		_attempt_jump()
		return
	else:
		var handled_wall_slide: = _handle_wall_slide(delta)
		if not handled_wall_slide:
			falling(delta)

	checkGrounded(delta)
	_attempt_jump()

func checkPressedInput():

	if moveDirectionInput.y <= 0.01:
		pressingDown = false


	justPressedUpThisFrame = justPressedUp


func _handle_loadout_climbing(delta: float) -> void :
	var input: Vector2 = _effective_move_input()
	var climb_speed: float = 120.0

	velocity = input.normalized() * climb_speed if input.length() > 0.1 else Vector2.ZERO
	move_and_slide()
	_apply_loadout_climbing_animation(input)
	if velocity.length() > 0:
		climbStepTimer -= delta
		if climbStepTimer <= 0:
			$Stepladdersound.startSound()
			climbStepTimer = Keeper3GameplaySettings.CLIMB_STEP_INTERVAL


func _apply_loadout_climbing_animation(input: Vector2) -> void :
	var sprite: AnimatedSprite2D = $Visuals / Sprite2D
	if not is_instance_valid(sprite):
		return

	var suffix: String = animationSuffix
	var anim: = ("climb_up" if input.y <= 0 else "climb_down") + suffix
	if sprite.animation != anim:
		sprite.play(anim)

	if input.length() < 0.1:
		sprite.pause()
	elif not sprite.is_playing():
		sprite.play()

func _enter_drill_climb(driller: SideDriller) -> void :
	if chainActive:
		detach_from_chain(false)
	if is_instance_valid(hook):
		hook.request_detach()
	if hookState != HookState.Idle:
		hookState = HookState.Detached
	if isPropelling:
		isPropelling = false
	if wasOnRope:
		wasOnRope = false
	if wallSlideActive:
		_exit_wall_slide(false)

	drillClimbActive = true
	_drill_climb_ref = driller
	velocity = Vector2.ZERO
	jumpCount = 0
	jumpAscending = false
	firstJumpGraceActive = false
	$Visuals / Sprite2D.rotation = 0

func _exit_drill_climb(jumping: bool) -> void :
	if is_instance_valid(_drill_climb_ref):
		var goal: float = _drill_climb_ref.get_clamped_tile_position(_drill_climb_ref.goalPos)
		_drill_climb_ref.holdStopped.emit(_drill_climb_ref.name, goal)
		_drill_climb_ref.releasePlayed = true
		_drill_climb_ref.timeSinceTouch = 0.0
	move = Vector2.ZERO
	drillClimbActive = false
	_drill_climb_ref = null
	if not jumping:
		velocity = Vector2.ZERO
		jumpCount = 0
		wasGrounded = false

func _handle_drill_climb(delta: float) -> void :
	if not is_instance_valid(_drill_climb_ref):
		_exit_drill_climb(false)
		return

	if not pressingUse:
		_exit_drill_climb(false)
		return

	var input: Vector2 = _effective_move_input()
	input.x = 0.0

	if justPressedUp:
		_exit_drill_climb(true)
		jumpCount = 0
		_start_jump()
		justPressedUp = false
		return

	_drill_climb_ref.useHold(self)

	var climb_speed: float = 80.0
	var drill_parent: Node2D = _drill_climb_ref.get_parent()
	var target_x: float = drill_parent.global_position.x

	global_position.x = target_x
	velocity.x = 0.0
	velocity.y = input.y * climb_speed if abs(input.y) > 0.1 else 0.0
	move_and_slide()
	global_position.x = target_x
	global_position.y = clamp(global_position.y, 60.0, _drill_climb_ref.maxDepth)

	_apply_drill_climb_animation(input)

func _apply_drill_climb_animation(input: Vector2) -> void :
	var sprite: AnimatedSprite2D = $Visuals / Sprite2D
	if not is_instance_valid(sprite):
		return
	var anim: = ("climb_up" if input.y <= 0 else "climb_down") + animationSuffix
	if sprite.animation != anim:
		sprite.play(anim)
	if abs(input.y) < 0.1:
		sprite.pause()
	elif not sprite.is_playing():
		sprite.play()

func checkGrounded(delta):
	var grounded: = _is_grounded()
	if grounded:
		if not wasGrounded:
			wasGrounded = true
			var sprite: AnimatedSprite2D = $Visuals / Sprite2D
			var current_animation: = ""
			if is_instance_valid(sprite):
				current_animation = String(sprite.animation)
			pendingRollLanding = jumpCount >= 2 or current_animation.begins_with("roll_") or current_animation.begins_with("landing_from_roll")
			_reset_jump_state_on_landing()
			resetStepTimer()
			land()
		jumpAscending = false
		isPropelling = false
		_fastFallActive = false
		inheritedPropelMomentumTimer = 0.0
		inheritedPropelHorizontalSpeed = 0.0
		if wasOnRope:
			wasOnRope = false
		chainVelocity = Vector2.ZERO
		escapeVelocity = Vector2.ZERO
		velocity.x *= Keeper3GameplaySettings.FRICTION_GROUND
		if velocity.y >= 5:
			velocity.y = 5
		checkKeeperStep(delta)
		groundAnimation()
	else:
		if wasGrounded:
			wasGrounded = false
			firstJumpGraceActive = true
			firstJumpGraceTimer = Keeper3GameplaySettings.OFF_FLOOR_JUMP_GRACE
		resetStepTimer()
		airAnimation()

func _reset_jump_state_on_landing() -> void :
	jumpCount = 0
	firstJumpGraceActive = true
	firstJumpGraceTimer = Keeper3GameplaySettings.OFF_FLOOR_JUMP_GRACE
	jumpAscending = false
	jumpHoldTimer = 0.0
	currentJumpProfileIndex = -1
	chainHangJumpReady = false

func _reset_jump_state_after_chain_hang() -> void :
	jumpCount = 0
	firstJumpGraceActive = true
	firstJumpGraceTimer = Keeper3GameplaySettings.OFF_FLOOR_JUMP_GRACE
	chainHangJumpReady = false
	jumpAscending = false
	jumpHoldTimer = 0.0
	currentJumpProfileIndex = -1

func _landing_lead_for(animation_name: StringName) -> float:
	var base: = String(animation_name)
	if animationSuffix != "" and base.ends_with(animationSuffix):
		base = base.substr(0, base.length() - animationSuffix.length())
	return float(LANDING_LEAD_TIMES.get(base, 0.0))

func _update_landing_anticipation(use_roll_landing: bool, horizontal_velocity: float) -> void :
	var sprite: AnimatedSprite2D = $Visuals / Sprite2D
	if not is_instance_valid(sprite) or velocity.y < LANDING_MIN_VERTICAL_SPEED:
		_clear_landing_anticipation()
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		_clear_landing_anticipation()
		return
	var direction: Vector2 = Vector2(velocity.x, max(velocity.y, 1.0))
	if direction.is_zero_approx():
		_clear_landing_anticipation()
		return
	direction = direction.normalized()
	var start: Vector2 = global_position
	var end: Vector2 = start + direction * LANDING_PREDICT_DISTANCE
	var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start, end, collision_mask, [self])
	var hit: Dictionary = space.intersect_ray(params)
	if hit.is_empty():
		_clear_landing_anticipation()
		return
	var hit_pos: Vector2 = hit.position
	var normal: Vector2 = hit.normal
	if normal.y > -0.7:
		_clear_landing_anticipation()
		return
	var vertical_distance: float = hit_pos.y - start.y
	if vertical_distance <= 0.0:
		_clear_landing_anticipation()
		return
	var time_to_floor: float = vertical_distance / max(velocity.y, 0.1)
	var current_anim: = String(sprite.animation)
	var want_roll: = use_roll_landing or current_anim.begins_with("roll_")
	var animation_name: StringName = _resolve_landing_animation(want_roll, horizontal_velocity)
	if animation_name == StringName(""):
		_clear_landing_anticipation()
		return
	var lead_time: float = _landing_lead_for(animation_name)
	if lead_time <= 0.0 or time_to_floor > lead_time:
		_clear_landing_anticipation()
		return
	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)
	if String(animation_name).begins_with("landing_from_roll"):
		pendingRollLanding = true
	landingAnticipationActive = true
	landingAnticipationAnimation = animation_name

func _clear_landing_anticipation() -> void :
	landingAnticipationActive = false
	landingAnticipationAnimation = StringName("")

func _resolve_landing_animation(use_roll_landing: bool, horizontal_velocity: float) -> StringName:
	var sprite: AnimatedSprite2D = $Visuals / Sprite2D
	if not is_instance_valid(sprite):
		return StringName("")
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		return StringName("")
	var suffix: = animationSuffix
	if use_roll_landing:
		var roll_base: String = "landing_from_roll_" + ("right" if lastFacingRight else "left")
		var roll_name: StringName = StringName(roll_base + suffix)
		if frames.has_animation(roll_name):
			return roll_name
	var base_anim: String = "land_front"
	if lastFallAnimation == StringName("fall_left"):
		base_anim = "land_left"
	elif lastFallAnimation == StringName("fall_right"):
		base_anim = "land_right"
	elif abs(horizontal_velocity) > Keeper3GameplaySettings.ANIMATION_HORIZONTAL_SPEED_DEADZONE:
		base_anim = "land_right" if horizontal_velocity > 0.0 else "land_left"
	var resolved: StringName = StringName(base_anim + suffix)
	if frames.has_animation(resolved):
		return resolved
	return StringName("")


func _apply_facing_hint(direction: float) -> void :
	if direction > 0.0:
		lastFacingRight = true
	elif direction < 0.0:
		lastFacingRight = false

func _apply_air_facing_hint(horizontal_velocity: float, input_direction: float) -> void :
	if horizontal_velocity > 0.1:
		lastFacingRight = true
	elif horizontal_velocity < -0.1:
		lastFacingRight = false
	else:
		_apply_facing_hint(input_direction)


func _handle_wall_slide(delta: float) -> bool:
	if wallSlideActive and _is_grounded():
		_exit_wall_slide(true)
		return false
	if wallSlideBlockTimer > 0.0:
		wallSlideBlockTimer = max(wallSlideBlockTimer - delta, 0.0)

	var input_dir: = 0
	var _eff: = _effective_move_input()
	if abs(_eff.x) > Keeper3GameplaySettings.AIR_INPUT_DEADZONE:
		input_dir = 1 if _eff.x > 0.0 else -1

	if wallSlideActive:
		var still_touching: = _is_touching_wall(wallSlideDirection)
		var at_corner: = _is_at_wall_corner(wallSlideDirection)
		var still_pressing: = wallSlideDirection == input_dir
		if not still_pressing:
			_exit_wall_slide(true)
			return false
		if not still_touching and not at_corner:
			_exit_wall_slide(true)
			return false
	else:
		var can_attempt: = wallSlideBlockTimer <= 0.0 and not _is_grounded() and input_dir != 0 and not isPropelling and not chainActive
		if can_attempt and _is_touching_wall(input_dir):
			_enter_wall_slide(input_dir)

	if not wallSlideActive:
		return false

	_clear_landing_anticipation()
	_apply_wall_slide_motion(delta)
	return true


func _enter_wall_slide(direction: int) -> void :
	wallSlideActive = true
	wallSlideDirection = direction
	wallSlideDustTimer = 0.0
	wallSlideActiveTimer = 0.0
	cornerClimbActive = false
	jumpAscending = false
	if direction != 0:
		_apply_facing_hint(float(direction))
	if is_instance_valid(wallGrabSound):
		wallGrabSound.startSound()
	if _specialKunaiIsReady:
		$MoveShurikenSound.startSound()
		_moveShurikenSoundGrace = 0.2
	if is_instance_valid(wallSlidingSound) and not wallSlidingSound.shouldPlay:
		if is_instance_valid(wallSlidingSound.FadeTween):
			wallSlidingSound.FadeTween.stop_all()
			wallSlidingSound.FadeTween.remove_all()
		wallSlidingSound.stop(true)
		wallSlidingSound.startSound()
	if is_instance_valid(wallSlideDust):
		wallSlideDust.position.x = Keeper3SecondarySettings.WALL_SLIDE_DUST_OFFSET * float(direction)
		wallSlideDust.emitting = false
		wallSlideDust.restart()
	firstJumpGraceActive = true
	firstJumpGraceTimer = Keeper3GameplaySettings.OFF_FLOOR_JUMP_GRACE
	jumpCount = 0
	_update_wall_slide_animation(velocity.y)


func _exit_wall_slide(start_grace: bool) -> void :
	if not wallSlideActive:
		return
	wallSlideActive = false
	wallSlideDirection = 0
	wallSlideDustTimer = 0.0
	wallSlideActiveTimer = 0.0
	cornerClimbActive = false
	if is_instance_valid(wallSlidingSound) and wallSlidingSound.shouldPlay:
		wallSlidingSound.stop()
	if is_instance_valid(wallSlideDust):
		wallSlideDust.emitting = false
	if start_grace:
		firstJumpGraceActive = true
		firstJumpGraceTimer = Keeper3GameplaySettings.OFF_FLOOR_JUMP_GRACE
	wallSlideBlockTimer = Keeper3GameplaySettings.WALL_SLIDE_BLOCK_TIME


func _apply_wall_slide_motion(delta: float) -> void :
	firstJumpGraceActive = true
	firstJumpGraceTimer = Keeper3GameplaySettings.OFF_FLOOR_JUMP_GRACE
	wallSlideActiveTimer += delta
	if _apply_corner_climb(delta):
		_emit_wall_slide_vfx(delta)
		return
	var target_x: float = float(wallSlideDirection) * Keeper3GameplaySettings.WALL_SLIDE_STICK_FORCE
	velocity.x = move_toward(velocity.x, target_x, Keeper3GameplaySettings.WALL_SLIDE_STICK_FORCE * delta * 5.0)
	velocity.y += Keeper3GameplaySettings.GRAVITY * delta

	var effective_input: Vector2 = _effective_move_input()
	var target_slide_speed: float = Keeper3GameplaySettings.WALL_SLIDE_SPEED
	if effective_input.y < -0.1:
		target_slide_speed = lerp(Keeper3GameplaySettings.WALL_SLIDE_SPEED, Keeper3GameplaySettings.WALL_SLIDE_SPEED_SLOW, _frame_slide_control)
	elif effective_input.y > 0.1:
		target_slide_speed = lerp(Keeper3GameplaySettings.WALL_SLIDE_SPEED, Keeper3GameplaySettings.WALL_SLIDE_SPEED_FAST, _frame_slide_control)

	if velocity.y > target_slide_speed:
		velocity.y = target_slide_speed
	var prev_floor_block_on_wall: bool = floor_block_on_wall
	floor_block_on_wall = false
	move_and_slide()
	floor_block_on_wall = prev_floor_block_on_wall
	var touching: = false
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		var normal: Vector2 = collision.get_normal()
		if wallSlideDirection < 0 and normal.x > 0.5:
			touching = true
			break
		if wallSlideDirection > 0 and normal.x < -0.5:
			touching = true
			break
	if not touching and not _is_touching_wall(wallSlideDirection, true):
		_exit_wall_slide(true)
		return
	var stopped: bool = abs(velocity.y) < 1.0
	if stopped:
		if is_instance_valid(wallSlidingSound) and wallSlidingSound.shouldPlay:
			wallSlidingSound.stop()
		if is_instance_valid(wallSlideDust):
			wallSlideDust.emitting = false
	else:
		if is_instance_valid(wallSlidingSound) and not wallSlidingSound.shouldPlay:
			wallSlidingSound.startSound()
	_update_wall_slide_animation(velocity.y)
	if not stopped:
		_emit_wall_slide_vfx(delta)


func _emit_wall_slide_vfx(delta: float) -> void :
	if not is_instance_valid(wallSlideDust) or wallSlideDirection == 0:
		return
	wallSlideDustTimer -= delta
	if wallSlideDustTimer <= 0.0:
		wallSlideDust.position.x = Keeper3SecondarySettings.WALL_SLIDE_DUST_OFFSET * float(wallSlideDirection)
		wallSlideDust.emitting = false
		wallSlideDust.restart()
		wallSlideDustTimer = Keeper3SecondarySettings.WALL_SLIDE_DUST_INTERVAL


func _update_wall_slide_animation(vertical_speed: float) -> void :
	var sprite: AnimatedSprite2D = $Visuals / Sprite2D
	if not is_instance_valid(sprite):
		return
	if wallSlideDirection == 0:
		return
	if abs(vertical_speed) < 1.0:
		sprite.pause()
		return
	var direction_suffix: String = "right" if wallSlideDirection > 0 else "left"
	var anim: String
	if vertical_speed < 0.0:
		anim = "jump_" + direction_suffix
	else:
		anim = "slide_" + direction_suffix
	if not sprite.sprite_frames.has_animation(anim):
		return
	var current: = String(sprite.animation)
	if current != anim or not sprite.is_playing():
		sprite.play(anim)
func _is_touching_wall(direction: int, force_refresh: = false) -> bool:
	return _get_wall_touch(direction, force_refresh)

func _get_wall_touch(direction: int, force_refresh: = false) -> bool:
	if direction == 0:
		return false
	if force_refresh or _wall_touch_cache_frame != _physics_frame_id:
		_wall_touch_cache_frame = _physics_frame_id
		_wall_touch_cache[-1] = _query_wall_touch(-1, force_refresh)
		_wall_touch_cache[1] = _query_wall_touch(1, force_refresh)
	return _wall_touch_cache.get(direction, false)

func _query_wall_touch(direction: int, force_refresh: = false) -> bool:
	var motion: = Vector2(float(direction) * 1.5, 0.0)
	var collision: = move_and_collide(motion, true)
	if collision:
		var normal: Vector2 = collision.get_normal()
		if abs(normal.y) > 0.3:
			return false
		if direction < 0:
			return normal.x > 0.1
		return normal.x < -0.1
	var ray: RayCast2D = rayCastLeft
	if direction >= 0:
		ray = rayCastRight
	if is_instance_valid(ray):
		if force_refresh:
			ray.force_raycast_update()
		if ray.is_colliding():
			var normal: Vector2 = ray.get_collision_normal()
			if abs(normal.y) > 0.3:
				return false
			if direction < 0:
				return normal.x > 0.1
			return normal.x < -0.1
	return false


func _is_at_wall_corner(direction: int) -> bool:
	if direction == 0:
		return false
	if not _is_touching_wall(direction):
		return false
	var corner_distance: float = Keeper3GameplaySettings.WALL_SLIDE_CORNER_CLIMB_DISTANCE
	var motion: Vector2 = Vector2(float(direction) * 1.5, 0.0)
	var elevated_transform: Transform2D = global_transform.translated(Vector2(0.0, - corner_distance))
	var touching_above: bool = test_move(elevated_transform, motion)
	return not touching_above


func _apply_corner_climb(delta: float) -> bool:
	if wallSlideDirection == 0:
		cornerClimbActive = false
		return false

	var effective_input: Vector2 = _effective_move_input()
	var input_dir: int = 0
	if abs(effective_input.x) > Keeper3GameplaySettings.AIR_INPUT_DEADZONE:
		input_dir = 1 if effective_input.x > 0.0 else -1

	if input_dir != wallSlideDirection:
		cornerClimbActive = false
		return false

	if not _is_at_wall_corner(wallSlideDirection):
		cornerClimbActive = false
		return false

	if not cornerClimbActive:
		if velocity.y < 0.0:
			return false
		if wallSlideActiveTimer < Keeper3GameplaySettings.WALL_SLIDE_CORNER_CLIMB_DELAY:
			_apply_corner_climb_animation()
			if is_instance_valid(wallSlidingSound) and wallSlidingSound.shouldPlay:
				wallSlidingSound.stop()
			velocity.y = 0.0
			velocity.x = float(wallSlideDirection) * Keeper3GameplaySettings.WALL_SLIDE_STICK_FORCE
			move_and_slide()
			return true
		cornerClimbActive = true

	_apply_corner_climb_animation()
	velocity.y = - Keeper3GameplaySettings.WALL_SLIDE_CORNER_CLIMB_SPEED
	velocity.x = float(wallSlideDirection) * Keeper3GameplaySettings.WALL_SLIDE_STICK_FORCE
	move_and_slide()

	if not _is_touching_wall(wallSlideDirection, true):
		_exit_wall_slide(true)
		return true

	return true


func _apply_corner_climb_animation() -> void :
	var sprite: AnimatedSprite2D = $Visuals / Sprite2D
	if not is_instance_valid(sprite):
		return
	_apply_facing_hint(float(wallSlideDirection))
	var suffix: String = animationSuffix
	var facing_suffix: String = ("right" if lastFacingRight else "left") + suffix
	var anim: String = "jump_up_" + facing_suffix
	if not sprite.sprite_frames.has_animation(anim):
		anim = "fall_" + facing_suffix
		if not sprite.sprite_frames.has_animation(anim):
			return
	if sprite.animation != anim:
		sprite.play(anim)


func _predict_wall_jump_direction() -> int:
	if _is_grounded():
		return 0
	if isPropelling or chainActive:
		return 0
	var candidates: Array = []
	var input_dir: = 0
	var effective_move: = _effective_move_input()
	if abs(effective_move.x) > Keeper3GameplaySettings.AIR_INPUT_DEADZONE:
		input_dir = 1 if effective_move.x > 0.0 else -1
		candidates.append(input_dir)
	if wallSlideDirection != 0:
		candidates.append(wallSlideDirection)
	var horizontal_dir: = 0
	if abs(velocity.x) > Keeper3GameplaySettings.AIR_INPUT_DEADZONE:
		horizontal_dir = 1 if velocity.x > 0.0 else -1
		candidates.append(horizontal_dir)
	var unique_candidates: = []
	for candidate in candidates:
		if candidate != 0 and candidate not in unique_candidates:
			unique_candidates.append(candidate)
	if -1 not in unique_candidates:
		unique_candidates.append(-1)
	if 1 not in unique_candidates:
		unique_candidates.append(1)
	for candidate in unique_candidates:
		if _is_touching_wall(candidate):
			return candidate
	return 0


func _perform_wall_jump(surface_direction: int = 0) -> void :
	var launch_source: int = surface_direction
	if launch_source == 0:
		launch_source = wallSlideDirection
	var launch_direction: int = - launch_source
	if launch_direction == 0:
		launch_direction = 1 if lastFacingRight else -1
	if wallSlideActive:
		_exit_wall_slide(false)
	else:
		wallSlideBlockTimer = Keeper3GameplaySettings.WALL_SLIDE_BLOCK_TIME
	var angle_rad: float = deg_to_rad(Keeper3GameplaySettings.WALL_JUMP_LAUNCH_ANGLE_DEGREES)
	var horizontal: float = cos(angle_rad) * float(launch_direction)
	var vertical: float = - sin(angle_rad)
	var launch_velocity: Vector2 = Vector2(horizontal, vertical) * Keeper3GameplaySettings.WALL_JUMP_LAUNCH_SPEED
	velocity = launch_velocity
	airReleaseDecelActive = false
	airOppositeInputActive = false
	airIgnoreInputUntilRelease = false
	lastAirHadInput = false
	jumpCount = 1
	currentJumpProfileIndex = 0
	jumpAscending = true
	jumpHoldTimer = 0.0
	firstJumpGraceActive = false
	firstJumpGraceTimer = 0.0
	inheritedPropelMomentumTimer = 0.0
	inheritedPropelHorizontalSpeed = 0.0
	wasGrounded = false
	_apply_facing_hint(float(launch_direction))
	var profile: = _current_jump_profile()
	_apply_jump_feedback(profile, true, launch_direction)
	_apply_jump_animation()

	wallJumpInputLockTimer = Keeper3GameplaySettings.WALL_JUMP_INPUT_LOCKOUT


func _attempt_jump(detachedPropel: bool = false) -> bool:
	var wall_jump_direction: = 0
	if wallSlideActive:
		wall_jump_direction = wallSlideDirection
	elif justPressedUp:
		wall_jump_direction = _predict_wall_jump_direction()
	if wall_jump_direction != 0:
		if not justPressedUp:
			return false
		_perform_wall_jump(wall_jump_direction)
		justPressedUp = false
		return true

	if not justPressedUp:
		return false
	if jumpCount >= _frame_max_jumps:
		justPressedUp = false
		return false

	var on_floor: = _is_grounded()
	var can_jump: = false
	if jumpCount == 0:
		var treated_grounded: = on_floor or firstJumpGraceActive or chainHangJumpReady
		can_jump = treated_grounded
	elif jumpCount >= 1:
		can_jump = not on_floor

	if not can_jump:
		justPressedUp = false
		return false

	var preserved_horizontal: = 0.0
	if detachedPropel:
		preserved_horizontal = velocity.x
		isPropelling = false
		wasOnRope = false

	_start_jump()
	if detachedPropel:
		velocity.x = preserved_horizontal
		inheritedPropelHorizontalSpeed = preserved_horizontal
		inheritedPropelMomentumTimer = Keeper3GameplaySettings.PROPEL_MOMENTUM_HOLD_DURATION

	justPressedUp = false
	return true

func _start_jump() -> void :
	_clear_landing_anticipation()
	var profile_index: int = int(min(jumpCount, Keeper3GameplaySettings.JUMP_PROFILES.size() - 1))
	currentJumpProfileIndex = profile_index
	var profile: = _current_jump_profile()
	var impulse: float = float(profile.get("impulse", 0.0))
	jumpCount = int(min(jumpCount + 1, _frame_max_jumps))
	if jumpCount > 1:

		impulse *= 1.0 + _frame_jump_amplification * jumpCount
	jumpAscending = true
	jumpHoldTimer = 0.0
	if jumpCount >= 1:
		firstJumpGraceActive = false
		firstJumpGraceTimer = 0.0
	chainHangJumpReady = false
	wasGrounded = false
	wasOnRope = false
	velocity.y = - abs(impulse)
	$Visuals / Sprite2D.rotation = 0
	_apply_jump_feedback(profile)
	_apply_jump_animation()

func _apply_jump_feedback(profile: Dictionary, is_wall_jump: bool = false, wall_launch_direction: int = 0) -> void :
	var sfx_boost: float = float(profile.get("sfx_boost_db", 0.0))
	if is_wall_jump:
		if is_instance_valid(wallJumpSound):
			if wallJumpSound.shouldPlay:
				wallJumpSound.stop(true)
			wallJumpSound.volume_db = _wallJumpSoundBaseDb + sfx_boost
			wallJumpSound.startSound()
	else:
		var jump_sound
		if jumpCount >= 4:
			jump_sound = $QuadrupleJumpSound
		elif jumpCount == 3:
			jump_sound = $TriplejumpSound
		elif jumpCount == 2:
			jump_sound = $DoublejumpSound
		else:
			jump_sound = $Jumpsound
		if is_instance_valid(jump_sound):
			if jump_sound.shouldPlay:
				jump_sound.stop(true)
			jump_sound.volume_db = _jumpSoundBaseDb + sfx_boost
			jump_sound.startSound()
	if _specialKunaiIsReady:
		$MoveShurikenSound.startSound()
		_moveShurikenSoundGrace = 0.2
	var multiplier: float = float(max(profile.get("vfx_multiplier", 1.0), 0.1))
	var target_amount: int = int(round(_jumpVfxBaseAmount * multiplier))
	var speed_multiplier: float = float(max(multiplier, 1.0))
	if is_wall_jump:
		var launch_sign: = int(sign(float(wall_launch_direction)))
		_spawn_wall_jump_dust(launch_sign, target_amount, speed_multiplier)
	else:
		_play_step_dust(target_amount, speed_multiplier)
	var shake_strength: float = float(profile.get("shake_strength", 0.0))
	if shake_strength > 0.0:
		var duration: float = float(profile.get("shake_duration", 0.0))
		var frequency: float = float(profile.get("shake_frequency", 0.0))
		var input_system: = get_tree().root.get_node_or_null("/root/InputSystem")
		if input_system:
			input_system.shake(shake_strength, duration, frequency, global_position)

func _play_step_dust(target_amount: int, speed_multiplier: float) -> void :
	var dust: GPUParticles2D = $StepDust
	if not is_instance_valid(dust):
		return
	dust.amount = int(max(target_amount, 1))
	dust.speed_scale = _jumpVfxBaseSpeedScale * speed_multiplier
	dust.restart()
	dust.call_deferred("set", "amount", _jumpVfxBaseAmount)
	dust.call_deferred("set", "speed_scale", _jumpVfxBaseSpeedScale)

func _spawn_wall_jump_dust(launch_direction: int, target_amount: int, speed_multiplier: float) -> void :
	if launch_direction == 0:
		return
	var template: GPUParticles2D = $WallJumpDust
	if not is_instance_valid(template):
		return
	var clone: = template.duplicate(true)
	if clone == null:
		return
	clone.name = "WallJumpDustInstance"
	clone.emitting = false
	clone.one_shot = true
	clone.scale.x = float(launch_direction)
	clone.lifetime = template.lifetime
	clone.amount = int(max(target_amount, 1))
	clone.speed_scale = _jumpVfxBaseSpeedScale * speed_multiplier
	var parent: = get_parent()
	if parent == null:
		parent = self
	parent.add_child(clone)
	clone.global_position = _resolve_wall_jump_dust_position(launch_direction)
	clone.z_index = z_index
	clone.restart()
	var cleanup_timer: = Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = clone.lifetime + 0.2
	clone.add_child(cleanup_timer)
	cleanup_timer.timeout.connect( func():
		clone.queue_free()
	)
	cleanup_timer.start()

func _resolve_wall_jump_dust_position(launch_direction: int) -> Vector2:
	var direction_sign: = int(sign(float(launch_direction)))
	if direction_sign == 0:
		return global_position
	var wall_direction: = - direction_sign
	var ray: = rayCastLeft if wall_direction < 0 else rayCastRight
	var vertical_offset: = Keeper3SecondarySettings.WALL_JUMP_DUST_VERTICAL_OFFSET
	var forward_offset: = Keeper3SecondarySettings.WALL_JUMP_DUST_FORWARD_OFFSET
	var spawn_point: = global_position + Vector2(float(direction_sign) * forward_offset, vertical_offset)
	if is_instance_valid(ray):
		ray.force_raycast_update()
		if ray.is_colliding():
			var collision_point: Vector2 = ray.get_collision_point()
			var normal: Vector2 = ray.get_collision_normal()
			spawn_point = collision_point + normal * Keeper3SecondarySettings.WALL_JUMP_DUST_COLLISION_PUSH
			spawn_point.y += vertical_offset
	return spawn_point

func _apply_jump_animation() -> void :
	var sprite: AnimatedSprite2D = $Visuals / Sprite2D
	if not is_instance_valid(sprite):
		return
	_apply_air_facing_hint(velocity.x, _effective_move_input().x)
	var facing_suffix: String = ("right" if lastFacingRight else "left") + animationSuffix
	var prefix: String = "roll_" if jumpCount >= 2 else "jump_"
	var animation: String = prefix + facing_suffix
	if sprite.animation != animation:
		sprite.play(animation)
		sprite.set_frame_and_progress(0, 0)

func _on_sprite_animation_changed() -> void :
	var anim: = String($Visuals / Sprite2D.animation)
	if anim.begins_with("roll_"):
		if not $SpinSound.playing:
			$SpinSound.startSound()
	else:
		$SpinSound.stop(true)

func _current_jump_profile() -> Dictionary:
	if Keeper3GameplaySettings.JUMP_PROFILES.is_empty():
		return {}
	var index: int = currentJumpProfileIndex
	if index < 0:
		index = 0
	index = int(clamp(index, 0, Keeper3GameplaySettings.JUMP_PROFILES.size() - 1))
	return Keeper3GameplaySettings.JUMP_PROFILES[index]

func _should_continue_jump_hold(profile: Dictionary) -> bool:
	if not jumpAscending:
		return false
	var min_hold: float = float(profile.get("min_hold", 0.0))
	var max_hold: float = float(profile.get("max_hold", min_hold))
	if jumpHoldTimer < min_hold:
		return true
	if jumpHoldTimer >= max_hold:
		return false
	return pressingUp

func _update_jump_animation_direction() -> void :
	var sprite: AnimatedSprite2D = $Visuals / Sprite2D
	if not is_instance_valid(sprite):
		return
	var animation: String = sprite.animation
	if not animation.begins_with("jump_"):
		return
	_apply_air_facing_hint(velocity.x, _effective_move_input().x)
	var desired: String = "jump_" + ("right" if lastFacingRight else "left") + animationSuffix
	if animation == desired:
		return
	var frame: int = sprite.get_frame()
	var progress: float = sprite.get_frame_progress()
	sprite.play(desired)
	sprite.set_frame_and_progress(frame, progress)

func land():
	$Landsound.startSound()
	$StepDust.restart()
	if _specialKunaiIsReady:
		$MoveShurikenSound.startSound()
		_moveShurikenSoundGrace = 0.2
	var sprite: AnimatedSprite2D = $Visuals / Sprite2D
	var horizontal_velocity: float = velocity.x
	if lastFallAnimation == StringName("fall_left"):
		_apply_facing_hint(-1.0)
	elif lastFallAnimation == StringName("fall_right"):
		_apply_facing_hint(1.0)
	else:
		_apply_facing_hint(horizontal_velocity)
	var use_roll_landing: = pendingRollLanding
	pendingRollLanding = false
	var anticipated_animation: = landingAnticipationAnimation
	var resolved_animation: StringName = _resolve_landing_animation(use_roll_landing, horizontal_velocity)
	var fall_animation_hint: StringName = lastFallAnimation
	_clear_landing_anticipation()
	lastFallAnimation = StringName("")
	if is_instance_valid(sprite) and resolved_animation != StringName(""):
		var already_playing: = sprite.animation == resolved_animation and sprite.is_playing()
		if already_playing and anticipated_animation == resolved_animation:
			return
		sprite.play(resolved_animation)
		return

	if use_roll_landing and is_instance_valid(sprite):
		var roll_anim: = "landing_from_roll_" + ("right" if lastFacingRight else "left") + animationSuffix
		if sprite.sprite_frames.has_animation(roll_anim):
			sprite.play(roll_anim)
			return
	if not is_instance_valid(sprite):
		return
	var base_anim: = "land_front"
	if fall_animation_hint == StringName("fall_left"):
		base_anim = "land_left"
	elif fall_animation_hint == StringName("fall_right"):
		base_anim = "land_right"
	elif abs(horizontal_velocity) >= Keeper3GameplaySettings.ANIMATION_HORIZONTAL_SPEED_DEADZONE:
		base_anim = "land_right" if horizontal_velocity > 0.0 else "land_left"
	sprite.play(base_anim + animationSuffix)

func groundAnimation():
	var sprite: AnimatedSprite2D = $Visuals / Sprite2D
	if not is_instance_valid(sprite):
		return

	var drillBuff: float = _frame_drill_buff
	sprite.speed_scale = 2.0 if drillBuff > 0 else 1.0

	if sprite.is_playing():
		var current_animation: = String(sprite.animation)
		var is_throw_animation: = (
			current_animation.begins_with("throw_kunai_")
			or current_animation.begins_with("throw_shuriken_")
			or current_animation.begins_with("shoot_hanging_")
		)
		if is_throw_animation:
			return

	var combinedMove = _effective_move_input()
	if move.length() > 0.15:
		combinedMove += move
	if abs(combinedMove.x) < 0.1:
		var current_animation: = String(sprite.animation)
		var playing_landing: bool = sprite.is_playing()
		if playing_landing:
			playing_landing = current_animation.begins_with("land_") or current_animation.begins_with("landing_from_roll")
		if playing_landing:
			return

		_apply_facing_hint(combinedMove.x)
		sprite.play("idle" + animationSuffix)
	else:
		if abs(combinedMove.x):
			_apply_facing_hint(combinedMove.x)
			sprite.play("run_left" + animationSuffix if combinedMove.x < 0 else "run_right" + animationSuffix)

func airAnimation():
	var sprite: AnimatedSprite2D = $Visuals / Sprite2D
	if not is_instance_valid(sprite):
		return

	var drillBuff: float = _frame_drill_buff
	sprite.speed_scale = 2.0 if drillBuff > 0 else 1.0

	if landingAnticipationActive:
		return
	if sprite.is_playing():
		var current_animation: = String(sprite.animation)
		var is_throw_animation: = (
			current_animation.begins_with("throw_kunai_")
			or current_animation.begins_with("throw_shuriken_")
			or current_animation.begins_with("shoot_hanging_")
		)
		if is_throw_animation:
			return
	if wallSlideActive:
		return

	var playing_initial_jump: bool = (
		sprite.animation.begins_with("jump_")
		and not sprite.animation.begins_with("jump_up_")
		and sprite.is_playing()
	)

	var suffix: String = animationSuffix
	var horizontal_speed: float = abs(velocity.x)
	var move_hint: Vector2 = _effective_move_input()
	if horizontal_speed >= Keeper3GameplaySettings.AIR_ROLL_SPEED_THRESHOLD and not playing_initial_jump:
		_apply_air_facing_hint(velocity.x, move_hint.x)
		var roll_animation: String = ("roll_right" if lastFacingRight else "roll_left") + suffix
		if sprite.animation != roll_animation:
			sprite.play(roll_animation)
		lastFallAnimation = StringName("")
		return

	var rising: bool = jumpAscending or velocity.y < 0.0
	if rising:
		lastFallAnimation = StringName("")
		if playing_initial_jump:
			_update_jump_animation_direction()
		return

	var is_fast_falling: bool = velocity.y > 0.0 and move_hint.y > 0.1 and _frame_air_control > 0
	var fall_suffix: String = "_fast" if is_fast_falling else suffix

	if horizontal_speed < Keeper3GameplaySettings.ANIMATION_HORIZONTAL_SPEED_DEADZONE:
		var fall_front: String = "fall_front" + fall_suffix
		if sprite.animation != fall_front:
			sprite.play(fall_front)
		lastFallAnimation = StringName("fall_front")
		return

	_apply_air_facing_hint(velocity.x, move_hint.x)
	var fall_base: String = "fall_right" if velocity.x > 0.0 else "fall_left"
	var fall_animation: String = fall_base + fall_suffix
	if sprite.animation != fall_animation:
		sprite.play(fall_animation)
	lastFallAnimation = StringName(fall_base)


func checkKeeperStep(delta):
	if abs(_effective_move_input().x) < 0.1:
		resetStepTimer()
		return

	stepTimer -= delta

	if stepTimer <= 0:
		doKeeperStep()
		stepTimer = Keeper3GameplaySettings.STEP_INTERVAL

func resetStepTimer():
	stepTimer = 0

func doKeeperStep():
	$Stepsound.startSound()
	$StepDust.restart()
	if _specialKunaiIsReady:
		$MoveShurikenSound.startSound()

func applyFallPhysics(delta: float, gravity_strength: float = Keeper3GameplaySettings.GRAVITY, jump_modifier: float = 0.45, apply_air_control: = true) -> void :
	var gravityDelta: float


	if velocity.y < 0:
		gravityDelta = gravity_strength * delta
		if pressingUp:
			gravityDelta *= jump_modifier
	else:
		gravityDelta = gravity_strength * 1.5 * delta

	velocity.y += gravityDelta

	if apply_air_control:
		_apply_horizontal_air_input(delta)

	velocity.y = clamp(velocity.y, - Keeper3GameplaySettings.MAX_FALL_SPEED, Keeper3GameplaySettings.MAX_FALL_SPEED)
	velocity.x = clamp(velocity.x, - Keeper3GameplaySettings.MAX_SPEED, Keeper3GameplaySettings.MAX_SPEED)

func _apply_horizontal_air_input(delta: float) -> void :
	var raw_input: float = _effective_move_input().x
	var has_input: bool = abs(raw_input) > Keeper3GameplaySettings.AIR_INPUT_DEADZONE
	var processed_input: float = raw_input
	var on_floor: bool = _is_grounded()

	if on_floor:
		airOppositeInputActive = false
		airIgnoreInputUntilRelease = false
		airReleaseDecelActive = false
		lastAirHadInput = false

	var input_direction: float = sign(raw_input) if has_input else 0.0
	var velocity_direction: float = sign(velocity.x) if abs(velocity.x) > 0.01 else 0.0
	var is_opposite_input: bool = has_input and velocity_direction != 0.0 and input_direction != velocity_direction
	var target_speed: float = 0.0

	if has_input:
		var speedBuff: int = int(_frame_speed_buff)
		var buffedMoveSpeed: float = Keeper3GameplaySettings.MOVE_SPEED + (float(speedBuff) * 105.0)
		var speed_multiplier: float = input_direction if on_floor else processed_input
		target_speed = speed_multiplier * buffedMoveSpeed * delta
		if not on_floor:
			target_speed *= 0.85

	if has_input and not on_floor:
		var input_held: bool = input_direction != 0.0 and input_direction == lastAirInputDirection
		var velocity_inverted: bool = lastAirVelocityDirection != 0.0 and lastAirVelocityDirection == input_direction\
		and velocity_direction != 0.0 and velocity_direction != input_direction
		if input_held and velocity_inverted:
			airIgnoreInputUntilRelease = true
			airOppositeInputActive = true
		if has_input:
			airReleaseDecelActive = false

	if not on_floor and lastAirHadInput and not has_input:
		airReleaseDecelActive = true

	var ignore_input: bool = airIgnoreInputUntilRelease and has_input and not on_floor
	if has_input and not on_floor and not ignore_input:
		var same_direction_input: bool = velocity_direction != 0.0 and input_direction == velocity_direction
		if same_direction_input and abs(velocity.x) >= abs(target_speed):
			ignore_input = true

	if has_input and not ignore_input:
		if not on_floor and is_opposite_input:
			airOppositeInputActive = true
		var acceleration: float = Keeper3GameplaySettings.AIR_INPUT_ACCELERATION
		var brake: float = Keeper3GameplaySettings.AIR_INPUT_BRAKE
		var current_velocity_x: float = velocity.x
		var same_direction: bool = abs(target_speed) <= 0.01
		if on_floor:
			acceleration = Keeper3GameplaySettings.GROUND_INPUT_ACCELERATION
			brake = Keeper3GameplaySettings.GROUND_INPUT_BRAKE
		if abs(current_velocity_x) > 0.01:
			same_direction = (current_velocity_x > 0.0 and target_speed >= 0.0) or (current_velocity_x < 0.0 and target_speed <= 0.0) or abs(target_speed) <= 0.01
			if not same_direction:
				var opposite_decel: = brake
				if not on_floor:
					opposite_decel = Keeper3GameplaySettings.AIR_OPPOSITE_DECEL
				velocity.x = move_toward(velocity.x, 0.0, delta * opposite_decel)
		var should_adjust_velocity: bool = true
		if should_adjust_velocity and (same_direction or abs(velocity.x) <= 0.01):
			velocity.x = move_toward(velocity.x, target_speed, delta * acceleration)
		inheritedPropelMomentumTimer = 0.0
		inheritedPropelHorizontalSpeed = 0.0
	elif on_floor:
		velocity.x = move_toward(velocity.x, 0.0, delta * Keeper3GameplaySettings.GROUND_PASSIVE_BRAKE)
	elif airReleaseDecelActive and not has_input:
		velocity.x = move_toward(velocity.x, 0.0, delta * Keeper3GameplaySettings.AIR_OPPOSITE_DECEL)

	if not has_input:
		airIgnoreInputUntilRelease = false

	if not on_floor:
		lastAirHadInput = has_input
	lastAirInputDirection = input_direction
	lastAirVelocityDirection = velocity_direction

func falling(delta):
	var profile: = _current_jump_profile()
	var on_floor: = _is_grounded()
	var gravity_scale: = 0.0
	if velocity.y < 0.0:
		if _should_continue_jump_hold(profile):
			gravity_scale = float(profile.get("hold_gravity_scale", 0.5))
		else:
			gravity_scale = float(profile.get("release_gravity_scale", 1.0))
			jumpAscending = false
	else:
		if not on_floor:
			gravity_scale = float(profile.get("fall_gravity_scale", 1.5))
		jumpAscending = false

	var gravity_acc: float = Keeper3GameplaySettings.GRAVITY * gravity_scale
	if gravity_scale != 0.0:
		velocity.y += gravity_acc * delta

	if _frame_lift_upwards_speed > 0.0 and _effective_move_input().y < -0.1:
		velocity.y = - (10.0 + 1.5 * _frame_lift_upwards_speed)
		var fly_anim: = "fly_up" + animationSuffix
		var sprite: AnimatedSprite2D = $Visuals / Sprite2D
		if is_instance_valid(sprite) and sprite.animation != fly_anim:
			sprite.play(fly_anim)
	elif velocity.y > 0.0:
		var effective_input: Vector2 = _effective_move_input()
		if effective_input.y < -0.1:

			velocity.y *= lerp(1.0, Keeper3GameplaySettings.AIR_FALL_SPEED_UP_MODIFIER, _frame_air_control)
		elif effective_input.y > 0.1:

			velocity.y *= lerp(1.0, Keeper3GameplaySettings.AIR_FALL_SPEED_DOWN_MODIFIER, _frame_air_control)
			if not _fastFallActive and _frame_air_control >= 1.0:
				_fastFallActive = true
				$DashSound.startSound()
		else:
			_fastFallActive = false
	else:
		_fastFallActive = false

	_update_jump_animation_direction()
	_apply_horizontal_air_input(delta)
	_update_landing_anticipation(pendingRollLanding, velocity.x)

	move_and_slide()
	velocity.y = clamp(velocity.y, - Keeper3GameplaySettings.MAX_FALL_SPEED, Keeper3GameplaySettings.MAX_FALL_SPEED)
	var horizontal_cap: float = Keeper3GameplaySettings.MAX_SPEED
	if inheritedPropelMomentumTimer > 0.0:
		horizontal_cap = max(horizontal_cap, abs(inheritedPropelHorizontalSpeed))
	velocity.x = clamp(velocity.x, - horizontal_cap, horizontal_cap)
	if inheritedPropelMomentumTimer > 0.0:
		inheritedPropelHorizontalSpeed = velocity.x

func _effective_move_input() -> Vector2:

	if wallJumpInputLockTimer > 0.0:
		return Vector2.ZERO
	return moveDirectionInput

func fallingFromRopeMovement(delta):

	wasGrounded = false
	applyFallPhysics(delta, Keeper3GameplaySettings.ROPE_GRAVITY, 1.0, false)

	if velocity.y < 0.1:
		var movementX = moveDirectionInput.x
		velocity.x += movementX
		velocity.x -= movementX

	$Visuals / Sprite2D.rotation += 10 * delta

	var collision = move_and_collide(velocity)

	$Visuals / Sprite2D.play("roll_left" + animationSuffix)
	_update_landing_anticipation(true, velocity.x)

	if collision:
		var normal = collision.get_normal()

		if normal.dot(Vector2(0, 1)) > 0.9 or normal.dot(Vector2(1, 1)) > 0.9 or normal.dot(Vector2(-1, 1)) > 0.9:
			velocity.y = abs(velocity.y * 0.5)
			wasOnRope = false
			$Visuals / Sprite2D.rotation = 0
			velocity = Vector2(0, 0)

		if normal.dot(Vector2(-1, 0)) > 0.9 or normal.dot(Vector2(1, 0)) > 0.9 or normal.dot(Vector2(1, 1)) > 0.9 or normal.dot(Vector2(-1, 1)) > 0.9 or normal.dot(Vector2(1, -1)) > 0.9 or normal.dot(Vector2(-1, -1)) > 0.9:
			velocity.x = 0


		if velocity.y == 0 and normal.dot(Vector2(0, -1)) > 0.9 or normal.dot(Vector2(1, -1)) > 0.9 or normal.dot(Vector2(-1, -1)) > 0.9:
			wasOnRope = false
			$Visuals / Sprite2D.rotation = 0
			velocity = Vector2(0, 0)


func updateCarry():
	var longest: = 0.0
	var previous_anchor: Node2D = null
	var c_index: = 0
	while c_index < carriedCarryables.size():
		var c = carriedCarryables[c_index]
		if is_multiplayer_authority():
			if c == null or not is_instance_valid(c):
				chainManager.detach_body(c)
				previous_anchor = null
				c_index += 1
				continue
			if c.independent:
				var size_before: = carriedCarryables.size()
				dropCarry(c)
				previous_anchor = null
				if carriedCarryables.size() < size_before:
					continue
				if c_index < carriedCarryables.size() and carriedCarryables[c_index] != c:
					continue
				c_index += 1
				continue

		var anchor_position: Vector2
		if c_index == 0 or not is_instance_valid(previous_anchor):
			anchor_position = global_position
		else:
			anchor_position = previous_anchor.global_position
		var distance: float = anchor_position.distance_to(c.global_position)
		if distance > longest:
			longest = distance
		var settle_frames: int = int(c.get_meta("pickup_settle_frames", 0))
		if settle_frames > 0:
			c.set_meta("pickup_settle_frames", settle_frames - 1)
		if multiplayer.is_server() and settle_frames == 0 and distance > Keeper3GameplaySettings.MAX_CARRY_LINE_LENGTH:
			var size_before: = carriedCarryables.size()
			dropCarry(c)
			$CarryLineBreak.startSound()
			previous_anchor = null
			if carriedCarryables.size() < size_before:
				continue
			if c_index < carriedCarryables.size() and carriedCarryables[c_index] != c:
				continue
			c_index += 1
			continue
		if c is Node2D:
			previous_anchor = c
		else:
			previous_anchor = null
		c_index += 1

	var breakThreshold = 0.7
	if longest > breakThreshold * Keeper3GameplaySettings.MAX_CARRY_LINE_LENGTH:
		if not $CarryLineStretch.playing:
			$CarryLineStretch.startSound()
		var pitch = (longest - breakThreshold * Keeper3GameplaySettings.MAX_CARRY_LINE_LENGTH) / ((1.0 - breakThreshold) * Keeper3GameplaySettings.MAX_CARRY_LINE_LENGTH)
		$CarryLineStretch.pitch_scale = 1 + ease(pitch, 0.6)
	else:
		if _hanging_effective_climb <= 0:
			$CarryLineStretch.stop()

func restoreConverterGravity(body) -> void :
	if body.carryableType != "resource":
		return
	for p in body.physicsOverrides:
		if p.creator == body:
			p.gravity_scale = 1.0
			p.linear_damp = 1.0
	body.removePhysicsOverride(Level.drops.synchronizer)

func _dropCarryInternal(body):
	if body == null or not is_instance_valid(body):
		_carrierDetachBody(body)
		return

	if not carriedCarryables.has(body):
		var carryableName: String = String(body.name)
		Logger.error("keeper wants to drop carryable that isn't carried", "Keeper.dropCarry", {"carryable": carryableName, "carry": str(carriedCarryables)})
		return

	$Drop.startSound()

	var brk = Data.CARRYLINE_BREAK.instantiate()
	brk.global_position = global_position
	brk.target = body.global_position
	get_parent().add_child(brk)

	_carrierDetachBody(body)
	restoreConverterGravity(body)

	if chainManager.carryChains.size() == 0:
		$CarryLine.stop()


func _carrierDetachBody(body) -> void :
	chainManager.detach_body(body)


func enterCarrierPickupArea(carrier: KunaiCarrier) -> bool:
	pruneCarrierPickupOverlaps()
	if _carrier_pickup_overlaps.has(carrier):
		return false

	var is_first_overlap: = _carrier_pickup_overlaps.is_empty()
	_carrier_pickup_overlaps.append(carrier)
	return is_first_overlap

func exitCarrierPickupArea(carrier: KunaiCarrier) -> void :
	_carrier_pickup_overlaps.erase(carrier)
	pruneCarrierPickupOverlaps()

func pruneCarrierPickupOverlaps() -> void :
	var index: = _carrier_pickup_overlaps.size() - 1
	while index >= 0:
		var carrier: KunaiCarrier = _carrier_pickup_overlaps[index]
		if not is_instance_valid(carrier) or carrier.is_queued_for_deletion():
			_carrier_pickup_overlaps.remove_at(index)
		index -= 1

func automaticPickup():
	if not is_multiplayer_authority():
		return

	if isInsideStation or disabled or loadoutClimbingMode:
		return

	if pressingThrow:
		return

	if carriedCarryables.size() >= _frame_carry_limit:
		return

	if Time.get_ticks_msec() / 1000.0 < float(disable_auto_pickup_until):
		return

	var max_distance_sq: = Keeper3GameplaySettings.AUTO_CARRYABLE_PICKUP_RADIUS * Keeper3GameplaySettings.AUTO_CARRYABLE_PICKUP_RADIUS

	for carryable in carryables:
		if not is_instance_valid(carryable):
			continue

		if carriedCarryables == null:
			continue

		if carryable == null:
			continue

		if carryable is KunaiCarrier:
			continue

		if carryable.has_method("isCarried") and carryable.isCarried() and not carryable.isCarriedBy(self):
			continue

		if carryable.hasCarryInfluence() and (carryable.linear_velocity.length_squared() > 300 or velocity.length_squared() > 2500):
			return

		if carryable.has_meta("kunai_carrier") and carryable.get_meta("kunai_carrier") != null:
			continue

		if carryable.global_position.distance_squared_to(global_position) > max_distance_sq:
			continue

		if not carriedCarryables.has(carryable)\
		and carryable.canFocusCarry(teamId)\
		and carryable.carryableType == "resource"\
		and (pickupType == "" or pickupType == carryable.carryableType)\
		and ( not carryable.is_in_group("usables") or usables.has(carryable.get_meta("usable"))):
			attachCarry(carryable)

func attachCarry(body) -> void :
	if body.get_meta("pickup_pending", false):
		return
	body.set_meta("pickup_pending", true)
	Level.drops.network_pickup(body, playerId)

func is_power_carryable(carryable: Carryable) -> bool:
	return carryable is Drop and carryable.type in ["powercore", "relic", "gadget"]

func _attachCarryInternal(body):
	if body == null or not is_instance_valid(body):
		return
	body.remove_meta("pickup_pending")
	if carriedCarryables.has(body):
		return
	if body.has_meta("kunai_carrier") and body.get_meta("kunai_carrier") != null and body.get_meta("kunai_carrier") != self:
		return
	body.unfocusCarry(self)
	body.dissolveCarryInfluence()
	var po = CarryablePhysicsOverride.new(self)
	po.angular_damp = 2
	po.gravity_scale = Keeper3SecondarySettings.CARRY_CARRIED_GRAVITY_SCALE
	body.addPhysicsOverride(po)
	if is_power_carryable(body):
		carriedCarryables.insert(0, body)
	else:
		var power_items = carriedCarryables.filter(is_power_carryable)
		carriedCarryables.insert(power_items.size(), body)
	body.setCarriedBy(self)
	for c in carriedCarryables:
		c.set_meta("pickup_settle_frames", 30)
		c.set_meta("pickup_chain_arrived", false)
	$Pickup.startSound()

	chainManager.setup_carryable(body)

	while _frame_carry_limit > 0 and carriedCarryables.size() > _frame_carry_limit:
		dropCarry(carriedCarryables[0])

func isAtCarryLimit() -> bool:
	return _frame_carry_limit > 0 and carriedCarryables.size() >= _frame_carry_limit

func hasBlockedNearbyCarryable() -> bool:
	return isAtCarryLimit() and is_instance_valid(focussedCarryable)\
	and not carriedCarryables.any( func(c): return c.type == focussedCarryable.type)

@rpc("reliable", "any_peer")
func handleThrowAnim(aimDirection: Vector2, is_special: bool = false, allow_shoot_hanging: bool = true) -> void :
	var right: = aimDirection.x > 0
	var anim: String
	if allow_shoot_hanging and chainHanging:
		anim = ("shoot_hanging_" + ("right" if right else "left")) + animationSuffix
	else:
		var base: = "throw_shuriken_" if is_special else "throw_kunai_"
		anim = (base + ("right" if right else "left")) + animationSuffix
	$Visuals / Sprite2D.play(anim)
	$Visuals / Sprite2D.set_frame_and_progress(0, 0)

	var drillBuff: float = _frame_drill_buff
	if drillBuff > 0:
		$Visuals / Sprite2D.speed_scale = 2.0
	else:
		$Visuals / Sprite2D.speed_scale = 1.0

	if is_special:
		$ThrowShuriken.startSound()
	else:
		$ThrowBomb.startSound()
		if _frame_kunai_cooldown_level > 0:
			match _frame_kunai_cooldown_level:
				1: $FastThrowSound.volume_db = -10.0
				2: $FastThrowSound.volume_db = -6.0
				3: $FastThrowSound.volume_db = 0.0
			$FastThrowSound.startSound()

func currentSpeed():
	return 200

func _update_trajectory_prediction() -> void :
	if not is_instance_valid(trajectoryPredictor):
		return

	if not _frame_bounce_preview:
		trajectoryPredictor.visible = false
		return

	var can_show: = _can_show_trajectory()
	trajectoryPredictor.visible = can_show

	if can_show:
		var aim: Vector2 = getAimDirection("aim1_snap")
		if aim.length() > 0:
			trajectoryPredictor.update_prediction(
				global_position, 
				aim.normalized(), 
				kunaiSpeed, 
				2097673
			)

func _can_show_trajectory() -> bool:
	if isInsideDome:
		return false
	if isInsideStation:
		return false
	if isPropelling:
		return false
	if chainActive:
		return false
	if not cooldownManager.is_ready("kunai") and not pressingThrow:
		return false
	if getAimDirection("aim1_snap").length() <= 0:
		return false
	return true


func getAimDirection(aim_id = "") -> Vector2:
	if showcaseMode:
		return moveDirectionInput
	if Options.useGamepad(deviceId):
		return _calcGamepadDirection(aim_id, input_settings)
	else:
		return _calcMouseDirection(aim_id, input_settings)


func throwKunai(charged) -> void :
	var aimDirection = getAimDirection("aim1_snap")
	if aimDirection.length() == 0:
		aimDirection = moveDirectionInput.normalized()
	if aimDirection == Vector2.ZERO:
		return

	var isTargettingTile = not Options.useGamepad(deviceId)
	var tileCoord: Vector2
	if isTargettingTile:
		var mouseWorldPos: Vector2 = get_global_mouse_position()
		tileCoord = Vector2(Level.map.getTileCoord(mouseWorldPos))
	$KunaithrowVfx.flip_v = !$KunaithrowVfx.flip_v
	$KunaithrowVfx.rotation = aimDirection.angle()
	$KunaithrowVfx.play("kunaithrow")
	synchronizer.network_rpc(networkThrowKunai.bind(charged, aimDirection, self.position, isTargettingTile, tileCoord), true)

@rpc("reliable", "any_peer")
func networkThrowKunai(charged: bool, aimDirection: Vector2, startPosition: Vector2, isTargettingTile: bool, targetTileCoords: Vector2) -> void :
	handleThrowAnim(aimDirection, charged)

	var kunai: = preload("res://content/keeper/keeper3/Kunai.tscn").instantiate()
	kunai.charged = charged
	kunai.damage = Data.of(playerId + ".keeper3.kunaidamage")
	kunai.position = startPosition
	if charged:
		kunai.radius = Data.of(playerId + ".keeper3.shurikenstrength")
		kunai.alwayRemoveSides = true
	Style.init(kunai)
	Level.map.addDrop(kunai)

	if charged:
		aimDirection *= kunaiSpeed * 0.5
	else:
		aimDirection *= kunaiSpeed

	kunai.apply_central_impulse(aimDirection)
	kunai.playerId = playerId
	kunai.teamId = teamId
	kunai.has_damage_upgrade = GameWorld.boughtUpgrades.has(playerId + ".keeper3kunaidamage4")
	kunai.has_fast_throw = _frame_kunai_cooldown_level > 0
	var sl: = 1
	if GameWorld.boughtUpgrades.has(playerId + ".keeper3shurikenstrength2"):
		sl = 3
	elif GameWorld.boughtUpgrades.has(playerId + ".keeper3shurikenstrength1"):
		sl = 2
	kunai.shuriken_level = sl
	kunai.set_multiplayer_authority(peerId)

	if isTargettingTile:
		var tile: Node = Level.map.getTile(targetTileCoords)
		if tile != null and Data.isDestructable(tile):
			kunai.targetTile = tile

	if charged:
		var special_cooldown: float = float(Data.ofOr(playerId + ".keeper3.shurikencooldown", SPECIAL_KUNAI_BASE_COOLDOWN))
		var drillbuff_multiplier: float = 1.0 - _frame_drill_buff
		if drillbuff_multiplier < 1.0:
			special_cooldown = max(special_cooldown * drillbuff_multiplier, 0.017)
		cooldownManager.set_cooldown("kunai_special", special_cooldown)
		_start_special_kunai_cooldown(special_cooldown)
		emit_signal("mined", 0.5)
	else:
		var kunai_cooldown: float = Data.of(playerId + ".keeper3.kunaicooldown")
		var drillbuff_multiplier: float = 1.0 - _frame_drill_buff
		if drillbuff_multiplier < 1.0:
			kunai_cooldown = max(kunai_cooldown * drillbuff_multiplier, kunai_cooldown * Keeper3GameplaySettings.KUNAI_COOLDOWN_MIN_MULTIPLIER)
		cooldownManager.set_cooldown("kunai", kunai_cooldown)
		emit_signal("mined", 1.0)

func deployKunaiCarrier(resources_only: bool = false):
	synchronizer.network_rpc(handleThrowAnim.bind(getAimDirection("aim2_snap")), true)
	var startPosition: = self.position

	var aim_dir = getAimDirection("aim2_snap")
	if aim_dir.length() == 0:
		aim_dir = moveDirectionInput
	if Data.of(playerId + ".keeper3.rocketcarrier"):
		aim_dir = Data.snapVectorToDirections(aim_dir, deg_to_rad(input_settings.aim2_snap * 0.5))
	if aim_dir.length() == 0:
		var facing_x: = 1.0 if lastFacingRight else -1.0
		aim_dir = Vector2(facing_x, -1.0).normalized()

	Level.drops.network_kunai_carrier(_build_carrier_group(resources_only), aim_dir, startPosition, playerId)
	pickupType = ""
	kunaiCarrierDeployCount += 1

func _auto_deploy_carrier_on_dome_entry() -> void :
	var group: = _build_carrier_group()
	if group.is_empty():
		return
	var aim_dir: = Vector2(0, -1)
	if Level.domesByTeamId.has(teamId):
		var dome = Level.domesByTeamId[teamId]
		var shredder = dome.get_node_or_null("Shredder")
		if is_instance_valid(shredder):
			aim_dir = (shredder.global_position - global_position).normalized()
	Level.drops.network_kunai_carrier(group, aim_dir, position, playerId)

func _build_carrier_group(resources_only: bool = false) -> Array[Carryable]:
	var group: Array[Carryable] = []
	for carryable in carriedCarryables:
		if carryable.get_collision_mask_value(CONST.LAYER_DOME_EXTERNAL):
			continue
		if resources_only and carryable.carryableType != "resource":
			continue
		if carryable is RigidBody2D:
			carryable.linear_velocity = Vector2.ZERO
			carryable.angular_velocity = 0.0
		group.append(carryable)
	return group

func checkGenCanThrow() -> bool:
	return !isInsideDome and !loadoutClimbingMode and !drillClimbActive

func onThrowPressed():
	$FirstClick.startSound()

func handleThrowInput():
	if !isPropelling:
		var current_time: = Time.get_ticks_msec() / 1000.0
		if current_time - last_throw_click_time <= double_click_threshold:
			was_double_click = true
			single_click_timer.stop()
			handleKunai(true, false, true)
		else:
			was_double_click = false
			single_click_timer.start()
			autoShoot = true
			last_throw_click_time = current_time

func _on_single_click_confirmed():
	if GameWorld.paused:
		return
	if was_double_click:
		return

	handleKunai(false)


func handleKunai(charged: bool, allowSpecial: bool = true, allowCarrier: bool = true) -> bool:
	if charged:
		if !carriedCarryables.is_empty():
			var found_gadget: Node = null
			for body in carriedCarryables:
				if body.carryableType == "gadget":
					found_gadget = body
					break

			if found_gadget:
				_throwCarryable(found_gadget)
				return true

		if allowCarrier:
			if !carriedCarryables.is_empty():
				deployKunaiCarrier()
				return true

		if allowSpecial:
			var has_special: = bool(Data.ofOr(playerId + ".keeper3.hasshuriken", false))
			if has_special and checkGenCanThrow() and cooldownManager.is_ready("kunai_special"):
				throwKunai(true)
				return true

		$EmptyBombsound.startSound()
		return false
	else:
		var kunai_ready: bool = cooldownManager.is_ready("kunai")
		var can_throw: bool = checkGenCanThrow()
		if kunai_ready and can_throw:
			throwKunai(false)
			return true

		$EmptyBombsound.startSound()
		return false


func handleMouseDoubleThrow() -> void :
	if isPropelling:
		return

	throwShuriken()

func canDropCarryablesDownwards() -> bool:
	if carriedCarryables.is_empty():
		return false
	if not is_on_floor():
		return false

	var aimDirection: Vector2 = getAimDirection("aim1_snap")
	if aimDirection.length() == 0:
		aimDirection = moveDirectionInput
	if aimDirection.length_squared() == 0.0:
		return false
	return aimDirection.normalized().dot(Vector2.DOWN) >= cos(deg_to_rad(Keeper3GameplaySettings.DROP_CARRY_AIM_TOLERANCE_DEGREES))

func latchDropCarryablesIntent() -> void :
	dropCarryablesLatched = canDropCarryablesDownwards()

func tryDropCarryablesDownwards() -> bool:
	if not dropCarryablesLatched:
		return false
	dropCarryablesLatched = false
	if carriedCarryables.is_empty():
		return false

	disable_auto_pickup_until = Time.get_ticks_msec() / 1000.0 + Keeper3GameplaySettings.DROP_CARRY_PICKUP_BLOCK_DURATION

	for c in carriedCarryables.duplicate():
		var pushDirection: Vector2 = c.global_position - global_position
		if pushDirection.length_squared() < 1.0:
			pushDirection = Vector2(1.0 if lastFacingRight else -1.0, -1.0)
		dropCarry(c)
		c.apply_central_impulse(pushDirection.normalized() * Keeper3SecondarySettings.DROP_CARRY_PUSH_IMPULSE)

	downwardsDropCount += 1
	return true

func startAutoShoot() -> void :
	if isPropelling:
		return
	autoShoot = true
	was_double_click = false
	if cooldownManager.is_ready("kunai") and checkGenCanThrow():
		throwKunai(false)

func deploySingleCarrier() -> bool:
	if isPropelling:
		return false
	if carriedCarryables.is_empty():
		return false
	if tryDropCarryablesDownwards():
		return true

	if input_settings.drop_ressources_before_gadets:
		for body in carriedCarryables:
			if body.carryableType == "resource":
				deployKunaiCarrier(true)
				return true

	var found_non_resource: Node = null
	for body in carriedCarryables:
		if body.carryableType != "resource":
			found_non_resource = body
			break

	if found_non_resource:
		_throwCarryable(found_non_resource)
		return true

	deployKunaiCarrier()
	return true

func _throwCarryable(carryable: Node) -> void :
	handleThrowAnim(getAimDirection("aim2_snap"))
	dropCarry(carryable)
	var aim_dir: Vector2 = getAimDirection("aim2_snap")
	if aim_dir.length() == 0:
		aim_dir = moveDirectionInput

	if carryable is RigidBody2D:
		var rigid_body: = carryable as RigidBody2D
		if aim_dir.length() > 0:
			var impulse_strength: float = Keeper3SecondarySettings.TELEPORTER_THROW_IMPULSE if carryable.is_in_group("teleporters") else Keeper3SecondarySettings.GADGET_THROW_IMPULSE
			var impulse_dir: Vector2 = aim_dir * impulse_strength
			rigid_body.apply_central_impulse(impulse_dir - rigid_body.linear_velocity)

		var original_mask = carryable.collision_mask
		carryable.collision_mask &= ~ (1 << 14)

		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(carryable):
			carryable.collision_mask = original_mask

func throwShuriken() -> void :
	if isPropelling:
		return
	was_double_click = true
	handleKunai(true, true, false)

func on_cooldown_ready(cooldown_name: String):
	if cooldown_name == "kunai_special":
		_set_special_kunai_star_progress(1.0)
		_specialKunaiCooldownDuration = float(Data.ofOr(playerId + ".keeper3.shurikencooldown", SPECIAL_KUNAI_BASE_COOLDOWN))

func _handle_auto_kunai_ready() -> void :
	if GameWorld.paused:
		return
	if not autoShoot or was_double_click:
		return

	var aim_direction: Vector2 = getAimDirection("aim1_snap")
	if aim_direction.length() == 0:
		aim_direction = moveDirectionInput
	if aim_direction == Vector2.ZERO:
		return

	throwKunai(false)

func specialKunaiLimit() -> int:
	var limit: int = Data.of(playerId + ".keeper3.totalbombs")
	return limit

func checkSpecialKunaiAmount() -> bool:

	if maxSpecialKunaiCount != specialKunaiLimit():
		maxSpecialKunaiCount = specialKunaiLimit()
		specialKunaiCount = maxSpecialKunaiCount

	return specialKunaiCount > 0



func throwHook() -> void :
	if disabled:
		return
	if externallyMoved:
		return
	if chainActive or loadoutClimbingMode:
		return
	if !cooldownManager.is_ready("rope"):
		return

	var aimDirection: Vector2 = getAimDirection("rope_snap")
	if aimDirection.length() == 0:
		aimDirection = moveDirectionInput.normalized()
	if aimDirection.length_squared() <= 0.0001:
		return

	if is_instance_valid(hook):
		hook.queue_free()
		clear_hook()

	synchronizer.network_rpc(networkThrowHook.bind(aimDirection, global_position), true)

func disableHookDetach() -> void :
	if StageManager.isSwitchingStage():
		return
	assert (is_multiplayer_authority())
	synchronizer.network_rpc(_disableHookDetach, true)

@rpc("reliable", "any_peer")
func _disableHookDetach() -> void :
	_allowHookDetach = false

func enableHookDetach() -> void :
	assert (is_multiplayer_authority())
	synchronizer.network_rpc(_enableHookDetach, true)

@rpc("reliable", "any_peer")
func _enableHookDetach() -> void :
	_allowHookDetach = true

func autoHookHang() -> void :
	if chainActive:
		return
	if is_instance_valid(hook):
		hook.queue_free()
		clear_hook()
	var aimDir: Vector2 = Vector2.UP
	synchronizer.network_rpc(networkThrowHook.bind(aimDir, global_position), true)

@rpc("reliable", "any_peer")
func networkThrowHook(aimDirection: Vector2, startPosition: Vector2) -> void :
	hook = Keeper3SecondarySettings.HOOK_SCENE.instantiate()
	hook.global_position = startPosition
	hook.set_keeper(self)
	Style.init(hook)
	Level.map.addDrop(hook)
	hook.begin_travel_chain()
	hook.connect("on_connected", Callable(self, "on_hook_connected"))
	hook.connect("rope_detached", Callable(self, "_on_hook_rope_detached"))
	hook.connect("tree_exited", Callable(self, "_on_hook_tree_exited"))

	hook.linear_velocity = aimDirection.normalized() * hookSpeed
	hook.angular_velocity = 0.0
	hook.sleeping = false

	cooldownManager.set_cooldown("rope", rope_cooldown)
	hookState = HookState.Traveling
	lastAnchor = hook.global_position
	wasOnRope = false
	propelGraceLeft = 0.0
	propelInitialSpeed = 0.0
	propelInitialDistance = 0.0

	var aimDir: Vector2 = getAimDirection("rope_snap")
	if aimDir.length() == 0:
		aimDir = moveDirectionInput
	var right: = aimDir.x > 0
	var anim: String = ("throw_kunai_" + ("right" if right else "left")) + animationSuffix
	$Visuals / Sprite2D.play(anim)
	$Visuals / Sprite2D.set_frame_and_progress(0, 0)
	if _frame_drill_buff > 0:
		$Visuals / Sprite2D.speed_scale = 2.0
	else:
		$Visuals / Sprite2D.speed_scale = 1.0
	$ThrowRope.startSound()

func on_hook_connected(anchor: Vector2) -> void :
	if not is_instance_valid(hook):
		return
	lastAnchor = hook.global_position
	hookState = HookState.Attached
	cooldownManager.set_cooldown("rope", rope_cooldown)

func attach_to_chain(chain: ChainRope, ball: ChainAttachment) -> void :
	if not is_instance_valid(chain) or not is_instance_valid(ball):
		return

	if is_instance_valid(chainRopeNode) and chainRopeNode != chain:
		chainRopeNode.begin_detach()

	chainRopeNode = chain
	chainBall = ball
	chainActive = true
	chainPulling = true
	chainHanging = false
	chainGravityVelocity = 0.0
	chainStuckTimer = 0.0
	chainStuckCount = 0
	previousChainDistance = 0.0
	chainStuckPosition = global_position

	var rope_detached_callable: = Callable(self, "_on_chain_rope_detached")
	if not chainRopeNode.is_connected("rope_detached", rope_detached_callable):
		chainRopeNode.connect("rope_detached", rope_detached_callable)

	var rope_finished_callable: = Callable(self, "_on_chain_rope_finished")
	if not chainRopeNode.is_connected("rope_finished", rope_finished_callable):
		chainRopeNode.connect("rope_finished", rope_finished_callable)

func _update_chain_motion(delta: float) -> void :
	if not chainActive:
		return
	if not is_instance_valid(chainBall):
		detach_from_chain(false)
		return
	var target_position: Vector2 = chainRopeNode.get_base_position() if is_instance_valid(chainRopeNode) else chainBall.global_position
	var displacement_to_target: Vector2 = target_position - global_position
	var desired_velocity: Vector2 = Vector2.ZERO
	if delta > 0.0:
		desired_velocity = displacement_to_target / delta
	var max_speed: = Keeper3GameplaySettings.CHAIN_MAX_SPEED
	var vertical_input: = 0.0
	var climb_direction: = 0
	var length_adjusted: = false
	var hanging_descend: bool = false
	var hanging_idle_momentum: bool = false
	_hanging_effective_climb = 0
	if chainHanging:
		max_speed = minf(max_speed, Keeper3GameplaySettings.CHAIN_HANG_MAX_SPEED)
		vertical_input = moveDirectionInput.y
		if vertical_input > 0.3:
			climb_direction = 1
		elif vertical_input < -0.3:
			climb_direction = -1
		if climb_direction < 0 and is_instance_valid(chainRopeNode) and (is_on_ceiling() or is_on_wall()):
			var anchor_for_check: Vector2 = _get_chain_anchor_position()
			var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
			var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, anchor_for_check, collision_mask, [self])
			var hit: Dictionary = space.intersect_ray(params)
			if not hit.is_empty():
				detach_from_chain(false)
				if is_instance_valid(hook):
					hook.request_detach()
				hookState = HookState.Detached
				return
		if is_instance_valid(chainRopeNode):
			if climb_direction != 0:
				length_adjusted = chainRopeNode.adjust_hang_length(climb_direction)
			else:
				chainRopeNode.adjust_hang_length(0)
			chainRopeNode.set_stiff_mode(length_adjusted)
		_hanging_effective_climb = climb_direction if length_adjusted else 0
		hanging_descend = _hanging_effective_climb > 0
		hanging_idle_momentum = _hanging_effective_climb == 0
		if _hanging_effective_climb > 0:
			if not $CarryLineStretch.playing:
				$CarryLineStretch.startSound()
			$CarryLineContract.stop()
		elif _hanging_effective_climb < 0:
			if not $CarryLineContract.playing:
				$CarryLineContract.startSound()
			$CarryLineStretch.stop()
		else:
			$CarryLineStretch.stop()
			$CarryLineContract.stop()
		var target_length: = 0.0
		if is_instance_valid(chainRopeNode):
			target_length = chainRopeNode.get_target_length()
		var anchor_position: = _get_chain_anchor_position()
		var hang_length: = target_length
		if hang_length <= 0.0:
			hang_length = global_position.distance_to(anchor_position) + Keeper3SecondarySettings.CHAIN_LINK_LENGTH
		var distance_to_anchor: = global_position.distance_to(anchor_position)
		if _hanging_effective_climb == 0 and not is_on_wall() and distance_to_anchor > hang_length + 0.1:
			var desired_hang_length: = distance_to_anchor + Keeper3SecondarySettings.CHAIN_LINK_LENGTH
			if is_instance_valid(chainRopeNode):
				chainRopeNode.lock_hang_length(desired_hang_length)
				hang_length = chainRopeNode.get_target_length()
			else:
				hang_length = max(hang_length, desired_hang_length)
		if _hanging_effective_climb != 0:
			chainGravityVelocity = 0.0
			desired_velocity = _calculate_chain_rod_velocity(delta, _hanging_effective_climb)
		else:
			desired_velocity = _calculate_chain_slack_velocity(delta, hang_length)
		if desired_velocity.length() > max_speed:
			desired_velocity = desired_velocity.normalized() * max_speed
	if not hanging_descend and not chainHanging:
		if desired_velocity.length() > max_speed:
			desired_velocity = desired_velocity.normalized() * max_speed
	if chainPulling:
		chainGravityVelocity = minf(chainGravityVelocity + (Keeper3GameplaySettings.CHAIN_GRAVITY * delta), Keeper3GameplaySettings.CHAIN_MAX_SPEED)
		desired_velocity.y += chainGravityVelocity
		if desired_velocity.length() > max_speed:
			desired_velocity = desired_velocity.normalized() * max_speed
	elif not hanging_descend:
		chainGravityVelocity = 0.0
	var previous_position: Vector2 = global_position
	velocity = desired_velocity
	var saved_momentum: Vector2 = desired_velocity if hanging_idle_momentum else Vector2.ZERO
	move_and_slide()
	if chainHanging and hanging_idle_momentum:
		var wall_collision_occurred: = false
		var wall_normal: = Vector2.ZERO
		for i in range(get_slide_collision_count()):
			var collision: KinematicCollision2D = get_slide_collision(i)
			var normal: Vector2 = collision.get_normal()
			if absf(normal.x) > 0.5:
				wall_collision_occurred = true
				wall_normal = normal
				break
		if wall_collision_occurred and saved_momentum.length() > Keeper3GameplaySettings.CHAIN_HANG_WALL_COLLISION_MIN_SPEED:
			var normal_component: float = saved_momentum.dot( - wall_normal)
			if normal_component > 0.0:
				var tangent: Vector2 = Vector2( - wall_normal.y, wall_normal.x)
				var tangent_component: float = saved_momentum.dot(tangent)
				var damped_normal: float = normal_component * Keeper3GameplaySettings.CHAIN_HANG_WALL_COLLISION_NORMAL_DAMPING
				var damped_tangent: float = tangent_component * Keeper3GameplaySettings.CHAIN_HANG_WALL_COLLISION_DAMPING
				saved_momentum = tangent * damped_tangent + ( - wall_normal) * damped_normal
	if chainHanging and _hanging_effective_climb == 0 and is_on_wall() and is_instance_valid(chainRopeNode):
		var anchor_pos: = _get_chain_anchor_position()
		var dist: = global_position.distance_to(anchor_pos)
		var current_hang_length: = chainRopeNode.get_target_length()
		if dist > current_hang_length and dist - current_hang_length < 5.0:
			var dir: = (global_position - anchor_pos).normalized()
			global_position = anchor_pos + dir * current_hang_length
	if chainHanging and is_on_floor():
		detach_from_chain(false)
		if is_instance_valid(hook):
			hook.request_detach()
		hookState = HookState.Idle
		_reset_jump_state_on_landing()
		wasGrounded = true
		land()
		return
	var displacement: Vector2 = global_position - previous_position
	var actual_velocity: Vector2 = Vector2.ZERO
	if delta > 0.0:
		actual_velocity = displacement / delta
	if hanging_idle_momentum:
		velocity = saved_momentum
	else:
		velocity = actual_velocity
	chainBall.angular_velocity = 0.0
	chainBall.linear_velocity = actual_velocity
	if is_instance_valid(chainRopeNode):
		chainRopeNode.set_base_override(global_position, actual_velocity, delta)

	if chainPulling:
		if _check_chain_stuck(delta, desired_velocity, actual_velocity, displacement_to_target):
			_handle_chain_stuck()
			return
	var sprite: AnimatedSprite2D = $Visuals / Sprite2D
	sprite.rotation = 0
	var speed: float = actual_velocity.length()
	if chainHanging:
		if is_instance_valid(sprite):
			var current_animation: = String(sprite.animation)
			var is_throw_animation: = (
				current_animation.begins_with("throw_kunai_")
				or current_animation.begins_with("throw_shuriken_")
				or current_animation.begins_with("shoot_hanging_")
			)
			if sprite.is_playing() and is_throw_animation:
				return
		if _hanging_effective_climb > 0:
			var extend_anim: = "fall_front_fast" + animationSuffix
			if sprite.animation != extend_anim:
				sprite.play(extend_anim)
		elif _hanging_effective_climb < 0:
			var retract_anim: = "fly_up" + animationSuffix
			if sprite.animation != retract_anim:
				sprite.play(retract_anim)
		else:
			_apply_chain_hang_animation(sprite)
		return
	var ascend_threshold: = Keeper3GameplaySettings.CHAIN_MAX_SPEED * 0.15
	var fly_anim: = "fly_up" + animationSuffix
	var velocity_length_sq: = actual_velocity.length_squared()
	var should_play_fly: = false
	if chainPulling and velocity_length_sq > 0.0 and sprite.sprite_frames.has_animation(fly_anim):
		var velocity_dir: = actual_velocity.normalized()
		if actual_velocity.y < - ascend_threshold:
			var vertical_angle_limit: float = 90.0 - CHAIN_FLY_MIN_ANGLE_DEGREES
			var angle_from_vertical: float = absf(rad_to_deg(Vector2.UP.angle_to(velocity_dir)))
			if angle_from_vertical <= vertical_angle_limit:
				should_play_fly = true
	if should_play_fly:
		var current_anim: = String(sprite.animation)
		if current_anim != fly_anim or not sprite.is_playing():
			sprite.play(fly_anim)
			sprite.set_frame_and_progress(0, 0)
		return
	if speed > 10.0:
		sprite.play("roll_left" + animationSuffix)
	else:
		sprite.play("idle" + animationSuffix)

func _check_chain_stuck(delta: float, desired_velocity: Vector2, actual_velocity: Vector2, displacement_to_target: Vector2) -> bool:
	if not chainPulling:
		chainStuckTimer = 0.0
		chainStuckCount = 0
		return false

	var distance_to_target: float = displacement_to_target.length()
	var desired_speed: float = desired_velocity.length()
	var actual_speed: float = actual_velocity.length()

	if desired_speed < 10.0:
		chainStuckTimer = 0.0
		chainStuckCount = 0
		previousChainDistance = distance_to_target
		chainStuckPosition = global_position
		return false

	var actual_dir: Vector2 = actual_velocity.normalized() if actual_velocity.length_squared() > 0.0001 else Vector2.ZERO

	var desired_horizontal: float = abs(desired_velocity.x)
	var actual_horizontal: float = abs(actual_velocity.x)
	var actual_vertical: float = actual_velocity.y

	var horizontal_progress_ratio: float = 0.0
	if desired_horizontal > 20.0:
		horizontal_progress_ratio = actual_horizontal / desired_horizontal

	var target_dir: Vector2 = displacement_to_target.normalized() if displacement_to_target.length_squared() > 0.0001 else Vector2.ZERO
	var movement_toward_target: float = 0.0
	if target_dir.length_squared() > 0.0001 and actual_dir.length_squared() > 0.0001:
		movement_toward_target = actual_dir.dot(target_dir)

	var horizontal_stuck: bool = desired_horizontal > 30.0 and horizontal_progress_ratio < 0.4
	var direction_stuck: bool = desired_speed > 50.0 and movement_toward_target < 0.2
	var overall_speed_stuck: bool = desired_speed > 50.0 and (actual_speed / max(desired_speed, 1.0)) < 0.35

	var is_falling_down: bool = actual_vertical > 50.0
	var is_sliding_down_wall: bool = is_falling_down and desired_horizontal > 30.0 and horizontal_progress_ratio < 0.5

	var horizontal_position_changed: bool = abs(global_position.x - chainStuckPosition.x) > 3.0

	if not horizontal_position_changed:
		if is_sliding_down_wall:
			chainStuckCount += 2
		else:
			chainStuckCount += 1
	else:
		chainStuckCount = 0
		chainStuckPosition = global_position

	var is_position_stuck: bool = chainStuckCount > 2

	var distance_improving: bool = false
	if previousChainDistance > 0.0:
		var distance_delta: float = previousChainDistance - distance_to_target
		distance_improving = distance_delta > 5.0
	var distance_stuck: bool = distance_to_target > 25.0 and not distance_improving and previousChainDistance > 0.0

	previousChainDistance = distance_to_target

	var has_stuck_condition: bool = horizontal_stuck or direction_stuck or overall_speed_stuck or is_sliding_down_wall
	var has_stuck_evidence: bool = is_position_stuck or distance_stuck

	var is_stuck: bool = has_stuck_condition and has_stuck_evidence

	if is_stuck:
		chainStuckTimer += delta
		return chainStuckTimer >= chainStuckThreshold
	else:
		chainStuckTimer = 0.0
		return false

func _handle_chain_stuck() -> void :
	Logger.warn("Keeper3 stuck during chain pull, canceling hook", "Keeper3._handle_chain_stuck")
	releaseHookInput()
	chainStuckTimer = 0.0
	chainStuckCount = 0
	previousChainDistance = 0.0

func _apply_chain_hang_animation(sprite: AnimatedSprite2D) -> void :
	var anchor_position: Vector2 = lastAnchor
	if anchor_position == Vector2.ZERO and is_instance_valid(hook):
		anchor_position = hook.global_position
	var current_animation: = String(sprite.animation)
	var facing_right: = false
	var aim: = getAimDirection("aim2_snap")
	if abs(aim.x) > 0.1:
		facing_right = aim.x > 0
	elif anchor_position != Vector2.ZERO:
		facing_right = anchor_position.x > global_position.x
		if abs(anchor_position.x - global_position.x) < 0.5:
			facing_right = moveDirectionInput.x >= 0.0 or current_animation.ends_with("right" + animationSuffix)
	else:
		if current_animation.ends_with("right" + animationSuffix):
			facing_right = true
		elif current_animation.ends_with("left" + animationSuffix):
			facing_right = false
		else:
			facing_right = moveDirectionInput.x >= 0.0
	lastFacingRight = facing_right
	var animation_base: = "hanging_right" if facing_right else "hanging_left"
	var animation_name: = animation_base + animationSuffix
	var animation_name_sn: StringName = animation_name
	if sprite.animation != animation_name_sn:
		sprite.play(animation_name_sn)
		sprite.set_frame_and_progress(0, 0)
	sprite.pause()

func _get_chain_anchor_position() -> Vector2:
	if is_instance_valid(chainRopeNode):
		return chainRopeNode.get_anchor_position()
	if is_instance_valid(hook):
		return hook.global_position
	return lastAnchor

func _calculate_chain_rod_velocity(delta: float, climb_direction: int) -> Vector2:

	var anchor_position: = _get_chain_anchor_position()
	var to_anchor: Vector2 = global_position - anchor_position
	var current_length: = to_anchor.length()
	if current_length <= 0.001:
		to_anchor = Vector2.DOWN
		current_length = 0.001
	var radial_dir: = to_anchor / current_length
	var tangential_dir: = Vector2( - radial_dir.y, radial_dir.x)

	var length_delta: = 0.0
	if climb_direction < 0:
		length_delta = - Keeper3GameplaySettings.CHAIN_HANG_CLIMB_SPEED * delta
	elif climb_direction > 0:
		length_delta = Keeper3GameplaySettings.CHAIN_HANG_EXTEND_SPEED * delta
	var min_length: = Keeper3SecondarySettings.CHAIN_LINK_LENGTH * float(Keeper3SecondarySettings.CHAIN_MIN_LINKS)
	var max_length: = Keeper3SecondarySettings.CHAIN_LINK_LENGTH * float(Keeper3SecondarySettings.CHAIN_MAX_LINKS)
	var target_length: = clampf(current_length + length_delta, min_length, max_length)

	var radial_speed: = 0.0
	if delta > 0.0:
		radial_speed = (target_length - current_length) / delta

	var momentum_decay: = Keeper3GameplaySettings.CHAIN_HANG_MOMENTUM_DECAY
	if climb_direction != 0:
		momentum_decay = Keeper3GameplaySettings.CHAIN_HANG_CLIMB_MOMENTUM_DECAY
	var adjusted_velocity: = velocity * momentum_decay
	adjusted_velocity += Vector2(0.0, Keeper3GameplaySettings.GRAVITY * delta * Keeper3GameplaySettings.CHAIN_HANG_GRAVITY_SCALE)

	var tangential_speed: = adjusted_velocity.dot(tangential_dir)
	var tangential_velocity: = tangential_dir * tangential_speed
	return tangential_velocity + radial_dir * radial_speed

func _calculate_chain_slack_velocity(delta: float, max_length: float) -> Vector2:
	var adjusted_velocity: = velocity * Keeper3GameplaySettings.CHAIN_HANG_MOMENTUM_DECAY
	adjusted_velocity += Vector2(0.0, Keeper3GameplaySettings.GRAVITY * delta * Keeper3GameplaySettings.CHAIN_HANG_GRAVITY_SCALE)
	if delta <= 0.0:
		return adjusted_velocity
	var anchor_position: = _get_chain_anchor_position()
	var next_position: = global_position + adjusted_velocity * delta
	var to_anchor_next: = next_position - anchor_position
	var next_distance: = to_anchor_next.length()
	if next_distance <= max_length or next_distance <= 0.001:
		return adjusted_velocity
	var radial_dir: = to_anchor_next / next_distance
	var clamped_position: = anchor_position + radial_dir * max_length
	var clamped_velocity: = (clamped_position - global_position) / delta
	var tangential_dir: = Vector2( - radial_dir.y, radial_dir.x)
	return tangential_dir * clamped_velocity.dot(tangential_dir)

func _attempt_chain_jump() -> bool:
	if not chainActive or not chainHanging:
		return false
	if jumpCount >= _frame_max_jumps:
		justPressedUp = false
		return false

	justPressedUp = false

	detach_from_chain(false)
	if is_instance_valid(hook):
		hook.request_detach()
	hookState = HookState.Detached

	velocity = Vector2.ZERO
	jumpCount = 0
	_start_jump()

	var baseVerticalSpeed: float = absf(velocity.y)
	var launchRight: bool = lastFacingRight

	var launchAngle: float = deg_to_rad(30.0)
	var baseDirection: Vector2 = Vector2.RIGHT if launchRight else Vector2.LEFT
	var launchDirection: Vector2 = baseDirection.rotated( - launchAngle if launchRight else launchAngle)
	if launchDirection.is_zero_approx():
		launchDirection = baseDirection
	else:
		launchDirection = launchDirection.normalized()

	var forceScale: float = Keeper3GameplaySettings.CHAIN_JUMP_DIRECTIONAL_FORCE_SCALE
	var verticalTarget: float = baseVerticalSpeed * forceScale
	var directionVertical: float = absf(launchDirection.y)
	if directionVertical > 0.0001:
		var launchSpeed: float = verticalTarget / directionVertical
		velocity = launchDirection * launchSpeed
	else:
		velocity = launchDirection * verticalTarget

	return true

func detach_from_chain(apply_velocity: = true) -> void :
	if not _allowHookDetach:
		return
	if not chainActive:
		return

	var exited_chain_hang: = chainHanging
	chainActive = false
	chainPulling = false
	chainHanging = false
	_hanging_effective_climb = 0
	chainGravityVelocity = 0.0
	airReleaseDecelActive = false
	lastAirHadInput = false

	var transfer_velocity: = Vector2.ZERO
	var has_transfer_velocity: = false
	if apply_velocity and is_instance_valid(chainBall):
		transfer_velocity = chainBall.linear_velocity
		has_transfer_velocity = true

	if is_instance_valid(chainRopeNode) and not chainRopeNode.is_queued_for_deletion():
		chainRopeNode.begin_detach()

	var rope_detached_callable: = Callable(self, "_on_chain_rope_detached")
	if is_instance_valid(chainRopeNode) and chainRopeNode.is_connected("rope_detached", rope_detached_callable):
		chainRopeNode.disconnect("rope_detached", rope_detached_callable)

	var rope_finished_callable: = Callable(self, "_on_chain_rope_finished")
	if is_instance_valid(chainRopeNode) and chainRopeNode.is_connected("rope_finished", rope_finished_callable):
		chainRopeNode.disconnect("rope_finished", rope_finished_callable)

	chainRopeNode = null

	if is_instance_valid(chainBall):
		chainBall = null

	if has_transfer_velocity:
		velocity = transfer_velocity

	if exited_chain_hang:
		_reset_jump_state_after_chain_hang()
	elif not is_on_floor():
		jumpCount = 1

	if $CarryLineContract.playing:
		$CarryLineContract.stop()

func releaseHookInput() -> void :
	synchronizer.network_rpc(networkReleaseHookInput, true)

@rpc("reliable", "any_peer")
func networkReleaseHookInput() -> void :
	if not _allowHookDetach:
		return

	if _cleanup_hook_chain():
		return
	clear_hook()

func _cleanup_hook_chain() -> bool:
	var cleaned: = false
	if is_instance_valid(chainRopeNode):
		chainRopeNode.begin_detach()
		chainRopeNode = null
		cleaned = true
	elif chainActive:
		detach_from_chain()
		cleaned = true
	if is_instance_valid(hook):
		hook.request_detach()
		cleaned = true
	return cleaned

func _on_chain_rope_detached() -> void :
	detach_from_chain()

func _on_chain_rope_finished() -> void :
	if not chainActive:
		return
	chainPulling = false
	chainHanging = true
	chainHangJumpReady = true
	jumpCount = 0
	firstJumpGraceActive = false
	firstJumpGraceTimer = 0.0
	jumpAscending = false
	jumpHoldTimer = 0.0
	currentJumpProfileIndex = -1
	if is_instance_valid(chainRopeNode):
		chainRopeNode.set_stiff_mode(false)
		var anchor_position: = _get_chain_anchor_position()
		var hang_length: = global_position.distance_to(anchor_position) + Keeper3SecondarySettings.CHAIN_LINK_LENGTH
		chainRopeNode.lock_hang_length(hang_length)
	var retained_velocity: = velocity * Keeper3GameplaySettings.CHAIN_HANG_DAMP_FACTOR
	if retained_velocity.length() > Keeper3GameplaySettings.CHAIN_HANG_MAX_SPEED:
		retained_velocity = retained_velocity.normalized() * Keeper3GameplaySettings.CHAIN_HANG_MAX_SPEED
	velocity = retained_velocity
	if is_instance_valid(chainBall):
		var ball_velocity: = chainBall.linear_velocity * Keeper3GameplaySettings.CHAIN_HANG_DAMP_FACTOR
		if ball_velocity.length() > Keeper3GameplaySettings.CHAIN_HANG_MAX_SPEED:
			ball_velocity = ball_velocity.normalized() * Keeper3GameplaySettings.CHAIN_HANG_MAX_SPEED
		chainBall.linear_velocity = ball_velocity
		chainBall.angular_velocity = 0.0
	var sprite: AnimatedSprite2D = $Visuals / Sprite2D
	sprite.rotation = 0
	_apply_chain_hang_animation(sprite)

func clear_hook():
	if is_instance_valid(hook):
		var callable: = Callable(self, "_on_hook_tree_exited")
		if hook.is_connected("tree_exited", callable):
			hook.disconnect("tree_exited", callable)
	detach_from_chain(false)
	hook = null
	hookState = HookState.Idle
	isPropelling = false
	propelInitialDistance = 0.0
	propelInitialSpeed = 0.0
	propelGraceLeft = 0.0
	lastAnchor = Vector2.ZERO


func _on_hook_tree_exited() -> void :
	hook = null
	if hookState != HookState.Detached:
		isPropelling = false
		detach_from_chain(false)
	hookState = HookState.Idle
	lastAnchor = Vector2.ZERO



func _on_hook_rope_detached() -> void :
	detach_from_chain()
	hookState = HookState.Detached

func _update_hook_camera(delta: float) -> void :
	var camera = InputSystem.getCamera(playerId)
	if not is_instance_valid(camera):
		return

	var hook_active: = hookState != HookState.Idle
	var hook_pos: Vector2 = Vector2.ZERO

	var hook_velocity: Vector2 = Vector2.ZERO
	if hook_active:
		if is_instance_valid(hook):
			hook_pos = hook.global_position
			hook_velocity = hook.linear_velocity
		elif lastAnchor != Vector2.ZERO:
			hook_pos = lastAnchor
		else:
			hook_active = false

	var distance: float = global_position.distance_to(hook_pos)
	var is_pulling: = hookState == HookState.Attached

	if not hook_active or isInsideDome or (distance < Keeper3GameplaySettings.HOOK_CAMERA_MIN_DISTANCE and not is_pulling):
		_hookCameraRamp = 0.0
		if _hookCameraPositionOffset.length() > 1.0:
			_hookCameraPositionOffset = _hookCameraPositionOffset.lerp(Vector2.ZERO, Keeper3GameplaySettings.HOOK_CAMERA_POSITION_SPEED * delta)
			camera.targetOffset = _hookCameraPositionOffset
			if _hookCameraPositionOffset.length() < 1.0:
				_hookCameraPositionOffset = Vector2.ZERO
				camera.targetOffset = Vector2.ZERO
		elif _hookCameraPositionOffset != Vector2.ZERO:
			_hookCameraPositionOffset = Vector2.ZERO
			camera.targetOffset = Vector2.ZERO
		return

	_hookCameraRamp = move_toward(_hookCameraRamp, 1.0, Keeper3GameplaySettings.HOOK_CAMERA_RAMP_SPEED * delta)

	var velocity_lead: Vector2 = hook_velocity * Keeper3GameplaySettings.HOOK_CAMERA_VELOCITY_LEAD
	var predicted_hook_pos: Vector2 = hook_pos + velocity_lead
	var rope_camera_follow = input_settings.rope_camera_follow
	if chainActive and not chainPulling:

		rope_camera_follow = 0.0
	var targetOffset: Vector2 = (predicted_hook_pos - global_position) * rope_camera_follow * _hookCameraRamp
	_hookCameraPositionOffset = _hookCameraPositionOffset.lerp(targetOffset, Keeper3GameplaySettings.HOOK_CAMERA_SMOOTHING * delta)
	camera.targetOffset = _hookCameraPositionOffset

func onShowKeeperAimIndicatorChanged():
	if loadoutClimbingMode or not Keepers.local.hasPlayerId(playerId):
		$AimIndicator.visible = false
	elif Options.useGamepad(deviceId):
		$AimIndicator.visible = input_settings.show_aim_indicator
	else:

		$AimIndicator.visible = input_settings.show_aim_indicator

func as_movement_dummy():
	isMovementDummy = true
	loadoutClimbingMode = true
	$Visuals.visible = false
	for c in get_children():
		if c is Sound:
			c.baseVolume = -100
	set_collision_layer_value(CONST.LAYER_PLAYER, false)
