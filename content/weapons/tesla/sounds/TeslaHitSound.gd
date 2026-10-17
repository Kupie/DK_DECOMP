extends Node2D

func _ready():
	$Hit.startSound()

func _on_hit_sound_duration_elapsed() -> void :
	queue_free()
