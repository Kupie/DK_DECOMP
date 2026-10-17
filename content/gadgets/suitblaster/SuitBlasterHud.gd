extends HudElement

const GUY_HEIGHT: = 12

func init():
	super.init()
	Data.listen(self, playerId + ".suitblaster.charge", true)
	Data.listen(self, teamId + ".suitblaster.maxcharge", true)

func propertyChanged(property: String, oldValue, newValue):
	if property == playerId + ".suitblaster.charge":
		update_rect_position(newValue)
	elif property == teamId + ".suitblaster.maxcharge":
		update_rect_position(Data.of(playerId + ".suitblaster.charge"))
		if newValue > 1:
			element_size.y = 4
			$Slots.visible = true
		else:
			element_size.y = 3
			$Slots.visible = false
		request_rebuild.emit()

func _process(delta: float) -> void :
	if Data.of(playerId + ".suitblaster.charge") == Data.of(teamId + ".suitblaster.maxcharge"):
		%GuySprite.texture = preload("res://content/gadgets/suitblaster/hud/suitblaster_ready.png")
		%SpriteAnimated.play("ready")
	else:
		%GuySprite.texture = preload("res://content/gadgets/suitblaster/hud/suitblaster_load.png")
		%SpriteAnimated.play("loading")

func update_rect_position(val):
	var rel = GUY_HEIGHT * fmod(val, 1)
	%GuySprite.region_rect.size.y = rel
	%GuySprite.region_rect.position.y = GUY_HEIGHT - rel
	%GuySprite.position.y = GUY_HEIGHT - rel
	%GuySprite.position.y = %GuySprite.region_rect.position.y * 0.5

	for i in range(1, 6):
		find_child(str(i)).visible = val >= i
