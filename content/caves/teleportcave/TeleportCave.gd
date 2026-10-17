extends "res://content/caves/Cave.gd"
class_name TeleportCave

var teamId: String

var hasEye: = true
var keeperPlacedEye = null
var forPlayerId: String

var maxCooldown: float
var cooldown: = 0.0
var is_ready: = false
var teleporting: = false
var hud

var action_hint_teleport: = -1

func serialize() -> Dictionary:
	var data = super.serialize()
	data["teamId"] = teamId
	data["hasEye"] = hasEye
	data["forPlayerId"] = forPlayerId
	data["maxCooldown"] = maxCooldown
	data["cooldown"] = cooldown
	data["ready"] = is_ready
	data["teleporting"] = teleporting
	return data


func _ready():
	super._ready()
	await StageManager.stage_started


func deserialize(data: Dictionary):
	super.deserialize(data)

	if currentState == State.REVEALED:
		find_child("Eye").play("default")

	teamId = data.get("teamId", "team1")
	hasEye = data["hasEye"]
	forPlayerId = data["forPlayerId"]
	maxCooldown = data["maxCooldown"]
	cooldown = data["cooldown"]
	is_ready = data["ready"]
	teleporting = data["teleporting"]




	if not hasEye:
		find_child("Eye").queue_free()
		for s in $Sprites.get_children():
			s.frame += 4

		hud = preload("res://content/caves/teleportcave/TeleporterHud.tscn").instantiate()
		Level.addHudElement(hud, forPlayerId)
		await GameWorld.savegame_loaded
		keeperPlacedEye = Level.map.find_child("TeleporterEye", true, false)
		hud.setup(self)

func onRevealed():
	find_child("Eye").play("default")
	find_child("CaveAmb").startSound()

func canFocusUse(keeper: Keeper) -> bool:
	return hasEye

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if hasEye:
		find_child("Eye").play("taken")
		$EyeCloseSound.startSound()
		hasEye = false
		teamId = keeper.teamId
		find_child("CaveAmb").queue_free()
		forPlayerId = keeper.playerId
		return true
	else:
		return false

func _process(delta):
	if GameWorld.softPaused(teamId):
		return
	if hasEye:
		return

	if cooldown > 0.0:
		cooldown -= delta * GameWorld.cycleSpeed
		if cooldown <= 0.0:
			make_ready()
			hud.on_ready()

func _on_eye_animation_looped() -> void :
	_EyeAnimationFinishedCheck()

func _on_Eye_animation_finished() -> void :
	_EyeAnimationFinishedCheck()

func _EyeAnimationFinishedCheck() -> void :
	if find_child("Eye").animation == "taken":
		find_child("Eye").queue_free()
		for s in $Sprites.get_children():
			s.frame += 4

		maxCooldown = Data.of("caveteleporter.cooldown") * GameWorld.getTimeBetweenWaves(teamId)
		make_ready()
		Level.addTutorial(self, "onewayteleporter", teamId)
		hud = preload("res://content/caves/teleportcave/TeleporterHud.tscn").instantiate()
		hud.setup(self)
		Level.addHudElement(hud, forPlayerId)

func make_ready():
	is_ready = true


func executeSpecial2(keeper: Keeper) -> bool:
	if hasEye:
		return false
	if forPlayerId != keeper.playerId:
		return false
	if teleporting or GameWorld.paused:
		return false

	if keeperPlacedEye:
		executeSpecial2Teleport(keeper)
		return true
	elif is_ready and not keeper.isInsideDome:
		keeperPlacedEye = preload("res://content/caves/teleportcave/TeleporterEye.tscn").instantiate()
		keeperPlacedEye.position = keeper.position
		Level.map.add_child(keeperPlacedEye)
		hud.on_placed()
		return true
	return false

func executeSpecial2Teleport(keeper: Keeper):
	teleporting = true
	var shrinkTime: = 0.5
	var transitionTime: float = 0.5
	keeper.startTeleportation(self, shrinkTime, keeper.global_position, keeperPlacedEye.global_position, true)

	await get_tree().create_timer(shrinkTime).timeout

	if teleporting:
		complete_teleport(keeper, false, shrinkTime, transitionTime)

func complete_teleport(keeper: Keeper, abort: bool, shrinkTime, transitionTime):
	keeper.teleportComplete()
	keeper.grow(shrinkTime, transitionTime - 0.2)

	if not abort:
		keeper.teleport(keeperPlacedEye.position)
		hud.on_teleport()
		maxCooldown = Data.of("caveteleporter.cooldown") * GameWorld.getTimeBetweenWaves(teamId)
		cooldown = maxCooldown
		is_ready = false

		keeperPlacedEye.onUsed()
		keeperPlacedEye = null
	else:
		Level.viewports.abortTeleportAnimation(keeper)
	teleporting = false

func keeperWantsToAbort(keeper: Keeper):
	if not teleporting:
		return

	complete_teleport(keeper, true, 0, 0.2)
