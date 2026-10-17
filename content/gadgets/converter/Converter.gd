extends "res://content/gadgets/CellarGadget.gd"

signal state_changed

@export var synchronizer: GadgetSynchronizer

enum ResourceType{NONE, IRON, WATER, SAND}

enum ConversionType{NONE, WATER_TO_IRON, IRON_PER_WATER, COBALT_TO_IRON, IRON_PER_COBALT, IRON_TO_IRON}


enum State{IDLE, PROCESSING, OPENING, READY}
var state: int = State.IDLE

var queueCooldown: = 0.0
var processingCountdown: = 0.0
var producedResource: ResourceType = ResourceType.NONE
var producedAmount: int
var lastConversion: ConversionType = ConversionType.NONE

var emitAmount: int
var emitResource: ResourceType = ResourceType.NONE
var emitAttached: bool

func _ready():
	$Sprite2D.play("idle")
	$Overlay.visible = false
	$ResourcePosition / Resource.visible = false

	if not SaveGame.currentLoadingSavegame:
		Data.apply(teamId + ".converter.queueselected", false)
	Data.listen(self, teamId + ".converter.queueselected")

	Style.init(self)

	Achievements.addIfOpen(self, "CONVERTER_USE", teamId)

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".converter.queueselected":
		if state == State.IDLE and not newValue:
			lastConversion = ConversionType.NONE

func serialize() -> Dictionary:
	var data = super.serialize()
	data["state"] = state
	data["processingCountdown"] = processingCountdown
	data["producedResource"] = producedResource
	data["producedAmount"] = producedAmount
	data["emitAmount"] = emitAmount
	data["emitResource"] = emitResource
	data["lastConversion"] = lastConversion
	data["emitAttached"] = emitAttached
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	state = int(data["state"])
	processingCountdown = data["processingCountdown"]
	producedResource = data["producedResource"]
	producedAmount = data["producedAmount"]
	lastConversion = data["lastConversion"]
	emitAmount = data["emitAmount"]
	emitResource = data["emitResource"]
	emitAttached = data["emitAttached"]

	if emitAmount > 0:
		create_tween().tween_callback(tryEmitGradually).set_delay(0.5)

	updateStation()

func get_gadget_state() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_u8(int(state))
	stream.encode_float(processingCountdown)
	stream.encode_u8(producedResource)
	stream.encode_u8(producedAmount)
	stream.encode_u8(int(lastConversion))
	stream.encode_u8(emitAmount)
	stream.encode_u8(emitResource)
	stream.encode_bool(emitAttached)
	return stream.data

