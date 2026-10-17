extends "res://content/caves/Cave.gd"

func onRevealed():
	find_child("Amb").startSound()

func serialize() -> Dictionary:
	var data = super.serialize()
	for cobalt in [ %Cobalt1, %Cobalt2]:
		data[cobalt.name + "_taken"] = cobalt.taken
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	if currentState == State.REVEALED:
		find_child("Amb").startSound()

	for cobalt in [ %Cobalt1, %Cobalt2]:
		var newKey = cobalt.name + "_taken"
		if data.has(newKey):
			cobalt.taken = data[newKey]
		else:
			cobalt.taken = not data.get(cobalt.name.to_lower(), true)
		cobalt.visible = not cobalt.taken
