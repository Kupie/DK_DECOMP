extends Control

var tutorials: = {}

var sortedTutorialIds: = []
var currentTutorial: Tutorial = null
var active: = false
var currentlyRelevantTutorialIds: = []

var tutorialStages: Dictionary
var keeper: Keeper

var tutorialsToAddAfterInit: = []

func init(keeper: Keeper):
	self.keeper = keeper

	tutorialStages = GameWorld.tutorialStages

	for data in tutorialsToAddAfterInit:
		addIfOpen(data[0], data[1])

	for tutorial in tutorials.values():


		tutorial.keeper = keeper

	if not keeper.tutorialsActive:
		for tutorial in tutorials.values():
			tutorial.queue_free()
		tutorials.clear()

func addIfOpen(tutorialParent, id: String):

	if Level.fullscreenTutorials.has(id):
		return

	if not keeper:
		tutorialsToAddAfterInit.append([tutorialParent, id])
		return

	if not Data.TUTORIAL_SCENES.has(id):
		Logger.error("tutorial id is unknown", "Tutorials.addIfOpen", id)
		return

	currentlyRelevantTutorialIds.append(id)

	if tutorialStages.get(id, 0) < CONST.TUTORIAL_TIMEDOUT:
		addTutorial(tutorialParent, id)

func addTutorial(tutorialParent, id):
	if tutorialParent is Keeper and tutorialParent != keeper:
		return
	Logger.info("adding tutorial " + id)
	tutorialStages[id] = CONST.TUTORIAL_LISTENING
	var tut = Data.TUTORIAL_SCENES.get(id).instantiate()
	tut.id = id
	tut.tutorialParent = tutorialParent
	tut.keeper = keeper
	tutorials[id] = tut
	if tut.isFullscreen:
		sortedTutorialIds.push_front(id)
		Level.fullscreenTutorials.append(id)
		get_tree().get_root().find_child("LevelCanvas", true, false).get_node("AreaLimiter").add_child(tut)
	else:
		sortedTutorialIds.append(id)
		add_child(tut)

func eraseTutorialId(id: String) -> void :
	sortedTutorialIds.erase(id)
	tutorials.erase(id)

func _process(delta):
	if not active or not keeper:
		return
	var wave = Data.of(keeper.teamId + ".monsters.wavepresent")
	var waveCooldown = Data.of(keeper.teamId + ".monsters.waveCooldown")
	if currentTutorial == null:
		if GameWorld.paused:
			return

		for tutId in sortedTutorialIds.duplicate():
			var tut = tutorials[tutId]
			if not tut.triggerDuringWave and wave:
				continue

			if tut.listeningDelay >= 0.0:
				tut.listeningDelay -= delta
				continue

			if tut.minTimeToWave > 0 and tut.minTimeToWave > waveCooldown:
				continue

			tut.process_confirm(delta)
			if tut.confirmed:
				Logger.info("confirmed tutorial before appearing " + tut.id)
				tutorialStages[tut.id] = CONST.TUTORIAL_CONFIRMED
				persistTutorialStages()
				eraseTutorialId(tut.id)
				tut.queue_free()
			else:
				if tut.triggered or tut.process_trigger(delta):
					Logger.info("triggered tutorial " + tut.id)
					tut.moveIn()
					currentTutorial = tut


					eraseTutorialId(currentTutorial.id)
					tutorialStages[tut.id] = CONST.TUTORIAL_DISPLAYING
					return
	else:
		if currentTutorial.isFullscreen:
			if currentTutorial.confirmed:
				currentTutorialConfirmed()
		elif not GameWorld.paused:
			if currentTutorial.moveOutAfter > 0.0:
				currentTutorial.moveOutAfter -= delta
				if currentTutorial.confirmed:
					currentTutorialConfirmed()
				else:
					currentTutorial.process_confirm(delta)
			elif not currentTutorial.isFullscreen:
				Logger.info("timed out tutorial " + currentTutorial.id)
				currentTutorial.moveOut()
				tutorialStages[currentTutorial.id] = CONST.TUTORIAL_TIMEDOUT
				persistTutorialStages()
				currentTutorial = null

func currentTutorialConfirmed():
	Logger.info("confirmed tutorial " + currentTutorial.id)
	currentTutorial.moveOut()
	tutorialStages[currentTutorial.id] = CONST.TUTORIAL_CONFIRMED
	persistTutorialStages()
	currentTutorial = null

func activate():
	active = true
	tutorialStages = GameWorld.tutorialStages

func deactivate():
	active = false
	if currentTutorial:
		currentTutorial.moveOut()

	currentTutorial = null
	for t in tutorials.values():
		t.queue_free()
	tutorials.clear()
	currentlyRelevantTutorialIds.clear()

func persistTutorialStages():
	GameWorld.tutorialStages = tutorialStages
	SaveGame.persistTutorialStages()

func getCurrentlyRelevantTutorialIds() -> Array:
	return currentlyRelevantTutorialIds
