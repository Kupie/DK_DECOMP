class_name Drillbot
extends Carryable

signal startedFalling(UID: int)
signal landed(UID: int)
signal startedWalking(UID: int)
signal startedIdling(UID: int)
signal startedWorking(UID: int)
signal wentToSleep(UID: int)
signal directionWasSet(UID: int, dir: Vector2)
signal startedDrilling(UID: int)
signal usedHit(UID: int, playerId: String)
signal wokeUp(UID: int)
signal switchedDirection(UID: int)
signal wasScared(UID: int)
signal stoppedBeingScared(UID: int)
signal treatEaten(UID: int)

enum State{WORKING, FALLING, SLEEPING, SCARED, CARRIED, LANDING}
enum WorkingState{NONE, IDLING, WALKING, DRILLING}
var state: int = State.SLEEPING
var workingState: WorkingState = WorkingState.NONE

var type: = CONST.DRILLBOT
var cooldown: = 0.0
var hitCooldown: = 0.0
var direction: Vector2 = Vector2.ZERO
var stableTime: = 0.0
var stuckTime: = 0.0
var sparkCooldown: = -1.0


var remainingSleepTime: = 1.0
var wasGoingDown: = false
var currentDrillSound
var stepSounds: Array
var wakingUp: = false

var isOnScreen: = false
var arrowsByRequester: = {}

var remainingHits: = 0
var remainingBuffedHits: = 0
var speed: = 1.0
var hitStrengthMod: = 1.0

var station: DrillbotStation
var rand: RandomNumberGenerator
var fromDeserialize: bool

const FootstepDust = preload("res://content/gadgets/drillbot/FootstepDust.tscn")


var playerControlled: bool
var playerId: String
var moveDirectionInput: Vector2
var usables: = []
var focussedUsable
var UseArea
var isInsideDome: = false
var isInsideStation: = false
var techId: = "drillbot"
var drillDown: = false

func _ready():
	super._ready()
	rand = RandomNumberGenerator.new()
	rand.seed = UID

	if multiplayer.is_server() and ( not fromDeserialize or state == State.SLEEPING):
		animation("sleep")
		state = State.SLEEPING
		normalMode()
		setDirection(Vector2.LEFT)

	if Data.ofOr("world.inversegravity", false):
		$BottomHitTestRay.rotate(PI)
		$Sprite2D.flip_v = true
		$Sprite2D.position.y += 12
		$DrillHitTestRay.position.y += 5

	add_to_group(teamId + "-drillbots")
	var drillbotCount: = get_tree().get_nodes_in_group(teamId + "-drillbots").size()
	if GameWorld.isChristmas and drillbotCount == 1:
		$Sprite2D.sprite_frames = load("res://content/gadgets/drillbot/frames_christmas.tres")
	else:
		$Sprite2D.sprite_frames = load("res://content/gadgets/drillbot/frames" + str(1 + (drillbotCount - 1) % 4) + ".tres")

	if GameWorld.isChristmas:
		$StepSound.pitch_scale = 1.0
		$StepSound.basePitch = 1.0
		var array = [
			preload("res://content/sounds/christmas/belldig_01.wav"), 
			preload("res://content/sounds/christmas/belldig_02.wav"), 
			preload("res://content/sounds/christmas/belldig_03.wav"), 
			preload("res://content/sounds/christmas/belldig_04.wav"), 
			preload("res://content/sounds/christmas/belldig_05.wav"), 
		] as Array[AudioStream]

		$StepSound.streams = array

	stepSounds = [$StepSound]


	Data.listen(self, teamId + ".monsters.wavepresent")
	Data.listen(self, teamId + ".drillbot.drilllevel", true)
	Data.listen(self, teamId + ".drillbot.amount", true)
	Style.init(self)

	if drillbotCount == 1:
		Level.addTutorial(self, "drillbothandling", teamId)
		Level.addTutorial(self, "drillbotsleeping", teamId)

	Achievements.addIfOpen(self, "DRILLBERT_TREATS", teamId)

