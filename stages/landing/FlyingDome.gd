extends Node2D

signal finished

func _ready():
	$DomeSprite.play("default")
	Style.init(self)
