extends "res://content/map/chamber/Chamber.gd"

var giftType: String

func _ready():
	super._ready()
	$Sprite2D.visible = false
	chamberType = Data.TILE_GADGET

func deserialize(data: Dictionary):
	super.deserialize(data)
	$Sprite2D.show()
	if currentState == State.OPEN or currentState == State.OPENING:
		$Sprite2D.play("opening")
		$Sprite2D.frame = $Sprite2D.sprite_frames.get_frame_count("opening") - 1
	elif currentState == State.EMPTY:
		$Sprite2D.play("empty")
	giftType = data.get("giftType", "")

func serialize() -> Dictionary:
	var data = super.serialize()
	data["giftType"] = giftType
	return data

func onExcavated():
	open()
	$Sprite2D.play("opening")
	$BellSound.startSound()

func onRevealed():
	$Sprite2D.play("default")
	$Sprite2D.visible = true
	$BellSound.startSound()

func _on_Sprite_animation_finished():
	if $Sprite2D.animation == "opening":
		currentState = State.OPEN

func registerHit(playerId: String) -> void :
	super.registerHit(playerId)
	var keeper: = Keepers.getKeeper(playerId)

	if giftType == "skin3"\
	and (keeper.techId == "keeper1" or keeper.techId == "keeper2"):
		keeper.setSkin("skin3")
		for x in Level.loadout.keepers:
			if keeper.playerId == x.playerId:
				x.skinId = "skin3"
		if multiplayer.is_server():
			GameWorld.newSkinsToUnlock.append({"keeperId": keeper.techId, "skinId": "skin3"})
	elif giftType == "pet7":
		if multiplayer.is_server():
			var gizmo: Drop = Level.drops.network_spawn({
				"type": CONST.EGG, 
				"position": $Usable.global_position, 
				"carriers": [playerId], 
				"team": keeper.teamId, 
			})
			gizmo.forcePetId = "pet7"

func onUsed():
	$Sprite2D.play("empty")
	$Usable.queue_free()
	$BellSound.startSound()

func _on_Sprite_frame_changed():
	if $Sprite2D.animation == "opening" and $Sprite2D.frame == 7:
		Audio.stinger("stinger_gadget_chamber_excavated_" + Audio.get_closest_keeperId_or_music_override(position), global_position)

func getTileType() -> int:
	return Data.TILE_GADGET
