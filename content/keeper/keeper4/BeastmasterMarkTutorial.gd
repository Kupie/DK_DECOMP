extends Tutorial

func _ready():
	pass

func moveIn():
	_ensure_tween()
	super.moveIn()

func process_trigger(delta: float) -> bool:
	return tutorialParent.hitCooldown > 0

func process_confirm(delta: float):

	pass

func _ensure_tween():
	if tween == null:
		tween = DeprecatedTween.new()
		add_child(tween)
