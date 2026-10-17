class_name Pet
extends Node2D

signal found_new_place

@export var id: = ""
@export var looksLeft: = false
@export var randomAction: = true
@export var sleepingPositions: = []
@export var emotePositionByAnimationPos: = {}
@export var zIndexByDome: = {}
@export var offsetXWhenFlipped: = 0

var teamId: String
var UID: int

var positions
var supportedPositions: = []
var currentPos: String
var currentActions: = []
var currentActionIndex: int
var currentlyPlayingAudioNode
var unflippedEmoteX: int
var defaultEmotePos: Vector2
var defaultZIndex: int
var hatchedThisRun: bool
var last_idx = 0

var switchCooldown: = 0.0

var random: RandomNumberGenerator

func _ready():
	Style.init(self)

	random = RandomNumberGenerator.new()
	random.seed = UID
	unflippedEmoteX = $EmoteSprite.position.x

	var dome = get_parent()
	var scenePath = "res://content/pets/" + id + "/Positions" + Data.startCaptialized(dome.techId) + ".tscn"
	var scene = load(scenePath)
	if scene:
		positions = scene.instantiate()
		dome.add_child(positions)
	else:
		Logger.error("pet positions missing", "Pet.ready", scenePath)
		queue_free()
		return

	var animatedSprite: AnimatedSprite2D = $Sprite2D as AnimatedSprite2D
	animatedSprite.animation_looped.connect(_on_sprite2d_looped)

	for a in $Sprite2D.sprite_frames.get_animation_names():
		if a.find("idle") != -1:
			var posId = a.substr(3, a.find("_") - 3)
			supportedPositions.append("pos" + posId)

	var emote = find_child("EmoteSprite")
	if emote:
		emote.visible = false
		defaultEmotePos = emote.position
		var greeting = find_child("GreetingSound")
		if greeting:
			greeting.connect("sound_duration_elapsed", Callable(emote, "hide"))

	defaultZIndex = z_index
	if multiplayer.is_server():
		findRandomPlace()

	add_to_group("lostL")
	add_to_group("saveable")

	Data.listen(self, teamId + ".event.keepers.insidedome")

func propertyChanged(property: String, oldValue, newValue):
	if GameWorld.runStarted and newValue and not oldValue and not sleepingPositions.has(currentPos):
		emote()

func emote():
	var greeting = find_child("GreetingSound")
	if greeting:
		greeting.startSound()

	var emote = find_child("EmoteSprite")
	if emote:
		emote.visible = true
		if emotePositionByAnimationPos.has(currentPos):
			emote.position = emotePositionByAnimationPos[currentPos]
		else:
			emote.position = defaultEmotePos

func serialize() -> Dictionary:
	var data = {}
	data["meta.priority"] = 100
	data["meta.kind"] = "generic"
	data["hatchedThisRun"] = hatchedThisRun
	return data

func deserialize(data: Dictionary):
	findRandomPlace()
	hatchedThisRun = data.get("hatchedThisRun", true)

func _process(delta):
	if not multiplayer.is_server():
		return

	if GameWorld.devMode and Input.is_action_just_pressed("f4"):
		findRandomPlace()
	if GameWorld.devMode and Input.is_action_just_pressed("f3"):
		findNextPlace()
	if GameWorld.devMode and Input.is_action_just_pressed("f5"):
		reloadPlace()
	if GameWorld.devMode and Input.is_action_just_pressed("f2"):
		cycleAllPlaces()
	if switchCooldown > 0.0:
		switchCooldown -= delta
	else:
		for keeper in Keepers.getAllOfTeam(teamId):
			if keeper.global_position.y < 200.0:
				return
		findRandomPlace()

func findRandomPlace():
	if not positions:

		return

	var consideredPositions: = []
	for place in positions.get_children():
		var pos = getPosPrefix(place)
		if supportedPositions.has(pos):
			consideredPositions.append(place)

	if consideredPositions.size() > 1 and consideredPositions.has(currentPos):
		consideredPositions.erase(currentPos)

	if consideredPositions.is_empty():
		visible = false
		return

	var place = consideredPositions[randi() % consideredPositions.size()]
	var positionName: String = getPosPrefix(place)
	var flip_h: = false
	if place.name.ends_with("left"):
		flip_h = not looksLeft
	elif place.name.ends_with("right"):
		flip_h = looksLeft
	else:
		flip_h = randf() > 0.5

	var animation_seed: = randi()
	setPlace(positionName, place.position, flip_h, animation_seed)
	found_new_place.emit(positionName, place.position, flip_h, animation_seed)

