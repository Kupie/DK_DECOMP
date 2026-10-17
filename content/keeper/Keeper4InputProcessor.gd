extends "res://content/keeper/KeeperInputProcessor.gd"

const HOLD_TO_PICKUP_ACTION = "ui_select"
const PICKUP_HOLD_THRESHOLD: = 0.3

var dropKeyDown: = false
var dropHold: = false
var dropKeyDownTime: = 0.0
var dropKeyCooldown: = 0.0

var holeKeyDown: = false

var _pickupKeyDownTime: = 0.0
var _pickupKeyDown: = false
var _pickupHold: = false
var _pickupKeyCooldown: = 0.0
var _pickup_blocked: = false

func clearInput():
	super.clearInput()
	_pickupKeyDown = false
	_pickupHold = false
	_pickup_blocked = false
	dropKeyDown = false
	dropHold = false

func _process(delta):
	super._process(delta)
	if GameWorld.paused or desintegrating or not is_instance_valid(keeper):
		return

	if keeper.isSpawningHole:
		return

	if keeper.isMiningMode:
		var moveInput = keeper.moveDirectionInput
		if moveInput.length() < 0.1:
			keeper.networkStopMining()
		elif keeper.currentMiningDirection.length() > 0:
			var dot_val = moveInput.dot(keeper.currentMiningDirection)
			if dot_val < 0.2:
				keeper.networkStopMining()

	if keeper and not keeper.isMiningMode and not keeper.isSpawningHole:
		_check_movement_towards_mineable(delta)

	if _pickupKeyDown and not useHoldHandled and not _pickup_blocked:
		_pickupKeyDownTime += delta
		if _pickupKeyDownTime > PICKUP_HOLD_THRESHOLD:
			keeper.pickupHold()
			_pickupHold = true
			_pickupKeyDownTime -= _pickupKeyCooldown
			_pickupKeyCooldown = max(0.06, _pickupKeyCooldown * 0.6)
	else:
		_pickupKeyCooldown = PICKUP_HOLD_THRESHOLD

	if dropKeyDown and not holeKeyDown:
		dropKeyDownTime += delta
		if dropKeyDownTime > 0.3 and keeper.carriedCarryables.size() > 0:
			keeper.dropHold()
			dropHold = true
			_pickup_blocked = true
			dropKeyDownTime -= dropKeyCooldown
			dropKeyCooldown = max(0.05, dropKeyCooldown * 0.6)
	else:
		dropKeyCooldown = 0.25

func notLeaf():
	super.notLeaf()
	_pickupKeyDown = false
	_pickupHold = false
	if holeKeyDown:
		holeKeyDown = false
		if keeper:
			keeper.networkStopHolePunch()
	_update_mouse_visibility(false)

func becameLeaf():
	super.becameLeaf()
	_update_mouse_visibility(true)

func keeperButtonEvent(event, handled: bool):
	if keeper and keeper.disabled and justPressed(event, "keeper4_drop"):
		keeper.useTryCancelDisable()
		return

	if released(event, "keeper4_portal"):
		_pickupReleaseCheck(event, handled)
		return

	if released(event, "keeper4_drop") and holeKeyDown:
		holeKeyDown = false
		dropKeyDown = false
		if keeper:
			keeper.networkStopHolePunch()
		return

	if keeper and keeper.isSpawningHole:
		return

	elif justPressed(event, "keeper4_drop"):
		dropKeyDownTime = 0.0
		dropHold = false
		dropKeyDown = true
		if keeper and keeper.carriedCarryables.size() == 0 and not keeper.isInsideDome:
			holeKeyDown = true
			keeper.networkStartHolePunch()

	if released(event, "keeper4_drop"):
		if dropKeyDown:
			dropKeyDown = false
			if not handled and not dropHold and not GameWorld.paused:
				if keeper.carriedCarryables.size() > 0:
					keeper.dropHit()
					_pickup_blocked = true
				dropKeyDownTime = 0.0

	if justPressed(event, HOLD_TO_PICKUP_ACTION):
		_pickupKeyDownTime = 0.0
		_pickupKeyDown = true
		_pickup_blocked = false

	_pickupReleaseCheck(event, handled)

func _pickupReleaseCheck(event: InputEvent, handled: bool) -> void :
	if not keeper:
		return
	if released(event, HOLD_TO_PICKUP_ACTION):
		if _pickupKeyDown:
			_pickupKeyDown = false
			if _pickupHold:
				keeper.pickupHoldStopped()
				_pickupHold = false
			elif not handled and not GameWorld.paused and not useHoldHandled:
				keeper.pickupHit()
				_pickupKeyDownTime = 0.0

func onInputMethodChanged():
	super.onInputMethodChanged()
	_update_mouse_visibility(true)

func _update_mouse_visibility(forceShow: bool):
	var shouldShow = ( not runningInLoadout and Options.useMouseKeeperGameplay and not Options.useGamepad) or (runningInLoadout and Options.useMouseMenus)
	if forceShow and shouldShow:
		GameWorld.setShowMouse(true)
		InputSystem.changeCursor("crosshairs")
	elif not shouldShow:
		GameWorld.setShowMouse(false)

func buttonEvent(event) -> bool:
	return super.buttonEvent(event)

func stick_move(event: InputEventJoypadMotion) -> bool:
	return super.stick_move(event)

func _check_movement_towards_mineable(delta):
	if not keeper or not keeper.has_method("_get_tile_in_direction_for_start"):
		return

	var moveInput: Vector2 = keeper.moveDirectionInput
	if moveInput.length() < 0.1:
		keeper.miningMoveTimer = 0.0
		keeper.lastMiningMoveDirection = Vector2.ZERO
		return

	var cardinal_dir: Vector2 = keeper._normalize_to_cardinal(moveInput)
	if cardinal_dir == Vector2.ZERO:
		keeper.miningMoveTimer = 0.0
		keeper.lastMiningMoveDirection = Vector2.ZERO
		return

	var tile = keeper._get_tile_in_direction_for_start(cardinal_dir)
	if tile and tile.has_meta("destructable") and tile.get_meta("destructable"):
		if keeper.lastMiningMoveDirection.dot(cardinal_dir) > 0.8:
			keeper.miningMoveTimer += delta
			if keeper.miningMoveTimer >= Keeper4GameplaySettings.MINING_TRIGGER_TIME:
				keeper.networkStartMining(cardinal_dir)
				keeper.miningMoveTimer = 0.0
		else:
			keeper.miningMoveTimer = delta
			keeper.lastMiningMoveDirection = cardinal_dir
	else:
		keeper.miningMoveTimer = 0.0
		keeper.lastMiningMoveDirection = Vector2.ZERO

func calculateMoveDirection() -> Vector2:
	if Options.useGamepad:
		return super.calculateMoveDirection()

	var md: = Vector2()
	if Input.is_action_pressed("ui_left"):
		md.x -= 1
	if Input.is_action_pressed("ui_right"):
		md.x += 1
	if Input.is_action_pressed("ui_up"):
		md.y -= 1
	if Input.is_action_pressed("ui_down"):
		md.y += 1

	if md.length() > 1.0:
		md = md.normalized()
	return md
