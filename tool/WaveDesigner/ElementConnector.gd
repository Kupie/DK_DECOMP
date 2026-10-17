extends Line2D

signal timeIndexChanged

var from
var to
var center: Vector2

var timeIndex: int

func init(timeIndex: = 2):
	self.timeIndex = timeIndex
	var p1 = from.position + Vector2(from.size.x * 0.5, 60)
	var p2 = to.position + Vector2(to.size.x * 0.5, 60)
	add_point(p1)
	add_point(p2)
	center = (p1 + p2) * 0.5
	$PanelContainer / VBoxContainer / HSlider.value = timeIndex
	_on_HSlider_value_changed(timeIndex)
	$PanelContainer.position = center - $PanelContainer.size * 0.5

func _on_HSlider_value_changed(value):
	self.timeIndex = value
	find_child("Label1").text = str(timeIndex) + ":"
	find_child("Label2").text = str(Data.gameProperties.get("monsters.timebetweenmonsters")[value]) + "s"
	emit_signal("timeIndexChanged", timeIndex)
