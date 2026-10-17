extends PanelContainer

@onready var CoopArea = find_child("CoopArea")
@onready var VersusArea = find_child("VersusArea")

var fillings: Dictionary

func _ready():
	visible = false
	fillings[CoopArea] = 0.0
	fillings[VersusArea] = 0.0

func _process(delta):
	if not visible:
		return

	var devices = get_tree().get_nodes_in_group("moveable-device")
	if devices.size() == 0:
		return

	var maxfilling = 0.0
	for area in [CoopArea, VersusArea]:
		var count = area.get_overlapping_bodies().size()
		var goalFill = count / float(devices.size())
		var diff = (100 * goalFill) - fillings[area]
		fillings[area] += (diff + sign(diff) * 4) * delta
		area.get_parent().self_modulate = Color.WHITE * (1.0 + fillings[area] * 0.0075)

	var filling = 0.0
	for v in fillings.values():
		filling = max(v, filling)

	find_child("ProgressBar").value = filling

func getMode() -> String:
	if fillings[CoopArea] >= 99.0:
		return CONST.MODE_COOP
	elif fillings[VersusArea] >= 99.0:
		return CONST.MODE_VERSUS
	else:
		return ""

func shakeBar(amount: float):
	var pb = find_child("ProgressBar")
	pb.pivot_offset = pb.size * 0.5
	pb.scale = (1.0 + amount * randf() * 0.2) * Vector2.ONE
	pb.rotation = amount * randf() * 20
