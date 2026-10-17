extends Node2D

func _ready() -> void :
	$Sparks.restart()

func _on_sparks_finished() -> void :
	queue_free()