func serialize() -> Dictionary:
	var data = super.serialize()
	data["state"] = state
	data["cooldown"] = cooldown
	data["hitCooldown"] = hitCooldown
	data["direction"] = var_to_str(direction)
	data["stableTime"] = stableTime
	data["stuckTime"] = stuckTime
	data["remainingSleepTime"] = remainingSleepTime
	data["wasGoingDown"] = wasGoingDown
	data["remainingHits"] = remainingHits
	data["remainingBuffedHits"] = remainingBuffedHits
	data["speed"] = speed
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	fromDeserialize = true
	cooldown = data["cooldown"]
	hitCooldown = data["hitCooldown"]
	stableTime = data["stableTime"]
	stuckTime = data["stuckTime"]
	remainingSleepTime = data["remainingSleepTime"]
	wasGoingDown = data["wasGoingDown"]
	speed = data["speed"]

	setState(int(data["state"]))
	localSetDirection(BackwardCompatibilityUtils.str_to_var(data["direction"]))

	if state == State.WORKING:
		normalMode()
		startedWorking.emit(UID)
	if state == State.FALLING:
		normalMode()
		startedFalling.emit(UID)
	if state == State.SLEEPING:
		normalMode()
	if state == State.SCARED:
		normalMode()
	if state == State.CARRIED:
		onCarried(carriedBy[0])
	if state == State.LANDING:
		pass

	await GameWorld.savegame_loaded

	remainingHits = data["remainingHits"]
	remainingBuffedHits = data["remainingBuffedHits"]

func get_drillbot_state() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_u32(UID)
	stream.encode_u8(state)
	stream.encode_float(cooldown)
	stream.encode_float(hitCooldown)
	stream.encode_vector2(direction)
	stream.encode_u8(remainingHits)
	stream.encode_u8(remainingBuffedHits)
	stream.encode_float(speed)
	return stream.data

func set_drillbot_state(stream: PackedByteStream) -> void :
	state = stream.decode_u8()
	cooldown = stream.decode_float()
	hitCooldown = stream.decode_float()
	direction = stream.decode_vector2()
	remainingHits = stream.decode_u8()
	remainingBuffedHits = stream.decode_u8()
	speed = stream.decode_float()

	setState(state)
	localSetDirection(direction)

	if state == State.WORKING:
		normalMode()
		startWorking()
	if state == State.FALLING:
		normalMode()
		startFalling()
	if state == State.SLEEPING:
		normalMode()
		animation("sleep")
	if state == State.SCARED:
		normalMode()
		setScared()
	if state == State.CARRIED:
		onCarried(carriedBy[0])
	if state == State.LANDING:
		pass

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".drillbot.drilllevel":
		match int(newValue):
			0: currentDrillSound = $DrillSound0
			1: currentDrillSound = $DrillSound1
			2: currentDrillSound = $DrillSound2
			3: currentDrillSound = $DrillSound3
			4: currentDrillSound = $DrillSound4
			_: currentDrillSound = $DrillSound0
	elif property == teamId + ".monsters.wavepresent":
		if not newValue and carriedBy.size() == 0:
			stoppedBeingScared.emit(UID)
	elif property == teamId + ".drillbot.amount":
		if oldValue:
			remainingHits = remainingHits + (newValue - oldValue)
		else:
			remainingHits += newValue

