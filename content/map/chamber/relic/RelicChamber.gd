extends "res://content/map/chamber/Chamber.gd"

signal relic_taken

var shouldOpen: = false
var stingerId: String
var chamberId: = 0
var excavated: = false

func _ready():
	super._ready()
	$SpriteBack.visible = false
	$SpriteBack / SpriteFront.play("closed")
	$SpriteBack.play("running")
	chamberType = Data.TILE_RELIC

	if multiplayer.is_server():
		chamberId = Data.ofOr("map.relicchambercounter", 1)
		Data.apply("map.relicchambercounter", chamberId + 1)
		add_to_group("relic-chamber-" + str(chamberId))

		GameWorld.registerChamberId(coord, chamberId)

func get_chamber_id() -> int:
	if chamberId == 0:
		chamberId = GameWorld.chamberCoordToId[coord]
		add_to_group("relic-chamber-" + str(chamberId))
	return chamberId

func deserialize(data: Dictionary):
	super.deserialize(data)
	for g in get_groups():
		if g.begins_with("relic-chamber-"):
			remove_from_group(g)
	chamberId = data["chamberId"]
	add_to_group("relic-chamber-" + str(chamberId))

func serialize() -> Dictionary:
	var data: = super.serialize()
	data["chamberId"] = chamberId
	return data

func deactivate():
	pass

func onStateUpdated():
	super.onStateUpdated()
	if currentState == State.REVEALED:
		pass
	if currentState == State.OPEN or currentState == State.OPENING or currentState == State.EMPTY:
		$Light3D.light_active = true
		$SpriteBack.show()
		$SpriteBack / SpriteFront.play("opening")
		$SpriteBack / SpriteFront.frame = $SpriteBack / SpriteFront.sprite_frames.get_frame_count("opening") - 1

func on_switch_activated():
	for switch in get_tree().get_nodes_in_group("relic-switch-" + str(chamberId)):
		if switch.currentState != State.EMPTY:
			return

	shouldOpen = excavated

func _process(delta):
	if shouldOpen:
		for keeper in Keepers.getAll():
			if keeper.global_position.distance_to(global_position) < GameWorld.TILE_SIZE * 8:
				open()
				shouldOpen = false
				return

func onExcavated():
	excavated = true


	on_switch_activated.call_deferred()

func onOpening():
	$SpriteBack / SpriteFront.play("opening")

func onRevealed():
	$SpriteBack.visible = true
	$GizmoSpawn / ChamberAmb.startSound()

func onUsed():
	$DoorOpen.queue_free()
	$Usable.queue_free()
	$GizmoSpawn.queue_free()
	$Light3D.light_active = false
	$SpriteBack.play("empty")
	$GizmoSpawn / ChamberAmb.stop()

	if multiplayer.is_server():
		Data.apply("map.relictaken", true)
		emit_signal("relic_taken")

	Achievements.triggerIfOpen("RELICHUNT_RELICTAKEN")

func _on_SpriteFront_frame_changed():
	if $SpriteBack / SpriteFront.animation == "opening":
		if $SpriteBack / SpriteFront.frame == 1:
			$DoorOpen.startSound()
		elif $SpriteBack / SpriteFront.frame == 50:
			$Light3D.light_active = true
			if stingerId == "":
				stingerId = "stinger_relic_chamber_excavated_" + Audio.get_closest_keeperId_or_music_override(position)
			Audio.stinger(stingerId, global_position)
		elif $SpriteBack / SpriteFront.frame == 65:
			currentState = State.OPEN

func addCable(cable):
	$SpriteBack / SpriteFront.add_child(cable)
	cable.centerOffset = 36

func getTileType() -> int:
	return Data.TILE_RELIC
