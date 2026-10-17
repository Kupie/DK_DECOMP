class_name ParallaxBG extends Node2D

@export var scrollSpeeds: = []
@export var enabled: = true

var _isPrototype: bool = false
var _playerID: String

func _ready():
	add_to_group("ParallaxBG")
	enabled = false
	hide()

	var z = - get_child_count() + 1
	for c in get_children():
		if c.z_index == 0:
			c.z_index = z
		z += 1


func useOnlyAsContructionPrototype() -> void :
	_isPrototype = true

func clone() -> ParallaxBG:
	assert (_isPrototype, "Clone can be created only from the prototype")
	var clone: ParallaxBG = duplicate()
	clone._isPrototype = false
	clone.global_position = global_position
	return clone

func init(inPlayerID: String, inVisibilityLayerBit: int) -> void :
	_playerID = inPlayerID
	visibility_layer = 0
	visibility_layer |= 1 << inVisibilityLayerBit
	show()
	enabled = true

func isRelatedToTeam(inTeam: String) -> bool:
	if not Keepers.hasKeeper(_playerID):
		return false

	var team: String = Keepers.getKeeper(_playerID).teamId
	return team == inTeam

func _process(delta):
	if not enabled:
		return

	if StageManager.isInLoadout():
		return

	var cam: KeeperCamera = get_viewport().get_camera_2d()
	var valid: bool = cam.hasValidTarget()
	if not valid:

		return

	var dy: float = cam.position.y - cam.getCurrentParallaxRestPosition(cam.zoom.x)
	for i in range(0, get_child_count()):
		var off = scrollSpeeds[i]
		var background = get_child(i)
		background.position.y = (1.0 - off) * dy



func addBackgroundHub(hub):
	$Marker2D / BackgroundHub.add_child(hub)



func hasWeatherSlot(inSlot: String) -> bool:
	var weatherSlot: Node = _getWeatherSlot(inSlot)
	return is_instance_valid(weatherSlot)

func addWeatherEffectUnderSlot(inEffect: Node, inSlot: String) -> void :
	var slotNode: Node = _getWeatherSlot(inSlot)
	_addWeatherEffectUnderSlotNode(inEffect, slotNode)

func addWeatherEffectToEverySlot(inEffectConstructor: Callable, inSlot: String) -> void :
	var slots: Array[Node] = _getAllWeatherSlots(inSlot)
	for slot: Node in slots:
		var effect: Node = inEffectConstructor.call()
		_addWeatherEffectUnderSlotNode(effect, slot)

func _addWeatherEffectUnderSlotNode(inEffect: Node, inSlotNode: Node) -> void :
	var addWithSounds: bool = _isPrototype
	if not addWithSounds:

		if inEffect.has_method("disableSounds"):
			inEffect.disableSounds()
	inSlotNode.add_child(inEffect)
	if inEffect.has_method("start_weather"):
		inEffect.start_weather(self)

func _getWeatherSlot(inSlot: String) -> Node:
	var allSlots: Array[Node] = _getAllWeatherSlots(inSlot)
	if allSlots.is_empty():
		return null
	return allSlots.front()

func _getAllWeatherSlots(inSlot: String) -> Array[Node]:
	var slots: Array[Node] = []
	for child: Node in get_children():
		if child.is_in_group(inSlot):
			slots.append(child)
		for grandChild: Node in child.get_children():
			if grandChild.is_in_group(inSlot):
				slots.append(grandChild)
	return slots