func _physics_process(delta):
	for req in arrowsByRequester:
		var arrow = arrowsByRequester[req]
		arrow.visible = not isOnScreen
		var basePos = req.global_position
		var d = global_position - basePos
		arrow.rotation = d.angle() + PI * 0.5
		arrow.position = basePos + Vector2.UP.rotated(arrow.rotation) * 35

	if not multiplayer.is_server():
		super._physics_process(delta)
		if state == State.WORKING:
			match (workingState):
				WorkingState.IDLING:
					animation("idle")
				WorkingState.WALKING:
					animation("walk")
				WorkingState.DRILLING:
					if hitCooldown > 0.0:
						hitCooldown -= delta
						if sparkCooldown > 0.0:
							sparkCooldown -= delta
						if sparkCooldown <= 0.0 and sparkCooldown > -1:
							createSparks()
							sparkCooldown = 0.03 * (1.0 / speed)
					if hitCooldown <= 0.0:
						if sparkCooldown == -1:
							sparkCooldown = 0
						animation("drill")
						currentDrillSound.startSound()
						if remainingBuffedHits > 0:
							remainingBuffedHits -= 1
							hitCooldown = 0.2 * (1.0 / speed)
						elif remainingHits > 0:
							remainingHits -= 1
							hitCooldown = 0.2
		return

	if isCarried():
		rotateUpright()
		return

	if isPlane():
		stableTime += delta
	else:
		if not state == State.FALLING:
			if stableTime > 0.0:
				stableTime = 0.0
			stableTime -= delta
			if stableTime < -0.3:
				startedFalling.emit(UID)

	if cooldown > 0.0:
		cooldown -= delta * GameWorld.cycleSpeed
		return

	if GameWorld.softPaused(teamId) and not playerControlled:
		if state == State.WORKING:
			if Data.of(teamId + ".monsters.wavepresent") and beScared():
				return

	$DrillHitTestRay.enabled = true
	if state != State.WORKING:
		workingState = WorkingState.NONE
	if state != State.SLEEPING:
		wakingUp = false
	match int(state):
		State.WORKING:
			rotateUpright()
			if linear_velocity.y > 2.0 and stableTime <= -0.3 and gravity_scale >= 0.2:
				startedFalling.emit(UID)
				return

			if GameWorld.paused:
				return

			if hitCooldown > 0.0:
				hitCooldown -= delta
				if sparkCooldown > 0.0:
					sparkCooldown -= delta
				if sparkCooldown <= 0.0 and sparkCooldown > -1:
					createSparks()
					sparkCooldown = 0.03 * (1.0 / speed)

			var collider
			if drillDown:
				collider = $BottomHitTestRay.get_collider()
			else:
				collider = $DrillHitTestRay.get_collider()
			if playerControlled:
				remainingHits = 999
				if moveDirectionInput.length() > 0:
					var s: float
					if collider and sign(moveDirectionInput.x) == sign(direction.x):
						s = moveDirectionInput.x * 2.0
					else:
						s = moveDirectionInput.x * 3.0 * speed
					apply_central_impulse(Vector2(s, moveDirectionInput.y * 3.0 * (1.0 - gravity_scale)))
				else:
					apply_central_impulse(Vector2( - linear_velocity.x * 0.2, 0))

			if not collider:
				if playerControlled:
					if linear_velocity.length() > 5.0:
						animation("walk")
						$Sprite2D.speed_scale = linear_velocity.length() / 50.0
						if linear_velocity.x < -1.0:
							setDirection(Vector2.LEFT)
						elif linear_velocity.x > 1.0:
							setDirection(Vector2.RIGHT)
					else:
						animation("idle")
				else:
					apply_central_impulse(direction * 2.0 * speed)
					if workingState != WorkingState.WALKING:
						startedWalking.emit(UID)
					animation("walk")
				stuckTime = 0.0
				if $DefaultCollisionShape3.disabled:
					$DefaultCollisionShape3.disabled = false
				return
			elif not Data.isDestructable(collider):
				if workingState != WorkingState.IDLING:
					startedIdling.emit(UID)
				stuckTime += delta
				if stuckTime > 1.0:
					if Data.of(teamId + ".drillbot.turnaround"):
						setDirection(direction * Vector2.LEFT)
					else:
						wentToSleep.emit(UID)
			elif hitCooldown <= 0.0:
				if workingState != WorkingState.DRILLING:
					workingState = WorkingState.DRILLING
					startedDrilling.emit(UID)

				if sparkCooldown == -1:
					sparkCooldown = 0
				if not playerControlled:
					apply_impulse( - linear_velocity * 0.5, Vector2(0, 0))
				var dir = global_position - collider.global_position
				var ds = Data.of(teamId + ".drillbot.drillstrength")
				collider.hit(dir, ds + collider.max_health * 0.03 + ds * 0.005, teamId)
				animation("drill")
				currentDrillSound.startSound()
				if remainingBuffedHits > 0:
					remainingBuffedHits -= 1
					hitCooldown = 0.2 * (1.0 / speed)
				elif remainingHits > 0:
					remainingHits -= 1
					hitCooldown = 0.2
				elif not playerControlled:
					wentToSleep.emit(UID)
		State.FALLING:
			if playerControlled:
				if moveDirectionInput.length() > 0:
					apply_central_impulse(Vector2(moveDirectionInput.x * 2.0, moveDirectionInput.y * 2.0 * (1.0 - gravity_scale)))
				else:
					apply_central_impulse(Vector2( - linear_velocity.x * 0.04, - linear_velocity.x * 0.04 * (1.0 - gravity_scale)))

			wasGoingDown = wasGoingDown or linear_velocity.y > 2.0
			if abs(linear_velocity.x) > 4.0:
				if linear_velocity.x < 0:
					setDirection(Vector2.LEFT)
				else:
					setDirection(Vector2.RIGHT)
			rotateUpright()
			if stableTime > 0.1 and wasGoingDown:
				landed.emit(UID)
			elif stableTime > 1.0 or (playerControlled and stableTime > 0.3):
				startedWorking.emit(UID)
		State.SLEEPING:
			remainingSleepTime -= delta * GameWorld.cycleSpeed
			if remainingSleepTime <= 0.0:
				if not wakingUp:
					wakingUp = true
					remainingHits = max(remainingHits, Data.of(teamId + ".drillbot.amount"))
					wokeUp.emit(UID)
			if linear_velocity.length() > 2.0:
				startedFalling.emit(UID)
		State.LANDING:
			rotateUpright()
			if stableTime > (0.8 if playerControlled else 3.0):
				startedWorking.emit(UID)

