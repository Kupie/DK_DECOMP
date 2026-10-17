extends "res://content/gadgets/CellarGadget.gd"

@export var synchronizer: GadgetSynchronizer

func _ready():
	Style.init(self)

	Data.listen(self, teamId + ".furnace.maxironstack", true)
	Data.listen(self, teamId + ".furnace.maxwaterstack")
	Data.listen(self, teamId + ".furnace.ironstack")
	Data.listen(self, teamId + ".furnace.waterstack")

	if multiplayer.is_server():
		Data.listen(self, teamId + ".monsters.cycle")

	if multiplayer.is_server() and not SaveGame.currentLoadingSavegame:
		Data.apply(teamId + ".furnace.ironstack", 0)
		Data.apply(teamId + ".furnace.waterstack", 0)
		Data.apply(teamId + ".furnace.remainingcycleswaterfuel", 0)
		Data.apply(teamId + ".furnace.remainingcyclesironfuel", 0)
		Data.apply(teamId + ".furnace.isburningiron", false)
		Data.apply(teamId + ".furnace.isburningwater", false)

func cycleWaterStack():
	var remaining = Data.of(teamId + ".furnace.remainingcycleswaterfuel")
	if remaining == 0:
		if Data.of(teamId + ".furnace.waterstack") > 0:
			Data.apply(teamId + ".furnace.isburningwater", true)
			Data.changeByInt(teamId + ".furnace.waterstack", -1)
			Data.changeByInt(teamId + ".furnace.remainingcycleswaterfuel", Data.of(teamId + ".furnace.waterduration"))
		else:
			Data.apply(teamId + ".furnace.isburningwater", false)
			return

	Data.changeByInt(teamId + ".furnace.remainingcycleswaterfuel", -1)
	Data.changeByInt(teamId + ".monsters.wavedelay", Data.of(teamId + ".furnace.waterdelay"))

func cycleIronStack():
	var remaining = Data.of(teamId + ".furnace.remainingcyclesironfuel")
	if remaining == 0:
		if Data.of(teamId + ".furnace.ironstack") > 0:
			Data.apply(teamId + ".furnace.isburningiron", true)
			Data.changeByInt(teamId + ".furnace.ironstack", -1)
			Data.changeByInt(teamId + ".furnace.remainingcyclesironfuel", Data.of(teamId + ".furnace.ironduration"))
		else:
			Data.apply(teamId + ".furnace.isburningiron", false)
			return

	Data.changeByInt(teamId + ".furnace.remainingcyclesironfuel", -1)
	Data.changeByInt(teamId + ".monsters.wavedelay", Data.of(teamId + ".furnace.irondelay"))

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".monsters.cycle":
		if not SaveGame.currentLoadingSavegame:
			cycleIronStack()
			cycleWaterStack()
			Data.changeByInt(teamId + ".monsters.wavedelay", Data.of(teamId + ".furnace.wavedelay"))
	elif property == teamId + ".furnace.ironstack":
		updateIronStack()
	elif property == teamId + ".furnace.waterstack":
		updateWaterStack()
	elif property == teamId + ".furnace.maxironstack":
		if oldValue == null:
			oldValue = 0

		var d = newValue - oldValue
		updateMaxIronStack(abs(d))
	elif property == teamId + ".furnace.maxwaterstack":
		if ( not oldValue or oldValue == 0) and newValue > 0:
			$Sprites.queue_free()
			remove_child($Sprites)
			var sprites = preload("res://content/gadgets/furnace/FurnaceStationDouble.tscn").instantiate()
			add_child(sprites)
			Style.init(sprites)
			if global_position.x < 0:
				flipAll(sprites)
			updateMaxIronStack(Data.of(teamId + ".furnace.maxironstack"))
			oldValue = 0

		var d = newValue - oldValue
		for i in abs(d):
			var stack_count = _waterStack().get_child_count()
			if d > 0:
				var s = Sprite2D.new()
				s.texture = preload("res://content/drop/water/water_smol.png")
				s.position.y = - stack_count * 5
				s.position.x = randi_range(-1, 1) + (stack_count % 2) * 5 * sign(global_position.x)
				_waterStack().add_child(s)
				Style.init(s)
			else:
				_waterStack().get_child(i).queue_free()
		updateWaterStack()