func set_gadget_state(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	state = stream.decode_u8() as State
	processingCountdown = stream.decode_float()
	producedResource = stream.decode_u8() as ResourceType
	producedAmount = stream.decode_u8()
	lastConversion = stream.decode_u8() as ConversionType
	emitAmount = stream.decode_u8()
	emitResource = stream.decode_u8() as ResourceType
	emitAttached = stream.decode_bool()

	updateStation()

func updateStation() -> void :
	if state == State.IDLE:
		$ResourcePosition / Resource.visible = false
		$Sprite2D.play("idle")
		$Overlay.visible = false

	if state == State.PROCESSING:
		$Sprite2D.play("active")

	if state == State.OPENING:
		$Sprite2D.play("release")

	if state == State.READY:
		$Sprite2D.play("ready")
		$Overlay.visible = true
		$ResourcePosition / Resource.texture = Data.DROP_ICONS.get(resourceTypeToString(producedResource))
		$ResourcePosition / Resource.visible = true

func _process(delta):
	if GameWorld.softPaused(teamId):
		return

	if not multiplayer.is_server():
		if processingCountdown > 0.0:
			processingCountdown -= delta * GameWorld.cycleSpeed
		return

	match int(state):
		State.IDLE:
			if queueCooldown > 0.0:
				queueCooldown -= delta
			elif Data.of(teamId + ".converter.queueselected"):
				tryQueuedConversion()
			else:
				lastConversion = ConversionType.NONE
		State.PROCESSING:
			if processingCountdown > 0.0:
				processingCountdown -= delta * GameWorld.cycleSpeed
			else:
				synchronizer.network_rpc(setOpening, true)
		State.OPENING:
			pass
		State.READY:
			if queueCooldown > 0.0:
				queueCooldown -= delta
			elif Data.of(teamId + ".converter.queueselected"):
				emitResources(false)
				tryQueuedConversion()

@rpc("reliable")
func setOpening() -> void :
	$Sprite2D.play("release")
	$FinishedSound.startSound()
	state = State.OPENING

func canFocusUse(keeper: Keeper) -> bool:
	return true

func useHold(keeper: Keeper) -> bool:
	return false

func useHit(keeper: Keeper) -> bool:
	if state == State.READY:
		synchronizer.network_rpc(emitResourcesAndUpdateVisuals.bind(keeper != null), true)
		return true
	else:
		var i = preload("res://content/shared/SelectionPopupInputProcessor.gd").new()
		var popup = preload("res://content/gadgets/converter/ConverterPopup.tscn").instantiate()
		popup.teamId = teamId
		if state != State.IDLE:
			popup.setCurrentConversion(conversionTypeToString(lastConversion), processingCountdown)
		i.deviceId = keeper.deviceId
		Level.stage.showPopup(popup, keeper)
		popup.moveIn()
		i.popup = popup
		i.blockStickMove = true
		i.blockAllKeys = true
		i.connect("onStop", Level.stage.unpause)
		i.connect("onStop", popup.moveOut)
		i.popup.connect("conversion_selected", i.trySelectOption)
		i.connect("option_selected", conversionSelected)
		i.popup.queue_selected.connect(queueSelected)
		i.integrate(self)
		Level.stage.pause()
		return true

@rpc("reliable", "any_peer")
func emitResourcesAndUpdateVisuals(_emitAttached: bool) -> void :
	if state == State.IDLE:
		return

	emitResources(_emitAttached)
	$Overlay.visible = false
	idle()
	queueCooldown = 2.0
	Backend.event("gadget_used", {"gadget": "converter"})

func idle():
	$Sprite2D.play("idle")
	state = State.IDLE
	$ResourcePosition / Resource.visible = false

	if multiplayer.is_server():
		state_changed.emit()

func emitResources(_emitAttached: bool):
	emitAttached = _emitAttached
	emitAmount = producedAmount
	emitResource = producedResource
	tryEmitGradually()

func tryEmitGradually():
	if not multiplayer.is_server():
		return

	if emitAmount <= 0:
		emitAttached = false
		return

	if not GameWorld.paused:
		var dome: Dome = Level.domesByTeamId[teamId]
		var positionRelativeToDome: Vector2 = $ResourcePosition.global_position - dome.global_position
		var spawnData: = {
			"type": resourceTypeToString(emitResource), 
			"position": $ResourcePosition.global_position, 
			"impulse": Vector2( - positionRelativeToDome.x, randf_range(-20, 20)), 
			"gravity_scale": 0, 
			"linear_damp": 1
		}

		if emitAttached:
			var keeper = Keepers.getClosestKeeper($ResourcePosition.global_position)
			if keeper:
				spawnData["carriers"] = [keeper.playerId]

		Level.drops.network_spawn(spawnData)





		emitAmount -= 1

	create_tween().tween_callback(tryEmitGradually).set_delay(0.1 if emitAttached else 0.8)

func conversionSelected(conversion: Control):
	var data: = {
		"lastConversion" = stringToConversionType(conversion.id), 
		"processingCountdown" = conversion.time * GameWorld.getTimeBetweenWaves(teamId), 
		"consumedResource" = stringToResourceType(conversion.from), 
		"producedResource" = stringToResourceType(conversion.to), 
		"consumedAmount" = conversion.resourcesIn, 
		"producedAmount" = conversion.resourcesOut
	}

	synchronizer.rpc_server(serverApplyConversion.bind(data))

@rpc("reliable", "any_peer")
func serverApplyConversion(conversionData: Dictionary) -> void :
	if state == State.PROCESSING:
		return

	var consumedResource = resourceTypeToString(conversionData["consumedResource"])
	var consumedAmount = conversionData["consumedAmount"]

	Data.changeByInt(teamId + ".inventory." + consumedResource, - consumedAmount)
	lastConversion = conversionData["lastConversion"]
	processingCountdown = conversionData["processingCountdown"]
	producedResource = conversionData["producedResource"]
	producedAmount = conversionData["producedAmount"]

	state = State.PROCESSING
	state_changed.emit()

	synchronizer.network_rpc(playConverterActiveAnimation, true)

	Backend.event("converter", {"from": consumedResource, "in": consumedAmount, "to": resourceTypeToString(producedResource), "out": producedAmount})

@rpc("reliable")
func playConverterActiveAnimation() -> void :
	state = State.PROCESSING
	$ResourcePosition / Resource.visible = false
	$Sprite2D.play("active")
	$ActiveAmb.startSound()
	$StartSound.startSound()

func tryQueuedConversion():
	if lastConversion == ConversionType.NONE:
		idle()
		return
	var con = getConversion(conversionTypeToString(lastConversion))
	if con and con.canBeSelected():
		conversionSelected(con)
	else:
		idle()
	queueCooldown = 1.0

func getConversion(id: String):
	var ratio = Data.of(teamId + ".converter." + id)
	var isPer = id.find("per") != -1
	var split = id.split("per") if isPer else id.split("to")
	var con = preload("res://content/gadgets/converter/Conversion.tscn").instantiate()
	con.teamId = teamId
	var from = split[0]
	var to = split[1]


	var time
	var s = teamId + ".converter." + from + to + "time"
	if Data.has(s):
		time = Data.of(s)
	else:
		s = teamId + ".converter." + to + from + "time"
		if Data.has(s):
			time = Data.of(s)
		else:
			return null


	if from == "cobalt":
		from = "sand"
	if to == "cobalt":
		to = "sand"
	con.setConversion(id, from, to, ratio if isPer else 1, 1 if isPer else ratio, time)
	return con

func _on_sprite_2d_animation_looped() -> void :
	_SpriteAnimationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_SpriteAnimationFinishedCheck()

func queueSelected(value: bool) -> void :
	synchronizer.rpc_server(serverApplyQueueSelected.bind(value))

@rpc("reliable", "any_peer")
func serverApplyQueueSelected(value: bool) -> void :
	Data.apply(teamId + ".converter.queueselected", value)

func _SpriteAnimationFinishedCheck() -> void :
	if $Sprite2D.animation == "release":
		$Sprite2D.play("ready")
		$Overlay.visible = true
		state = State.READY
		$ResourcePosition / Resource.texture = Data.DROP_ICONS.get(resourceTypeToString(producedResource))
		$ResourcePosition / Resource.visible = true
		$ActiveAmb.stop()
		if Data.of(teamId + ".converter.queueselected"):
			queueCooldown = 2.0

func resourceTypeToString(resourceType: ResourceType) -> String:
	match resourceType:
		ResourceType.NONE:
			return ""
		ResourceType.IRON:
			return CONST.IRON
		ResourceType.WATER:
			return CONST.WATER
		ResourceType.SAND:
			return CONST.SAND
		_:
			return ""

func stringToResourceType(resourceString: String) -> ResourceType:
	match resourceString:
		"":
			return ResourceType.NONE
		CONST.IRON:
			return ResourceType.IRON
		CONST.WATER:
			return ResourceType.WATER
		CONST.SAND:
			return ResourceType.SAND
		_:
			return ResourceType.NONE

func conversionTypeToString(conversion: ConversionType) -> String:
	match conversion:
		ConversionType.WATER_TO_IRON:
			return "watertoiron"
		ConversionType.IRON_PER_WATER:
			return "ironperwater"
		ConversionType.COBALT_TO_IRON:
			return "cobalttoiron"
		ConversionType.IRON_TO_IRON:
			return "irontoiron"
		ConversionType.IRON_PER_COBALT:
			return "ironpercobalt"
		_:
			return ""

func stringToConversionType(conversionString: String) -> ConversionType:
	match conversionString:
		"watertoiron":
			return ConversionType.WATER_TO_IRON
		"ironperwater":
			return ConversionType.IRON_PER_WATER
		"cobalttoiron":
			return ConversionType.COBALT_TO_IRON
		"ironpercobalt":
			return ConversionType.IRON_PER_COBALT
		"irontoiron":
			return ConversionType.IRON_TO_IRON
		_:
			return ConversionType.NONE
