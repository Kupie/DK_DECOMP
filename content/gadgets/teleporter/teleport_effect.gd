class_name TeleportEffect extends "res://content/keeper/keeper2/CustomStyle_ChangeModulate.gd"

signal finished


func _on_use_particles_finished() -> void :
	finished.emit()
