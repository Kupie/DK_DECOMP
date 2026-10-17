extends CenterContainer

var cooldown: = 10.0

var done: = true

func _ready():
	visible = false
	$PanelContainer.pivot_offset = $PanelContainer.size * 0.5
	Style.init(self)

func _process(delta):
	if done:
		return

	cooldown -= delta
	var newText = str(abs(round(cooldown)))
	if find_child("LabelTime").text != newText:
		find_child("LabelTime").text = newText
		Audio.sound("alarm")
	if cooldown <= 0.0:
		done = true
		StageManager.startStage("stages/title/title")

func fadeIn(t: float = 0.5):
	visible = true

	done = false
	cooldown = 10.49
	for o in get_tree().get_nodes_in_group("level_canvas_overlay"):
		o.showOverlay()
	Audio.sound("gui_pause_start")
	Audio.muteSounds()


func fadeOut(t: float = 0.5):
	visible = false
	for o in get_tree().get_nodes_in_group("level_canvas_overlay"):
		o.hideOverlay()
	done = true
	Audio.sound("gui_pause_stop")
	Audio.unmuteSounds()
