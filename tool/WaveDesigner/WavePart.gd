extends PanelContainer

signal newElementCreated
signal dropElement
signal dragExistingElement
signal request_up
signal request_down

const firstWeight: = Vector2(3, 1)
const connectorWeight: = Vector2(1, 2)

var delays: = {}
var elementCount: = 0

func init(data: Array):
	var connector
	var lastE
	for s in data:
		if s.begins_with("wait."):
			connector = preload("res://tool/WaveDesigner/ElementConnector.tscn").instantiate()
			connector.from = lastE
			connector.timeIndex = int(s.split(".")[1])
		else:
			var e
			if s.begins_with("add."):
				e = preload("res://tool/WaveDesigner/WaveElement.tscn").instantiate()
			else:
				e = preload("res://tool/WaveDesigner/WaveConnector.tscn").instantiate()

			emit_signal("newElementCreated", e)
			$WaveElementContainer.add_child(e)
			e.enableMouse()
			e.mouse_filter = Control.MOUSE_FILTER_STOP
			e.connect("selected", Callable(self, "dragExistingElement").bind(e))
			e.connect("remove", Callable(self, "removeElement").bind(e))
			if s.begins_with("add."):
				var parts = s.split(".")
				e.init(parts[1], parts[2])
			e.showVariants()
			if connector:
				connector.to = e
				var h = lastE.name + e.name
				connector.connect("timeIndexChanged", Callable(self, "timeIndexChanged").bind(h))
				connector.init(connector.timeIndex)
				$WaveElementConnectors.add_child(connector)
				connector = null
			lastE = e

	call_deferred("layout")

func connectElements():
	for c in $WaveElementConnectors.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()

	var currentElement
	var bestWeight: = 9999999
	var elements = $WaveElementContainer.get_children().duplicate()
	for e in elements:
		var weight = firstWeight * e.position
		if weight.length() < bestWeight:
			bestWeight = weight.length()
			currentElement = e

	while currentElement:
		elements.erase(currentElement)
		var nextElement
		var lowestDistance = 9999999
		for e in elements:
			var diff = e.position - currentElement.position
			diff *= connectorWeight
			if diff.length() < lowestDistance:
				lowestDistance = diff.length()
				nextElement = e
		if nextElement:
			var connector = preload("res://tool/WaveDesigner/ElementConnector.tscn").instantiate()
			var h = currentElement.name + nextElement.name
			connector.from = currentElement
			connector.to = nextElement
			connector.init(delays.get(h, 2))
			$WaveElementConnectors.add_child(connector)
			connector.connect("timeIndexChanged", Callable(self, "timeIndexChanged").bind(h))
		currentElement = nextElement

	call_deferred("updateWeight")

func updateWeight():
	var s: = []
	var w = WaveSnippet.new()
	for entry in serialize():
		w.addEntry(WaveEntry.new(entry))
	find_child("WeightLabel").text = str(w.getWeight())

func timeIndexChanged(index, h):
	delays[h] = index
	updateWeight()

func _on_DeleteButton_pressed():
	queue_free()

func layout():
	var conns = $WaveElementConnectors.get_children()
	var pos = Vector2(260, 26)
	if conns.size() == 0:
		if $WaveElementContainer.get_child_count() > 0:
			$WaveElementContainer.get_children().front().position = pos
		call_deferred("updateWeight")
		return
	conns.front().from.position = pos
	for conn in conns:
		pos.x += 250
		conn.to.position = pos
	call_deferred("connectElements")

func _on_WavePart_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		emit_signal("dropElement", self, event.position)

func dropDraggedElement(draggedElement, dropPosition: Vector2, dragOffset: Vector2):
	draggedElement.get_parent().remove_child(draggedElement)
	$WaveElementContainer.add_child(draggedElement)
	draggedElement.enableMouse()
	draggedElement.position = dropPosition - $WaveElementContainer.position
	draggedElement.position.x -= dragOffset.x
	draggedElement.position.y -= dragOffset.y
	draggedElement.mouse_filter = Control.MOUSE_FILTER_STOP
	if not draggedElement.is_connected("selected", Callable(self, "_dragExistingElement")):
		draggedElement.connect("selected", Callable(self, "_dragExistingElement").bind(draggedElement))
		draggedElement.connect("remove", Callable(self, "removeElement").bind(draggedElement))
	draggedElement.showVariants()
	call_deferred("connectElements")

func _dragExistingElement(type, pos, draggedElement):
	emit_signal("dragExistingElement", type, pos, draggedElement)
	if draggedElement.is_connected("selected", Callable(self, "_dragExistingElement")):
		draggedElement.disconnect("selected", Callable(self, "_dragExistingElement"))
		draggedElement.disconnect("remove", Callable(self, "removeElement"))

	call_deferred("connectElements")

func removeElement(el):
	call_deferred("connectElements")

func serialize() -> Array:
	var connectors = find_child("WaveElementConnectors").get_children()

	if connectors.size() > 0:
		var out: = [connectors.front().from.serialize()]
		for c in connectors:
			out.append("wait." + str(c.timeIndex))
			out.append(c.to.serialize())
		return out
	else:
		var c = find_child("WaveElementContainer").get_children()
		if c.size() == 0:
			return []
		else:
			return [c.front().serialize()]

func _on_UpButton_pressed():
	get_parent().move_child(self, max(0, get_index() - 1))

func _on_DownButton_pressed():
	get_parent().move_child(self, get_index() + 1)
