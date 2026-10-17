extends Node2D

enum BlendMode{NORMAL, OVERLAY, COLORDODGE}


func _ready():
	_on_BlendModeButton_item_selected($BlendModeButton.selected)


func _on_BlendModeButton_item_selected(index):
	if index == BlendMode.NORMAL:
		$A.material = null

	if index == BlendMode.OVERLAY:
		$A.material = preload("res://systems/style/materials/overlay_material.tres")

	if index == BlendMode.COLORDODGE:
		$A.material = preload("res://systems/style/materials/colordodge_material.tres")


func _on_fgopacity_value_changed(value):
	$A.modulate.a = float(value) / float($fgopacity.max_value)
