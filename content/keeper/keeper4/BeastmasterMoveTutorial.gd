extends Tutorial

func _ready():
	splitTutorialText("level.tutorial.beastmaster.move.desc1", "Label1", "Label2")

func moveIn():
	_ensure_tween()
	super.moveIn()

func process_trigger(delta: float) -> bool:
	return Data.of("monsters.cycle") == 0

func process_confirm(delta: float):
	var tentacles = tutorialParent.get_node_or_null("Tentacles")
	if tentacles and not tentacles.is_spread_mode:
		confirm()

func _ensure_tween():
	if tween == null:
		tween = DeprecatedTween.new()
		add_child(tween)
