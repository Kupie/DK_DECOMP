extends Container

var isIn: = false
var outLeft: = false
var outRight: = false


var tween2: DeprecatedTween

func _ready():
	Style.init(self)

	position.y += size.y

	tween2 = DeprecatedTween.new()
	add_child(tween2)

func moveIn(delay: = false):
	if isIn:
		return

	isIn = true
	tween2.stop_all()
	tween2.remove_all()

	var s = get_parent().size
	$Tween.interpolate_property(self, "position", position, Vector2(s.x * anchor_left - size.x * 0.5, s.y - size.y), 0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT, 0.3 if delay else 0.0)
	$Tween.start()

func moveOut(freeOnMovedOut: = false):
	if not isIn:
		return

	isIn = false
	$Tween.stop_all()
	$Tween.remove_all()
	var s = get_parent().size
	tween2.interpolate_property(self, "position:y", position.y, s.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_IN)
	if freeOnMovedOut:
		tween2.interpolate_callback(self, 0.5, "queue_free")
	tween2.start()
