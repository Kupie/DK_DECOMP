class_name DrillbotStation
extends "res://content/gadgets/CellarGadget.gd"

signal state_changed

@export var synchronizer: GadgetSynchronizer
@export var drillbots: DrillbotSynchronizer

var hasDrillbot: bool
var hasPlant: = false
var plantGrowth: = 0.0
var keeper
var remainingDrillbots: = 0
var producedBots: = 0

func _ready():
	Style.init(self)
	Data.listen(self, teamId + ".drillbot.headcount", true)
	updateStation()

	Level.addTutorial(self, "drillbotcarry", teamId)

func serialize() -> Dictionary:
	var data = super.serialize()
	data["hasDrillbot"] = hasDrillbot
	data["hasPlant"] = hasPlant
	data["plantGrowth"] = plantGrowth
	data["remainingDrillbots"] = remainingDrillbots
	data["producedBots"] = producedBots
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	hasDrillbot = data["hasDrillbot"]
	hasPlant = data["hasPlant"]
	plantGrowth = data["plantGrowth"]
	remainingDrillbots = data["remainingDrillbots"]

	producedBots = data.get("producedBots", Data.of(teamId + ".drillbot.headcount") - remainingDrillbots)
	updateStation()
	setBotStations.call_deferred()

func setBotStations() -> void :
	var bots = get_tree().get_nodes_in_group(teamId + "-drillbots")
	for bot in bots:
		bot.station = self
		drillbots.network_track_drillbot(bot)

func get_gadget_state() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_bool(hasDrillbot)
	stream.encode_bool(hasPlant)
	stream.encode_float(plantGrowth)
	stream.encode_u8(remainingDrillbots)
	stream.encode_u8(producedBots)

	return stream.data

func set_gadget_state(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	hasDrillbot = stream.decode_bool()
	hasPlant = stream.decode_bool()
	plantGrowth = stream.decode_float()
	remainingDrillbots = stream.decode_u8()
	producedBots = stream.decode_u8()

	updateStation()

func addDrillbot():
	if not hasDrillbot:
		$GlasOverlaySprite.play("open")
		updateStation()
		$Sprite2D.pause()

func propertyChanged(property: String, oldValue, newValue):
	var bots = get_tree().get_nodes_in_group(teamId + "-drillbots")

	if property == teamId + ".drillbot.headcount":
		remainingDrillbots = newValue - producedBots
		updateStation()

	for bot in bots:
		bot.station = self
		addDrillbot()

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func canFocusUse(keeper: Keeper) -> bool:
	return hasDrillbot or hasPlant

func _process(delta):
	if not multiplayer.is_server():
		return

	if hasDrillbot or GameWorld.softPaused(teamId):
		return

	var growthTime = Data.of(teamId + ".drillbot.plantgrowthtime") * GameWorld.getTimeBetweenWaves(teamId)
	if not hasPlant and growthTime > 0.0:
		plantGrowth += delta
		if plantGrowth >= growthTime:
			synchronizer.network_rpc(growPlant, true)
		elif plantGrowth >= growthTime * 0.3 and $Sprite2D.frame != 1:
			synchronizer.network_rpc(growPlantHalfway, true)

@rpc("reliable")
func growPlantHalfway() -> void :
	$Sprite2D.frame = 1

@rpc("reliable")
func growPlant():
	hasPlant = true
	$Sprite2D.frame = 2
	$FruitReadySound.startSound()

func useHit(keeper: Keeper) -> bool:
	if canFocusUse(keeper):
		synchronizer.network_rpc(registerHit.bind(keeper.playerId), true)
		return true
	return false

@rpc("reliable", "any_peer")
func registerHit(playerId: String) -> void :
	var keeper: = Keepers.getKeeper(playerId)
	if hasDrillbot:
		$OpeningSound.startSound()
		hasDrillbot = false
		$Sprite2D.play("open")
		$GlasOverlaySprite.play("open")
		self.keeper = keeper
	elif hasPlant:
		hasPlant = false
		$Sprite2D.frame = 0
		plantGrowth = 0.0

		if multiplayer.is_server():
			Level.drops.network_spawn({
				"type": CONST.TREAT, 
				"position": $DropPosition.global_position, 
				"carriers": [keeper.playerId], 
				"team": teamId
			})

func updateStation():
	hasDrillbot = remainingDrillbots > 0
	if hasDrillbot:
		$Sprite2D.play("idle")
		$GlasOverlaySprite.play("default")
	else:
		$GlasOverlaySprite.play("open")
		$Sprite2D.animation = "plant"
		if hasPlant:
			$Sprite2D.frame = 2
		else:
			$Sprite2D.frame = 0
		$Sprite2D.pause()

func _on_Sprite_animation_finished():
	if keeper and $Sprite2D.animation == "open":
		if multiplayer.is_server():
			var drillbot: Drillbot = Level.drops.network_spawn({
				"type": CONST.DRILLBOT, 
				"team": teamId, 
				"position": $DropPosition.global_position, 
				"carriers": [keeper.playerId], 
			})
			drillbots.network_track_drillbot(drillbot)
			drillbot.setDirection(Vector2.RIGHT if $Sprite2D.flip_h else Vector2.LEFT)


		keeper = null
		remainingDrillbots -= 1
		producedBots += 1
		$Sprite2D.animation = "plant"
		if hasPlant:
			$Sprite2D.frame = 2
		else:
			$Sprite2D.frame = 0
		$Sprite2D.pause()

		updateStation()
