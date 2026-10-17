extends "res://content/caves/Cave.gd"

@export var synchronizer: DragonCaveSynchronizer

var hasEgg: = true
var needsCobalt: = true

func _ready():
	super._ready()
	%Egg.visible = false
	Style.init( %Egg)
	%Dragon.visible = false
	%CobaltDelivered.visible = false

func serialize() -> Dictionary:
	var data = super.serialize()
	data["hasEgg"] = hasEgg
	data["needsCobalt"] = needsCobalt
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	hasEgg = data["hasEgg"]
	needsCobalt = data["needsCobalt"]
	if needsCobalt:
		%Egg.visible = false
	else:
		%CobaltMarker.queue_free()
		if hasEgg:
			%Egg.visible = true
		else:
			%Egg.queue_free()

	if currentState == State.REVEALED:
		%AmbSound.startSound()

func onRevealed():
	%DiscoverSound.startSound()
	%AmbSound.startSound()

func _on_ResourceGrabber_grabbed_resource():
	synchronizer.network_rpc(playResourceGrabbedVisuals, true)

@rpc("reliable")
func playResourceGrabbedVisuals() -> void :
	needsCobalt = false
	var dragon = %Dragon
	dragon.visible = true
	dragon.play()
	dragon.connect("frame_changed", Callable(self, "_on_Dragon_frame_changed").bind(dragon))
	var pos = dragon.global_position
	dragon.get_parent().remove_child(dragon)
	Level.map.addDrop(dragon)
	dragon.global_position = pos
	%Tail.play()
	%ActivatedSound.startSound()
	%CobaltDelivered.visible = true

func _on_Dragon_frame_changed(dragon):
	if dragon.frame == 26:
		%Lamp.play()
		%Egg.visible = true
		%CobaltMarker.queue_free()

func _on_Egg_egg_taken():
	%Lamp.pause()
	%Lamp.frame = 0
	hasEgg = false
