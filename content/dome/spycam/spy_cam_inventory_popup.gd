extends MarginContainer

var isIn: = false

func _ready() -> void :
	Style.init(self)

func setTeam(teamId: String):
	%Inventory.teamId = teamId
	%Inventory.init()
	%HealthMeter.teamId = teamId
	%HealthMeter.init()
	%HealthMeter.scale = Vector2.ONE * 4

func moveIn(delay: = false):
	var t: = create_tween()
	modulate.a = 0.0
	t.tween_property(self, "modulate:a", 1.0, 0.2).set_delay(2.0)

func moveOut(free: = false):
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	if free:
		t.tween_callback(queue_free).set_delay(0.31)
