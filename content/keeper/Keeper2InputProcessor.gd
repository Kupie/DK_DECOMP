extends "res://content/keeper/KeeperInputProcessor.gd"

var mineKeyDown: = false
var mineHold: = false
var mineKeyDownTime: = 0.0

var collectKeyDown: = false
var collectHold: = false
var collectKeyDownTime: = 0.0

func clearInput():
	super.clearInput()

	if not is_instance_valid(keeper):
		return
	if collectKeyDown and collectHold:
		keeper.collectRelease()

	if mineKeyDown and mineHold:
		keeper.ballRelease()

	mineKeyDownTime = 0.0
	collectKeyDownTime = 0.0
	mineKeyDown = false
	mineHold = false
	collectKeyDown = false
	collectHold = false

func _process(delta):
	super._process(delta)
	if GameWorld.paused or desintegrating:
		return

	if collectKeyDown and not collectHold and not useHoldHandled:
		collectKeyDownTime += delta

		if keeper.wasHolding() or collectKeyDownTime > 0.3:
			keeper.collectHold()
			collectHold = true

	if mineKeyDown and not mineHold:
		mineKeyDownTime += delta
		if mineKeyDownTime > 0.3:
			keeper.ballHold()
			mineHold = true

func keeperButtonEvent(event, handled: bool):
	if GameWorld.paused or desintegrating:
		return

	if keeper.disabled and \
	(justPressed(event, "keeper2_gravityball") or \
	justPressed(event, "keeper2_gravitycollect")):


		if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
			keeper.useTryCancelDisable()
			useKeyDown = false
			return

	if pressed(event, "keeper2_gravityball"):
		mineKeyDown = true
	elif released(event, "keeper2_gravityball"):
		if mineKeyDown:
			mineKeyDownTime = 0.0
			mineKeyDown = false
			if mineHold:
				keeper.ballRelease()
				mineHold = false
			elif not handled:
				keeper.ballHit()
	elif pressed(event, "keeper2_gravitycollect"):
		collectKeyDown = true
	elif released(event, "keeper2_gravitycollect"):
		if collectKeyDown:
			collectKeyDownTime = 0.0
			collectKeyDown = false
			if collectHold:
				keeper.collectRelease()
				collectHold = false
			elif not handled:
				keeper.collectHit()


func becameLeaf():
	super.becameLeaf()
	if Keepers.getLocalMouseUser() == keeper:
		GameWorld.setShowMouse(( not runningInLoadout and keeper.input_settings.use_mouse) or (runningInLoadout and Options.useMouseMenus))
		InputSystem.changeCursor("crosshairs")