func startDrilling() -> void :
	workingState = WorkingState.DRILLING
	animation("drill")
	remainingHits = Data.of(teamId + ".drillbot.amount") + Data.of(teamId + ".drillbot.buffextraamount")
	remainingBuffedHits = Data.of(teamId + ".drillbot.buffamount")
	speed = Data.of(teamId + ".drillbot.buffstrength")
	match int(Data.of(teamId + ".drillbot.drilllevel")):
		0: currentDrillSound = $DrillSound0
		1: currentDrillSound = $DrillSound1
		2: currentDrillSound = $DrillSound2
		3: currentDrillSound = $DrillSound3
		4: currentDrillSound = $DrillSound4
		_: currentDrillSound = $DrillSound0

func isPlane() -> bool:
	return abs(fmod(rotation, PI)) <= 0.2 and abs(linear_velocity.y) * gravity_scale < 4.0 and $BottomHitTestRay.get_collider()

func land() -> void :
	animation("land")
	$LandSound.startSound()
	setState(State.LANDING)

func createSparks() -> void :
	if not Network.is_point_visible_by_peer(global_position, multiplayer.get_unique_id()):
		return
	for _i in range(1):
		var s
		if $DefaultCollisionShape3.disabled:
			if not $DrillHitTestRay.is_colliding():
				return
			s = Data.KEEPER_SPARK.instantiate()
			s.global_position = $DrillHitTestRay.get_collision_point()
		else:
			s = Data.KEEPER_SPARK.instantiate()
			s.global_position = $DrillPoint.global_position
		s.apply_central_impulse(Vector2.LEFT.rotated($DrillHitTestRay.rotation + randf_range(-0.5, 0.5)) * randf_range(30, 150))
		get_parent().call_deferred("add_child", s)

func startWalking() -> void :
	state = State.WORKING
	workingState = WorkingState.WALKING
	animation("walk")
	$Sprite2D.speed_scale = linear_velocity.length() / 50.0

func startIdling() -> void :
	state = State.WORKING
	workingState = WorkingState.IDLING
	animation("idle")

func rotateUpright():
	if playerControlled:
		apply_torque_impulse( - rotation * 20.0)
	else:
		apply_torque_impulse( - rotation * 10.0)

func startFalling(playSound: = true):
	if $SleepingSound.playing:
		$SleepingSound.stop()
	if playSound:
		$FallingScreamSound.startSound()
	wasGoingDown = false
	setState(State.FALLING)
	stableTime = 0.0
	animation("knockback")
	$DefaultCollisionShape3.disabled = true

func animation(ani: String):
	$Sprite2D.speed_scale = 1.0 * speed
	$Sprite2D.play(ani)

func startWorking():
	animation("idle")
	if not playerControlled:
		cooldown = 1.0
	setState(State.WORKING)