func findNextPlace():
	if not positions:

		return

	var consideredPositions: = []
	for place in positions.get_children():
		var pos = getPosPrefix(place)
		if supportedPositions.has(pos):
			consideredPositions.append(place)

	if consideredPositions.is_empty():
		visible = false
		return

	last_idx += 1
	var next_place = consideredPositions[last_idx % consideredPositions.size()]

	var positionName: String = getPosPrefix(next_place)
	var flip_h: = false
	if next_place.name.ends_with("left"):
		flip_h = not looksLeft
	elif next_place.name.ends_with("right"):
		flip_h = looksLeft
	else:
		flip_h = randf() > 0.5

	var animation_seed: = randi()
	setPlace(positionName, next_place.position, flip_h, animation_seed)
	found_new_place.emit(positionName, next_place.position, flip_h, animation_seed)

func reloadPlace():
	if not positions:

		return

	var consideredPositions: = []
	for place in positions.get_children():
		var pos = getPosPrefix(place)
		if supportedPositions.has(pos):
			consideredPositions.append(place)

	if consideredPositions.is_empty():
		visible = false
		return

	var next_place = consideredPositions[last_idx % consideredPositions.size()]

	var positionName: String = getPosPrefix(next_place)
	var flip_h: = false
	if next_place.name.ends_with("left"):
		flip_h = not looksLeft
	elif next_place.name.ends_with("right"):
		flip_h = looksLeft
	else:
		flip_h = randf() > 0.5

	var animation_seed: = randi()
	setPlace(positionName, next_place.position, flip_h, animation_seed)
	found_new_place.emit(positionName, next_place.position, flip_h, animation_seed)

func setPlace(positionName: String, pos: Vector2, flip_h: bool, animation_seed: int) -> void :
	currentPos = positionName
	position = pos
	$Sprite2D.flip_h = flip_h

	if $Sprite2D.flip_h:
		$Sprite2D.offset.x = offsetXWhenFlipped
		$EmoteSprite.position.x = - unflippedEmoteX
	else:
		$Sprite2D.offset.x = 0
		$EmoteSprite.position.x = unflippedEmoteX


	random.seed = animation_seed

	startAnimation(currentPos + "_idle")
	currentActions.clear()
	currentActionIndex = 0
	for a in $Sprite2D.sprite_frames.get_animation_names():
		var split = a.split("_")
		if split[0] == currentPos and a.find("action") != -1:
			currentActions.append(a)

	visible = true
	switchCooldown = 30.0

	var domeTechId = get_parent().techId
	z_index = zIndexByDome.get(domeTechId, {}).get(currentPos, defaultZIndex)

func getPosPrefix(place):
	var positionIndex = place.name.split("_")[0]
	var idx = positionIndex.split("n")[1]
	return str("pos", idx)

func cycleAllPlaces():
	var consideredPositions: = []
	for place in positions.get_children():
		var pos = getPosPrefix(place)
		if supportedPositions.has(pos):
			consideredPositions.append(place)


	for i in consideredPositions.size():
		var place = consideredPositions[i]
		currentPos = getPosPrefix(place)
		if place.name.ends_with("left"):
			$Sprite2D.flip_h = not looksLeft
		elif place.name.ends_with("right"):
			$Sprite2D.flip_h = looksLeft
		else:
			$Sprite2D.flip_h = randf() > 0.5


		startAnimation(currentPos + "_idle")
		position = place.position
		visible = true
		switchCooldown = 30.0
		var t = Timer.new()
		add_child(t)
		t.wait_time = 2.0
		t.start()
		t.connect("timeout", Callable(t, "queue_free"))
		await t.timeout


func startAnimation(id: String):
	$Sprite2D.play(id)
	var audioId = id.capitalize().replace(" ", "")
	if currentlyPlayingAudioNode:
		currentlyPlayingAudioNode.stop()
		currentlyPlayingAudioNode = null

	if has_node(audioId):
		var node = get_node(audioId)
		node.play()
		currentlyPlayingAudioNode = node

func _on_sprite2d_looped() -> void :
	sprite2dAnimationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	sprite2dAnimationFinishedCheck()

func sprite2dAnimationFinishedCheck() -> void :
	if not visible:
		return

	if $Sprite2D.animation == currentPos + "_idle" and currentActions.size() > 0:
		if random.randf() > 0.5:
			if randomAction:
				currentActionIndex = random.randi() % currentActions.size()
				startAnimation(currentActions[currentActionIndex])
			else:
				currentActionIndex = 0
				startAnimation(currentActions[currentActionIndex])
	elif randomAction or currentActionIndex >= currentActions.size() - 1:
		startAnimation(currentPos + "_idle")
	else:

		currentActionIndex += 1
		startAnimation(currentActions[currentActionIndex])

func onGameLost():
	visible = false

func greetingSoundFinished():
	var emote = find_child("EmoteSprite")
	if emote:
		emote.visible = false
