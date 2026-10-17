extends Node2D

func _ready():
	$DripsSfx.startSound()


func _on_Timer_timeout():
	$GPUParticles2D.emitting = true
	$Timer.wait_time = randf_range(1, 4)
	$Timer.start()
