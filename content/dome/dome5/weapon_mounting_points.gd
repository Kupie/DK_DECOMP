extends Node2D

func get_mounting_point(left: bool, slot: int):
	return get_node(str(slot) + ("left" if left else "right"))
