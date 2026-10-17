extends Sprite2D

func setSlots(slots: Array):
	for c in get_children():
		c.visible = false
		for slot in slots:
			var slot_name = slot.substr(slot.find(".") + 1)
			if slot_name == c.name:
				c.visible = true
