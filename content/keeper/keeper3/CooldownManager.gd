extends Node

class_name CooldownManager

signal cooldown_ready(name: String)

var cooldowns: Dictionary = {}

func _process(delta):
	if GameWorld.paused:
		return
	for cooldown_name in cooldowns.keys():
		if cooldowns[cooldown_name] > 0:
			cooldowns[cooldown_name] -= delta
			if cooldowns[cooldown_name] <= 0:
				cooldowns[cooldown_name] = 0
				emit_signal("cooldown_ready", cooldown_name)

func set_cooldown(cooldown_name: String, duration: float) -> void :
	cooldowns[cooldown_name] = duration

func is_ready(cooldown_name: String) -> bool:
	return not cooldowns.has(cooldown_name) or cooldowns[cooldown_name] <= 0.0

func get_remaining(cooldown_name: String) -> float:
	return cooldowns.get(cooldown_name, 0.0)
