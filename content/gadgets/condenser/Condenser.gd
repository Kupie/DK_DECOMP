extends "res://content/gadgets/CellarGadget.gd"

signal state_changed

@export var synchronizer: GadgetSynchronizer

var producing: = false
var resourceCount: = 0
var inTransition: = false
var growth: = 0.0
var grownAfter: = 0.0
var additionalGrownAfter: = 0.0
var particleCooldown: = 0.0
var autoCollectDelay: = 0.0

var CondensingParticles

func _ready():
	$ResourcePosition / FinishedParticles.emitting = false
	if $Sprite2D.flip_h:
		CondensingParticles = preload("res://content/gadgets/condenser/CondensingParticlesLeft.tscn").instantiate()
		add_child(CondensingParticles)
	else:
		CondensingParticles = preload("res://content/gadgets/condenser/CondensingParticlesRight.tscn").instantiate()
		add_child(CondensingParticles)

	if multiplayer.is_server():
		finishProduction()

	$Amb.startSound()

	Style.init(self)

	Achievements.addIfOpen(self, "CONDENSER_USE", teamId)

func serialize() -> Dictionary:
	var data = super.serialize()
	data["producing"] = producing
	data["resourceCount"] = resourceCount
	data["inTransition"] = inTransition
	data["growth"] = growth
	data["grownAfter"] = grownAfter
	data["additionalGrownAfter"] = additionalGrownAfter
	data["particleCooldown"] = particleCooldown
	data["autoCollectDelay"] = autoCollectDelay
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	producing = data["producing"]
	resourceCount = data["resourceCount"]
	inTransition = data["inTransition"]
	growth = data["growth"]
	grownAfter = data["grownAfter"]
	additionalGrownAfter = data["additionalGrownAfter"]
	particleCooldown = data["particleCooldown"]
	autoCollectDelay = data["autoCollectDelay"]

	if inTransition:
		$Sprite2D.play("idle")
		addWater()

	if producing:
		playProducingVisuals()
	else:
		$Sprite2D.play("idle")
		CondensingParticles.emitting = false

	updateResourceVisuals()

func get_gadget_state() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_bool(producing)
	stream.encode_u8(resourceCount)
	return stream.data

func set_gadget_state(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	producing = stream.decode_bool()
	resourceCount = stream.decode_u8()


	updateResourceVisuals()
	$Usable.updateFocus()

func _process(delta):
	if GameWorld.softPaused(teamId):
		return

	if not multiplayer.is_server():
		return




	if Data.of(teamId + ".condenser.autoCollect") and resourceCount > 0:
		autoCollectDelay += delta
		if autoCollectDelay >= 1.0:
			Data.changeByInt(teamId + ".inventory.water", resourceCount)
			Data.changeByInt("inventory.totalwater", 1)
			resourceCount = 0
			state_changed.emit()
			synchronizer.network_rpc(playCollectVisuals, true)

	if producing:
		if additionalGrownAfter > 0.0:
			additionalGrownAfter -= delta * GameWorld.cycleSpeed
		elif growth < grownAfter:
			growth += delta * GameWorld.cycleSpeed
		else:
			synchronizer.network_rpc(finishProduction, true)
			return
	elif resourceCount < Data.of(teamId + ".condenser.waterstorage"):
		synchronizer.network_rpc(playProducingVisuals, true)
		producing = true
		growth = 0.0
		grownAfter = GameWorld.getTimeBetweenWaves(teamId) * float(Data.of(teamId + ".condenser.growthTime"))

	if Data.of(teamId + ".condenser.autoovercharge"):
		for o in get_tree().get_nodes_in_group("overchargable"):
			if o.teamId == teamId and o.canOvercharge():

				Data.changeByInt(teamId + ".inventory.water", 1)
				o.overcharge()
				additionalGrownAfter = Data.of(teamId + ".condenser.overchargeDelay") * GameWorld.getTimeBetweenWaves(teamId)
				return

@rpc("reliable")
func playCollectVisuals() -> void :
	$Sprite2D.play("active")
	$Water1.hide()
	$Water2.hide()
	$WaterPickup.startSound()
	$ResourcePosition / FinishedParticles.emitting = false
	$Usable.updateFocus()

@rpc("reliable")
func playProducingVisuals() -> void :
	$ResourcePosition / FinishedParticles.emitting = false
	$Sprite2D.play("active")
	$Active.startSound()
	CondensingParticles.emitting = true

func updateResourceVisuals() -> void :
	if resourceCount >= 1:
		$Water1.show()
		if resourceCount >= 2:
			$Water2.show()
		else:
			$Water2.hide()
	else:
		$Water1.hide()
		$Water2.hide()

@rpc("reliable")
func finishProduction():
	resourceCount += 1
	CondensingParticles.emitting = false
	producing = false
	inTransition = true
	$Sprite2D.play("idle")
	updateResourceVisuals()
	$WaterSpawn.startSound()
	$Active.stop()
	addWater()

func canFocusUse(keeper: Keeper) -> bool:
	return resourceCount >= 1

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if resourceCount >= 1:
		synchronizer.network_rpc(registerHit.bind(keeper.playerId), true)
		return true

	return false

@rpc("reliable", "any_peer")
func registerHit(playerId: String):
	if resourceCount >= 1:
		playCollectVisuals()

		if multiplayer.is_server():
			for _i in range(0, resourceCount):
				Level.drops.network_spawn({
					"type": CONST.WATER, 
					"position": $ResourcePosition.global_position, 
					"carriers": [playerId], 
					"teamId": [teamId], 
				})

			resourceCount = 0
			Backend.event("gadget_used", {"gadget": "condenser"})
			state_changed.emit()

func addWater():
	inTransition = false
	autoCollectDelay = 0.0
	$ResourcePosition / FinishedParticles.emitting = true
	$Usable.updateFocus()
