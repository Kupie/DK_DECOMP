extends "res://content/gadgets/CellarGadget.gd"

signal state_changed

@export var synchronizer: GadgetSynchronizer

var producing: = false
var _hasMine: = false
var growth: = 0.0
var grownAfter: = 0.0
var nextFlameAfter: = 0.0

var flameCount: int

func _ready():
	flameCount = $Flames.get_child_count() + 1
	for c in $Flames.get_children():
		c.connect("animation_finished", continueFlameAnimation.bind(c))
		c.visible = false
	addMine()

	Data.listen(self, teamId + ".blastmining.bombsize")

	Style.init(self)

	Level.addTutorial(self, "blastmining", teamId)

	Achievements.addIfOpen(self, "BLASTMINING_USE")

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".blastmining.bombsize":
		updateBombSprite()

func serialize() -> Dictionary:
	var data = super.serialize()
	data["producing"] = producing
	data["_hasMine"] = _hasMine
	data["growth"] = growth
	data["grownAfter"] = grownAfter
	data["flameCount"] = flameCount
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	producing = data["producing"]
	_hasMine = data["_hasMine"]
	growth = data["growth"]
	grownAfter = data["grownAfter"]
	flameCount = data["flameCount"]

	updateFromState()

func get_gadget_state() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_bool(producing)
	stream.encode_bool(_hasMine)
	stream.encode_float(growth)
	stream.encode_float(grownAfter)
	stream.encode_u8(flameCount)
	return stream.data

func set_gadget_state(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	producing = stream.decode_bool()
	_hasMine = stream.decode_bool()
	growth = stream.decode_float()
	grownAfter = stream.decode_float()
	flameCount = stream.decode_u8()
	updateFromState()

func updateFromState() -> void :
	if _hasMine:
		addMine()
	else:
		$Mine.visible = false

	if producing:
		$Flames.visible = true
		var flames_to_light = int(flameCount * pow(growth / grownAfter, 2))
		for c in $Flames.get_children():
			if flames_to_light > 0:
				c.visible = true
				c.play("start")
			else:
				c.visible = false
			flames_to_light -= 1
		updateNextFlameAfter()

	$Usable.updateFocus()

func updateNextFlameAfter():
	var litFlames: = 0
	for c in $Flames.get_children():
		if c.visible:
			litFlames += 1
		else:
			break

	var childCount = $Flames.get_children().size()
	var nextStep = sqrt((litFlames) / float(childCount))
	nextFlameAfter = nextStep * grownAfter

func continueFlameAnimation(f):
	f.play("run")

func _process(delta):
	if GameWorld.softPaused(teamId):
		return

	if growth < grownAfter:
		growth += delta
		if nextFlameAfter <= growth:
			var pitch: = 1.0
			for c in $Flames.get_children():
				if not c.visible:
					c.visible = true
					c.play("start")
					$FlameOn.pitch_scale = pitch
					$FlameOn.startSound()
					break
				pitch += 0.05
			updateNextFlameAfter()
		return

	if not multiplayer.is_server():
		return

	if producing:
		synchronizer.network_rpc(addMine, true)
	elif not _hasMine:
		producing = true
		growth = 0.0
		grownAfter = GameWorld.getTimeBetweenWaves(teamId) * float(Data.of(teamId + ".blastMining.growthTime"))
		$Flames.visible = true
		for c in $Flames.get_children():
			c.visible = false

		state_changed.emit()
		updateNextFlameAfter()

@rpc("reliable")
func addMine():
	$MineReady.startSound()
	$Mine.visible = true
	$Mine.frame = 0
	$Mine.play()
	updateBombSprite()
	$Flames.visible = false
	producing = false
	_hasMine = true

func updateBombSprite():
	$Mine / Bomb.play("normal_" + str(min(100, Data.ofOr(teamId + ".blastMining.bombsize", 100))))

func canFocusUse(keeper: Keeper) -> bool:
	return _hasMine

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if _hasMine:
		synchronizer.network_rpc(registerHit.bind(keeper.playerId), true)
		return true
	return false

@rpc("reliable", "any_peer")
func registerHit(playerId: String) -> void :
	if _hasMine and multiplayer.is_server():
		for _i in Data.of(teamId + ".blastMining.bombs"):
			Level.drops.network_spawn({
					"type": CONST.MINE, 
					"position": $MinePosition.global_position, 
					"carriers": [playerId], 
					"team": teamId, 
				})

	_hasMine = false
	$Mine.visible = false
	$MinePickup.startSound()

func _on_mine_animation_looped() -> void :
	_MineAnimationFinishedCheck()

func _on_Mine_animation_finished() -> void :
	_MineAnimationFinishedCheck()

func _MineAnimationFinishedCheck() -> void :
	$Usable.updateFocus()


func hasMine() -> bool:
	return _hasMine
