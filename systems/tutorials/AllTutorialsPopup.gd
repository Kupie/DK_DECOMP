extends CenterContainer
var keeper: Keeper

func _ready():
	var tutorialIds: = {}
	for tutorialManager in get_tree().get_nodes_in_group("tutorial-manager"):
		for id in tutorialManager.getCurrentlyRelevantTutorialIds():
			tutorialIds[id] = 0
	fill(tutorialIds)
	Style.init(self)
	InputSystem.grabFocus(find_child("CancelButton"))

func fill(tutorialIds: Dictionary):
	var container = find_child("TutorialContainer")

	var groups: = {}
	for id in tutorialIds:
		if GameWorld.tutorialStages.get(id, 0) <= 2:
			continue
		var scene = Data.TUTORIAL_SCENES.get(id, null)
		if not scene:
			continue
		var tut = scene.instantiate()
		if not tut.showOnSummaryPopup:
			tut.queue_free()
			continue

		var tuts: Array
		if groups.has(tut.summaryCategory):
			tuts = groups[tut.summaryCategory]
		else:
			tuts = []
			groups[tut.summaryCategory] = tuts
		tuts.append(tut)

	%NoneUnlockedLabel.visible = groups.size() == 0

	for key in groups:
		var label = Label.new()
		label.text = tr(key)
		label.label_settings = preload("res://gui/fontsettings/HeadingFontSettings.tres")
		label.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_BOTTOM
		label.custom_minimum_size.y = 100
		container.add_child(label)
		var c = HFlowContainer.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(c)
		for tut in groups[key]:
			tut.keeper = keeper
			c.add_child(tut)
			tut.visible = true
			if tut.isFullscreen:
				tut.showAllVideos()

func _on_CancelButton_pressed():
	Audio.sound("gui_back")
