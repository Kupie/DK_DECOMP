@tool
extends Node2D





@export var export: = false:
	set(b):
		$SubViewportContainer / SubViewport.get_texture().get_image().save_png("res://tool/NoiseCombiner/combined_noise.png")
