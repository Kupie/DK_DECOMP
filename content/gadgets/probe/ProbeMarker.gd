extends Node2D
class_name ProbeMarker

signal on_show

var teamId: String

var center: Vector2
@export var sound: Sound
var tileCoord: Vector2

func _ready():
	var distance = position.distance_to(center)
	if distance > 0.0:

		$Timer.wait_time = distance / Data.of(teamId + ".probe.impulseSpeed")
		$Timer.start()
		hide()
		Level.map.addTileRevealedListener(self, tileCoord)

	add_to_group(teamId + "-probe_markers")

	Style.init($Sprite2D)

func serialize() -> Dictionary:
	var data = {}
	if visible:
		data["remainingtime"] = $Timer.time_left
	else:
		data["remainingtime"] = Data.of(teamId + ".probe.markerRetention")
	data["tileCoord"] = var_to_str(tileCoord)
	data["meta.priority"] = 100
	data["meta.kind"] = "generic"
	return data

func deserialize(data: Dictionary):
	startTimer(data["remainingtime"])
	tileCoord = BackwardCompatibilityUtils.str_to_var(data["tileCoord"])
	Level.map.addTileRevealedListener(self, tileCoord)

func startTimer(remainingTime: float) -> void :
	$Timer.start(remainingTime)
	show()
	$Sprite2D.play("ping")

func _on_Timer_timeout():
	if visible:
		remove()
	else:
		show()
		$Sprite2D.play("ping")
		if sound:
			sound.play()
		$Timer.wait_time = Data.of(teamId + ".probe.markerRetention")
		$Timer.start()

func refresh():
	$Timer.start(0)

func remove():
	Level.map.removeTileRevealedListener(self, tileCoord)

	if (sound and sound.shouldPlay):

		create_tween().tween_callback(queue_free).set_delay(3)
	else:
		queue_free()

func tileRevealed(tileCoord: Vector2):
	remove()

func pauseChanged():
	$Timer.paused = GameWorld.paused

func setupEchoSound(t) -> void :
	match t:
		Data.TILE_IRON: sound.pitch_scale = 1.69
		Data.TILE_SAND: sound.pitch_scale = 2.52
		Data.TILE_WATER: sound.pitch_scale = 1.98
		Data.TILE_CAVE:
			sound.pitch_scale = 1.1
			sound.baseVolume -= 4.0
		Data.TILE_GADGET:
			sound.pitch_scale = 1.1
			sound.baseVolume -= 4.0