func isWorking():
	return state == State.WORKING

func isCarried():
	return state == State.CARRIED

func canFocusUse(keeper: Keeper) -> bool:
	return not isCarried() and not state == State.FALLING

func useHold(keeper: Keeper) -> bool:
	return false

func useHit(keeper: Keeper) -> bool:
	usedHit.emit(UID, keeper.playerId)
	return true

func registerHit(playerId: String) -> void :
	if state == State.SLEEPING:
		wokeUp.emit(UID)
		Backend.event("gadget_used", {"gadget": "drillbot", "activity": "woken"})
	elif state == State.SCARED:
		wokeUp.emit(UID)
	else:
		switchedDirection.emit(UID)
	remainingHits = Data.of(teamId + ".drillbot.amount")

func switchDirection() -> void :
	animation("idle")
	sparkCooldown = -1
	localSetDirection(direction * Vector2.LEFT)
	$ChangeDirectionSound.startSound()
	Backend.event("gadget_used", {"gadget": "drillbot", "activity": "switched"})

func setDirection(dir: Vector2):
	if dir == direction:
		return
	direction = dir
	directionWasSet.emit(UID, dir)

func localSetDirection(dir: Vector2) -> void :
	direction = dir
	$Sprite2D.flip_h = dir == Vector2.RIGHT
	$DrillHitTestRay.rotation = direction.angle()
	var side: float = -1.0 if dir == Vector2.LEFT else 1.0
	$DrillHitTestRay.position.x = abs($DrillHitTestRay.position.x) * side
	$DrillPoint.position.x = abs($DrillPoint.position.x) * side
	$Sprite2D.position.x = abs($Sprite2D.position.x) * side
	$DefaultCollisionShape1.position.x = abs($DefaultCollisionShape1.position.x) * side
	$DefaultCollisionShape2.position.x = abs($DefaultCollisionShape2.position.x) * side
	$DefaultCollisionShape3.position.x = abs($DefaultCollisionShape3.position.x) * side
	$DefaultCollisionShape4.position.x = abs($DefaultCollisionShape4.position.x) * side
	$CarriedCollisionShape.position.x = abs($CarriedCollisionShape.position.x) * side
	$FocusSprite.position.x = abs($FocusSprite.position.x) * side
	$CarrySprite.position.x = abs($CarrySprite.position.x) * side

func onCarried(p):
	animation("carried")
	$DefaultCollisionShape1.disabled = true
	$DefaultCollisionShape2.disabled = true
	$DefaultCollisionShape3.disabled = true
	$DefaultCollisionShape4.disabled = true
	$CarriedCollisionShape.disabled = false
	setState(State.CARRIED)
	if $SleepingSound.playing:
		$SleepingSound.stop()
	remainingHits = Data.of(teamId + ".drillbot.amount")
	Backend.event("gadget_used", {"gadget": "drillbot", "activity": "pickup"})

func onDropped(keeper_or_kunaicarrier):
	animation("knockback")
	normalMode()
	if multiplayer.is_server():
		startedFalling.emit(UID)
	Backend.event("gadget_used", {"gadget": "drillbot", "activity": "drop"})

func normalMode():
	$DefaultCollisionShape1.disabled = false
	$DefaultCollisionShape2.disabled = false
	$DefaultCollisionShape4.disabled = false
	$CarriedCollisionShape.disabled = true

func goToSleep():
	setState(State.SLEEPING)
	normalMode()
	animation("liedown")
	remainingSleepTime = Data.of(teamId + ".drillbot.sleeptime") * GameWorld.getTimeBetweenWaves(teamId)

func beScared():
	if Data.of(teamId + ".drillbot.scared"):
		wasScared.emit(UID)
		return true
	return false

func setScared() -> void :
	setState(State.SCARED)
	normalMode()
	animation("scared")

func stopBeingScared():
	if state == State.SCARED:
		animation("getup")
		$WakeupSound.startSound()


func wakeUp():
	animation("getup")
	$SleepingSound.stop()
	$WakeupSound.startSound()
	remainingSleepTime = 0.0

