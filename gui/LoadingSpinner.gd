extends HBoxContainer

var tex: = [
	preload("res://content/monster/walker/monster1_stun0.png"), 
	preload("res://content/monster/walker/monster1_stun1.png"), 
	preload("res://content/monster/walker/monster1_stun2.png"), 
	preload("res://content/monster/walker/monster1_stun3.png")
]

var index: = 0

func _ready():
	spin()

func spin():
	visible = true
	$Timer.start(0.125)

func stop():
	visible = false
	$Timer.stop()

func _on_Timer_timeout() -> void :
	index = (index + 1) % 4
	$TextureRect1.texture = tex[index]


	$Timer.start(0.125)