func updateMaxIronStack(d: int):
	for i in abs(d):
		var stack_count = _ironStack().get_child_count()
		if d > 0:
			var s = Sprite2D.new()
			s.texture = preload("res://content/drop/iron/iron_smol.png")
			s.position.y = - stack_count * 5
			s.position.x = randi_range(-1, 1) + (stack_count % 2) * 5 * sign(global_position.x)
			_ironStack().add_child(s)
			Style.init(s)
		else:
			_ironStack().get_child(stack_count - i - 1).queue_free()
	updateIronStack()

func _ironStack():
	return find_child("IronStack", true, false)

func _waterStack():
	return find_child("WaterStack", true, false)

func updateIronStack():
	updateStack(_ironStack(), Data.of(teamId + ".furnace.ironstack"))

func updateWaterStack():
	updateStack(_waterStack(), Data.of(teamId + ".furnace.waterstack"))

func updateStack(root, amount):
	var i: = 0
	for c in root.get_children():
		var shouldBeVisible = i < amount


		if not shouldBeVisible and c.get_meta("will_be_visible", true):
			var prevtween = c.get_meta("tween", null)
			if prevtween:
				prevtween.kill()
			var t = create_tween()
			t.tween_property(c, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_QUAD)
			t.tween_callback(c.set.bind("visible", false))
			c.set_meta("will_be_visible", false)
			c.set_meta("tween", t)
		elif not c.get_meta("will_be_visible", true) and shouldBeVisible:
			var prevtween = c.get_meta("tween", null)
			if prevtween:
				prevtween.kill()
			var t = create_tween()
			t.tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD)
			c.visible = true
			c.set_meta("will_be_visible", true)
			c.set_meta("tween", t)
		i += 1

func canFocusUse(keeper: Keeper) -> bool:
	return Data.of(teamId + ".furnace.maxironstack") > 0

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	var i = preload("res://content/shared/SelectionPopupInputProcessor.gd").new()
	i.endAfterSelection = false
	var popup = preload("res://content/gadgets/furnace/FurnacePopup.tscn").instantiate()
	i.deviceId = keeper.deviceId
	popup.teamId = keeper.teamId
	Level.stage.showPopup(popup, keeper)
	popup.moveIn()
	i.popup = popup
	i.blockStickMove = true
	i.blockAllKeys = true
	i.connect("onStop", Level.stage.unpause)
	i.connect("onStop", popup.moveOut)
	i.popup.connect("fuel_selected", i.trySelectOption)
	i.connect("option_selected", fuelSelected)
	i.integrate(self)
	Level.stage.pause(false)
	return true

func fuelSelected(fuel: Control):
	synchronizer.rpc_server(serverApplyFuel.bind(fuel.resource))

@rpc("reliable", "any_peer")
func serverApplyFuel(fuel_resource: String) -> void :
	var amount = Data.of(teamId + ".furnace.remainingcycles" + fuel_resource + "fuel")
	synchronizer.network_rpc(playFuelSound.bind(fuel_resource), true)
	Data.changeByInt(teamId + ".inventory." + fuel_resource, -1)
	Data.changeByInt(teamId + ".furnace." + fuel_resource + "stack", 1)
	if amount == 0 and not Data.of(teamId + ".furnace.isburning" + fuel_resource):
		call("cycle" + Data.startCaptialized(fuel_resource) + "Stack")

@rpc("reliable", "call_local")
func playFuelSound(fuel_resource: String) -> void :
	if fuel_resource == "iron":
		$AddFuelSoundIron.startSound()
	else:
		$AddFuelSoundWater.startSound()
