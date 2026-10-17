@tool
class_name CrossFader extends Node

signal finished
signal finished_player(player: AudioStreamPlayer)

@export var volume_db: float = 0.0:
	set(value):
		volume_db = clamp(value, -80.0, 6.0)
		_update_volume()

	get:
		return volume_db

var bus: StringName = &"Master":
	set(value):
		bus = value
		_update_bus()

	get:
		return bus

@onready var player_a: AudioStreamPlayer = %Player_01
@onready var player_b: AudioStreamPlayer = %Player_02

var stream: AudioStream
var tween: Tween

var fade: float = 1.0:
	set(value):
		fade = clamp(value, 0.0, 1.0)
		_update_volume()
	get:
		return fade

var playing:
	get:
		return player_a.playing or player_b.playing

var players: Array[AudioStreamPlayer]

var _fadeout_is_a: bool

func get_playback_position() -> float:
	return player_b.get_playback_position() if _fadeout_is_a else player_a.get_playback_position()

func stop():
	player_a.stop()
	player_b.stop()

func play(from_position: float = 0.0):
	player_a.stream = stream
	player_a.play(from_position)
	player_a.volume_db = volume_db
	_fadeout_is_a = false
	player_b.stop()

func fade_to(target_stream: AudioStream, start_at_position: float = 0.0, fade_duration: float = 3.0):
	if stream == target_stream:
		return

	if tween:
		push_warning("Trying to fade while already fading. Killing old fade")
		tween.kill()
		tween = null

	stream = target_stream

	var fadeout_player: = player_a if player_a.playing else player_b
	var fadein_player: = player_b if fadeout_player == player_a else player_a
	_fadeout_is_a = (fadeout_player == player_a)

	fadein_player.stream = target_stream
	fadein_player.play(start_at_position)

	fade = 0.0
	_update_volume()
	tween = create_tween()
	tween.tween_property(self, "fade", 1.0, fade_duration)

	tween.finished.connect( func():
		fadeout_player.stop()
		fade = 1.0
		tween = null
	)

func _update_volume() -> void :
	if not is_node_ready():
		return

	var weight_fadeout: = cos(fade * PI * 0.5)
	var weight_fadein: = sin(fade * PI * 0.5)

	var weight_a: = weight_fadeout if _fadeout_is_a else weight_fadein
	var weight_b: = weight_fadein if _fadeout_is_a else weight_fadeout

	player_a.volume_db = _mix_db(volume_db, weight_a)
	player_b.volume_db = _mix_db(volume_db, weight_b)

func _mix_db(master_db: float, weight: float) -> float:
	if weight <= 0.0001:
		return -80.0
	return clamp(master_db + linear_to_db(weight), -80.0, 6.0)

func _ready() -> void :
	players.append(player_a)
	players.append(player_b)
	_update_volume()
	_update_bus()

func _update_bus():
	if not is_node_ready():
		return
	player_a.bus = bus
	player_b.bus = bus

func _get_property_list():
	return [{
		"name": "bus", 
		"type": TYPE_STRING_NAME, 
		"hint": PROPERTY_HINT_ENUM, 
		"hint_string": _get_bus_list()
	}]

func _get_bus_list() -> String:
	var buses: = []
	for i in AudioServer.get_bus_count():
		buses.append(AudioServer.get_bus_name(i))
	return ",".join(buses)

func _on_player_b_finished() -> void :
	finished_player.emit(player_b)
	finished.emit()

func _on_player_a_finished() -> void :
	finished_player.emit(player_a)
	finished.emit()
