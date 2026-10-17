extends Node

func _ready():
	GameWorld.prepareCleanData()
	var i = preload("res://content/keeper/KeeperInputProcessor.gd").new()
	i.keeper = $Keeper
	i.integrate(self)
	Style.setPalette("palette_1_1")
	Style.init(self)

func _process(delta):
	if Input.is_action_pressed("f4"):
		var d = preload("res://content/drop/iron/IronDrop.tscn").instantiate()
		d.position.x = randf_range(-50, 50)
		d.position.y = randf_range(-50, 50)
		add_child(d)
