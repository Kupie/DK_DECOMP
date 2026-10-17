extends Node

var worldModifiers

func _ready():
	var counts: = {}
	var classes: = {}
	for i in 100000:
		generateModifiers()

		for m in worldModifiers:
			counts[m] = 1 + counts.get(m, 0)
			classes[Data.worldModifiers[m]["class"]] = 1 + classes.get(Data.worldModifiers[m]["class"], 0)

	for m in classes:
		print(m + ": " + str(classes[m]))
	print()
	for m in counts:
		print(m + ": " + str(counts[m]))

func generateModifiers():
	for _j in 10:
		var availableModifiers: Array = Data.worldModifiers.keys().duplicate()
		for mod in GameWorld.lastWorldModifiers:
			availableModifiers.erase(mod)
		worldModifiers = []

		var currentRating: = 0
		var consideredModifiers = availableModifiers.duplicate()
		for _i in 3:
			var appliedModId = consideredModifiers[randi() % consideredModifiers.size()]
			worldModifiers.append(appliedModId)
			var appliedMod = Data.worldModifiers[appliedModId]
			currentRating += appliedMod["rating"]
			for modId in availableModifiers.duplicate():
				if Data.worldModifiers[modId]["class"] == appliedMod["class"]:
					availableModifiers.erase(modId)

			consideredModifiers.clear()
			for modId in availableModifiers:
				if sign(Data.worldModifiers[modId]["rating"]) != sign(currentRating):
					consideredModifiers.append(modId)

		if abs(currentRating) <= 1:
			if GameWorld.devMode:
				print("running with world modifiers " + str(worldModifiers))
			return
