extends "res://content/keeper/KeeperInputProcessor.gd"
const INTERACT_HOLD_THRESHOLD: = 0.3
const HOLD_TO_PICKUP_ACTION = "keeper3_pickup"

var throwKeyDown: = false
var throwKeyDownTime: = 0.0
var throwHoldTriggered: = false
const THROW_HOLD_THRESHOLD: = 0.3
const THROW_DOUBLE_TAP_THRESHOLD: = 0.1

var ropeKeyDownForHook: = false
var _is_double_click_press: = false
var _carrier_deploy_pending: = false
var _carrier_deploy_time: = 0.0

var _pickupKeyDownTime = 0.0
var _pickupKeyDown = false
var _pickupHold: = false
var _pickupKeyCooldown: = 0.0
var _pickup_blocked: = false


func becameLeaf():
	super.becameLeaf()

	var show_mouse: bool = is_instance_valid(keeper) and ( not Options.useGamepad(keeper.deviceId))
	GameWorld.setShowMouse(( not runningInLoadout and show_mouse) or (runningInLoadout and Options.useMouseMenus))
	InputSystem.changeCursor("crosshairs")
	if is_instance_valid(keeper):
		keeper.enableHookDetach()


func setShowMouse() -> void :
	if is_instance_valid(keeper) and Options.useGamepad(keeper.deviceId):
		return
	GameWorld.setShowMouse(true)

func notLeaf():
	if is_instance_valid(keeper):
		keeper.disableHookDetach()
	super.notLeaf()

func clearInput():
	super.clearInput()
	throwKeyDown = false
	throwHoldTriggered = false
	throwKeyDownTime = 0.0
	ropeKeyDownForHook = false
	_is_double_click_press = false
	_carrier_deploy_pending = false
	_pickupKeyDown = false
	_pickupHold = false
	_pickup_blocked = false
	if is_instance_valid(keeper):
		keeper.justPressedUp = false
		keeper.pressingUp = false
		keeper.pressingThrow = false
		keeper.autoShoot = false
		keeper.releaseHookInput()

func _process(delta):
	if useKeyDown and not useHoldHandled and is_instance_valid(keeper):
		if keeper.focussedUsable and is_instance_valid(keeper.focussedUsable):
			if keeper.focussedUsable.get_parent() is SideDriller:
				useHoldHandled = keeper.useHold()
				useHold = true
	super._process(delta)
	if GameWorld.paused:
		return

	if throwKeyDown and not keeper.drillClimbActive:
		throwKeyDownTime += delta
		if not throwHoldTriggered and throwKeyDownTime >= THROW_HOLD_THRESHOLD:
			throwHoldTriggered = true
			if _is_double_click_press:
				keeper.throwShuriken()
			else:
				keeper.startAutoShoot()

	if _carrier_deploy_pending and not keeper.drillClimbActive:
		var current_time: = Time.get_ticks_msec() / 1000.0
		if current_time - _carrier_deploy_time >= THROW_DOUBLE_TAP_THRESHOLD:
			_carrier_deploy_pending = false
			if keeper.deploySingleCarrier():
				_pickup_blocked = true

	if _pickupKeyDown and not useHoldHandled and not _pickup_blocked:
		_pickupKeyDownTime += delta
		if _pickupKeyDownTime > 0.3:
			keeper.pickupHold()
			_pickupHold = true

			_pickupKeyDownTime -= _pickupKeyCooldown
			_pickupKeyCooldown = max(0.06, _pickupKeyCooldown * 0.6)
	else:
		_pickupKeyCooldown = INTERACT_HOLD_THRESHOLD

func buttonEvent(event) -> bool:
	if event.is_action("ui_select") and event.is_action("keeper3_jump"):

		keeperButtonEvent(event, false)
		return false
	return super.buttonEvent(event)

func keeperButtonEvent(event, handled: bool):
	if GameWorld.paused:
		return false

	if not keeper or not is_instance_valid(keeper):
		return

	if keeper.disabled and justPressed(event, "keeper3_throw"):
		if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
			keeper.useTryCancelDisable()
			return

	if keeper.drillClimbActive:
		if justPressed(event, "keeper3_jump"):
			if not keeper.pressingUp:
				keeper.justPressedUp = true
			keeper.pressingUp = true
		elif released(event, "keeper3_jump"):
			keeper.pressingUp = false
		elif released(event, "keeper3_throw"):
			keeper.pressingThrow = false
			keeper.autoShoot = false
			throwKeyDown = false
			throwKeyDownTime = 0.0
			throwHoldTriggered = false
		elif released(event, HOLD_TO_PICKUP_ACTION):
			_pickupKeyDown = false
			_pickupKeyDownTime = 0.0
			if _pickupHold:
				keeper.pickupHoldStopped()
				_pickupHold = false
		return

	var has_focus: bool = keeper.has_meaningful_focus() if keeper else false
	var use_priority: bool = has_focus and event.is_action("ui_select")
	var throw_use_priority: bool = use_priority and keeper.carriedCarryables.is_empty()

	if justPressed(event, "keeper3_throw") and not throwKeyDown:
		if _carrier_deploy_pending:
			_carrier_deploy_pending = false
			_is_double_click_press = true
		else:
			_is_double_click_press = false
		keeper.onThrowPressed()
		keeper.pressingThrow = true
		throwKeyDown = true
		throwKeyDownTime = 0.0
		throwHoldTriggered = false
		if not throw_use_priority:
			useKeyDown = false
	elif released(event, "keeper3_throw"):
		keeper.pressingThrow = false
		var was_throw_key_down: = throwKeyDown
		throwKeyDown = false
		useKeyDown = false
		if throwHoldTriggered:
			if not _is_double_click_press:
				keeper.autoShoot = false
			throwHoldTriggered = false
		elif was_throw_key_down and not throw_use_priority:
			if _is_double_click_press:
				keeper.throwShuriken()
			else:
				keeper.latchDropCarryablesIntent()
				_carrier_deploy_pending = true
				_carrier_deploy_time = Time.get_ticks_msec() / 1000.0

	if justPressed(event, "keeper3_jump"):
		if not keeper.pressingUp:
			keeper.justPressedUp = true
		keeper.pressingUp = true
	elif released(event, "keeper3_jump"):
		keeper.pressingUp = false

	if justPressed(event, "keeper3_rope") and not use_priority:
		ropeKeyDownForHook = true
		keeper.throwHook()
	elif released(event, "keeper3_rope"):
		ropeKeyDownForHook = false
		keeper.releaseHookInput()

	var pickupExclusive: bool = isPickupExclusive(event)
	if pickupExclusive and justPressed(event, HOLD_TO_PICKUP_ACTION):
		_pickupKeyDownTime = 0.0
		_pickupKeyDown = true
		_pickup_blocked = false
	if released(event, HOLD_TO_PICKUP_ACTION):
		if _pickupKeyDown:
			_pickupKeyDown = false
			if _pickupHold and pickupExclusive:
				keeper.pickupHoldStopped()
				_pickupHold = false
			elif not handled and not GameWorld.paused and not useHoldHandled:
				if pickupExclusive:
					keeper.pickupHit()
				_pickupKeyDownTime = 0.0


func isPickupExclusive(inEvent: InputEvent) -> bool:
	var exclusive: bool = inEvent.is_action(HOLD_TO_PICKUP_ACTION)
	exclusive = exclusive and not inEvent.is_action("keeper3_jump")
	exclusive = exclusive and not inEvent.is_action("keeper3_rope")
	exclusive = exclusive and not inEvent.is_action("keeper3_throw")
	return exclusive