func fadeIn() -> void :
	%Sprite2D.modulate = Color(0.1, 0.1, 0.1, 1.0)
	%Sprite2D.scale *= 0.0
	var tween: = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property( %Sprite2D, "modulate", Color.WHITE, 0.9)
	tween.parallel().tween_property( %Sprite2D, "scale", Vector2.ONE, 1.0)
	tween.tween_callback(finishFade)

func finishFade() -> void :
	gravity_scale = 1.0
	apply_central_impulse(
		Vector2(rand.randf_range(-60, -10), rand.randf_range(-100, -250))
	)

func _on_sprite_2d_animation_looped() -> void :
	_SpriteAnimationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_SpriteAnimationFinishedCheck()

func _SpriteAnimationFinishedCheck() -> void :
	match $Sprite2D.animation:
		"getup":
			if remainingSleepTime <= 0:
				if multiplayer.is_server():
					startedWorking.emit(UID)
			else:
				wentToSleep.emit(UID)
		"liedown":
			animation("sleep")
		"land":
			if multiplayer.is_server():
				startedWorking.emit(UID)

func setState(to):
	match int(state):
		State.FALLING:
			$FallingScreamSound.stop()
	state = to

func dropTarget() -> Vector2:
	return global_position

func _on_TreatArea_treat_eaten():
	if not multiplayer.is_server():
		return
	treatEaten.emit(UID)
	remainingHits = Data.of(teamId + ".drillbot.amount") + Data.of(teamId + ".drillbot.buffextraamount")
	remainingBuffedHits = Data.of(teamId + ".drillbot.buffamount")
	speed = Data.of(teamId + ".drillbot.buffstrength")
	Backend.event("gadget_used", {"gadget": "drillbot", "activity": "treated"})

func eatTreat() -> void :
	if state == State.SLEEPING:
		wakeUp()
	$TreatEatenSound.startSound()

func _on_Sprite_frame_changed():
	if $Sprite2D.animation == "sleep" and $Sprite2D.frame == 14:
		$SleepingSound.startSound()
	elif $Sprite2D.animation == "walk" and $Sprite2D.frame % 2 == 0:
		var d = FootstepDust.instantiate()
		if Level.viewports:
			Level.viewports.addElement(d)
		d.global_position = global_position
		d.flip_h = $Sprite2D.flip_h
		for sound in stepSounds:
			if not sound.playing:
				sound.startSound()
				return
		var sound = stepSounds.front().duplicate()
		add_child(sound)
		stepSounds.append(sound)
		sound.startSound()


func getRemainingSleepTime() -> float:
	return remainingSleepTime

func _on_VisibilityNotifier2D_screen_entered():
	isOnScreen = true

func _on_VisibilityNotifier2D_screen_exited():
	isOnScreen = false

func showNavigationArrow(requester):
	if not arrowsByRequester.has(requester):
		addArrow(requester)

func hideNavigationArrow(requester):
	if arrowsByRequester.has(requester):
		eraseArrow(requester)

func addArrow(requester):
	var arrow = Sprite2D.new()
	arrow.texture = preload("res://content/gadgets/drillbot/arrow.png")
	arrow.z_index = 50
	get_parent().add_child(arrow)
	Style.init(arrow)
	arrowsByRequester[requester] = arrow

func eraseArrow(requester):
	arrowsByRequester[requester].queue_free()
	arrowsByRequester.erase(requester)

func asPlayerControlled():
	if playerControlled:
		return
	playerControlled = true
	hitStrengthMod = 2.0
	add_to_group("secondary-keeper")

func jump():
	if isPlane():
		apply_central_impulse(Vector2.UP * 280 * gravity_scale)
	return true

func setDrillDown(do):
	drillDown = do

func currentSpeed():
	return 100

func setSkin(skinId: String):
	$Sprite2D.sprite_frames = load("res://content/gadgets/drillbot/frames" + skinId + ".tres")
	push_warning("setskin")

func unlockGadget(data):
	pass

func startInput():
	var i = preload("res://content/gadgets/drillbot/DrillbertInputProcessor.gd").new()
	i.keeper = self
	i.playerId = playerId
	i.deviceId = Keepers.getKeeper(playerId).deviceId
	i.integrate(self)

func kill():
	remove()
	queue_free()

func remove():
	visible = false
