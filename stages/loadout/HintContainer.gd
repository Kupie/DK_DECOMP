extends PanelContainer

@export var mode: = "left"

var followControl: Control

const marginX: = 18
const marginY: = 12

var updatePosition: = false

func _ready():
	Style.init(self)
	scale = Vector2.ZERO
	updatePosition = true

func asBigText():
	$LabelDesc.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT

func setFollowControl(followControl: Control):
	self.followControl = followControl
	followControl.connect("resized", Callable(self, "shouldUpdatePosition"))

func shouldUpdatePosition():
	updatePosition = true

func setHint(hint: String):
	find_child("LabelDesc").text = hint

func _process(delta):
	if not followControl:
		queue_free()
		return

	if not followControl.is_visible_in_tree():
		if mode == "inside":
			scale.y *= 0
		else:
			scale = Vector2.ZERO
		return

	if updatePosition:
		followNodeResized()

	modulate.a = followControl.filling
	if modulate.a > 0.0:
		if followControl.filling >= 1.0:
			var d = Vector2.ONE - scale
			if mode == "inside":
				scale += d * delta * 20
			else:
				scale += d * delta * 10
		else:

			if mode == "inside":
				scale.y -= scale.y * delta * 20
			else:
				scale -= scale * delta * 10

		clamp_scale()

func clamp_scale():
	scale = Vector2(clamp(scale.x, 0.0, 1.0), clamp(scale.y, 0.0, 1.0))

func followNodeResized():
	updatePosition = false
	global_position = followControl.global_position
	match mode:
		"inside":
			size.x = followControl.size.x
			pivot_offset.x = size.x * 0.5
			position.y += followControl.size.y - size.y
			pivot_offset.y = size.y
		"left":
			position.y += (followControl.size.y - size.y) * 0.5
			position.x -= size.x - 5
			pivot_offset.x = size.x
			pivot_offset.y = size.y * 0.5
			custom_minimum_size.x = 250
		"right":
			position.y += (followControl.size.y - size.y) * 0.5
			position.x += followControl.size.x - 5
			pivot_offset.x = 0
			pivot_offset.y = size.y * 0.5
			custom_minimum_size.x = 250
		"up":
			size.x = followControl.size.x - 2 * marginX
			position.x += marginX
			position.y -= size.y - 5
			pivot_offset.x = size.x * 0.5
			pivot_offset.y = size.y
		"down":
			size.x = followControl.size.x - 2 * marginX
			position.x += marginX
			position.y += followControl.size.y - 5
			pivot_offset.x = size.x * 0.5
			pivot_offset.y = 0

	await get_tree().process_frame
	size.y = 10

func _on_LabelDesc_resized():
	updatePosition = true
