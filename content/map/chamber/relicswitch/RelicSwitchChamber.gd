extends "res://content/map/chamber/Chamber.gd"

var ownedCables: = []
var readyToUse: = false
var used: = false
var chamberId: = 0

func _ready():
	super._ready()
	$Sprite2D.visible = false
	chamberType = Data.TILE_RELIC_SWITCH

	if multiplayer.is_server():
		connect_cables()
	else:
		GameWorld.chamberIdsReceived.connect(on_chamber_ids_received)

func on_chamber_ids_received() -> void :
	connect_cables()

func connect_cables():
	var closestChamber
	var closestDist: = 9999999.0
	for chamber in get_tree().get_nodes_in_group("relicchamber"):
		if chamber.type == CONST.RELIC:
			var d: = position.distance_to(chamber.position)
			if d < closestDist:
				closestDist = d
				closestChamber = chamber

	if closestChamber:
		chamberId = closestChamber.get_chamber_id()
		add_to_group("relic-switch-" + str(chamberId))
		var newDestinationPos = closestChamber.getCenter() + closestChamber.global_position
		var newOriginPos = getCenter() + global_position
		var cableLine: = preload("res://content/map/chamber/relicswitch/NewCable/CablePath.tscn").instantiate()
		cableLine.startPoint = newOriginPos
		cableLine.endPoint = newDestinationPos
		Level.map.bg_elements.add_child(cableLine)
		ownedCables.append(cableLine)
		closestChamber.connect("relic_taken", cableLine.deactivate)
		closestChamber.connect("relic_taken", deactivate)

func serialize() -> Dictionary:
	var data: = super.serialize()
	data["chamberId"] = chamberId
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	chamberId = data["chamberId"]
	for g in get_groups():
		if g.begins_with("relic-switch-"):
			remove_from_group(g)
	add_to_group("relic-switch-" + str(chamberId))
	if currentState == State.OPEN or currentState == State.OPENING:
		$Sprite2D.show()
		$Sprite2D.play("opening")
		$Sprite2D.frame = $Sprite2D.sprite_frames.get_frame_count("opening") - 1
	elif currentState == State.EMPTY:
		$Sprite2D.show()
		if Data.ofOr("map.relictaken", false):
			deactivate()
		else:
			$Light3D.light_active = true
			$Sprite2D.play("running")


	if ownedCables.size() == 0:
		await GameWorld.savegame_loaded
		connect_cables()

	if currentState == State.EMPTY and not Data.ofOr("map.relictaken", false):
		for cable in ownedCables:
			cable.activate()

func deactivate():
	$Sprite2D.play("deactivated")
	$Light3D.light_active = false
	$ChamberAmbOpen.queue_free()

func onExcavated():
	open()

func onOpening():
	$Tween.interpolate_callback(self, 0.4, "actuallyOpen")
	$Tween.start()

func actuallyOpen():
	$Sprite2D.play("opening")
	$DoorOpen.startSound()


	currentState = State.OPEN

func onRevealed():
	$Sprite2D.play("default")
	$Sprite2D.visible = true
	$ChamberAmbClosed.startSound()

func _on_sprite_2d_animation_looped() -> void :
	_SpriteAnimationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_SpriteAnimationFinishedCheck()

func _SpriteAnimationFinishedCheck() -> void :
	if $Sprite2D.animation == "opening":
		readyToUse = true
		if used:
			onUsed()
	elif $Sprite2D.animation == "empty":
		$Light3D.light_active = true
		$Sprite2D.play("running")

func onUsed():
	if readyToUse:
		$Sprite2D.play("empty")
		$Usable.queue_free()
		$ChamberSwitchHit.startSound()
		$ChamberAmbClosed.stop()
		$ChamberAmbClosed.queue_free()
		$ChamberAmbOpen.startSound()
		currentState = State.EMPTY

		for chamber in get_tree().get_nodes_in_group("relic-chamber-" + str(chamberId)):
			chamber.on_switch_activated()

		var time: = 0.1
		for cable in ownedCables:
			$Tween.interpolate_callback(cable, time, "activate")
			time += 0.5
		$Tween.start()
	else:
		used = true

func addCable(cable):
	$Sprite2D.add_child(cable)
	cable.centerOffset = 11

func getTileType() -> int:
	return Data.TILE_RELIC_SWITCH

func onStateUpdated() -> void :
	super.onStateUpdated()
	if multiplayer.is_server():
		return

	if currentState == State.OPEN or currentState == State.OPENING:
		$Sprite2D.show()
		$Sprite2D.play("opening")
		$Sprite2D.frame = $Sprite2D.sprite_frames.get_frame_count("opening") - 1
	elif currentState == State.EMPTY:
		$Sprite2D.show()
		if Data.ofOr("map.relictaken", false):
			deactivate()
		else:
			$Light3D.light_active = true
			$Sprite2D.play("running")
