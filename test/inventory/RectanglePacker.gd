extends Node2D

var polies: = []
var rects: = []
var colors: = []

func _ready():
	randomize()
	for i in range(0, 10):
		var x = 5 + randi() % 16
		var y = 5 + randi() % 16
		var rect = Rect2(0, 0, x, y)
		rects.append(rect)
		colors.append(Color(randf(), randf(), randf()))

func sortByHeight(a, b):

	return a.size.x * a.size.y > b.size.x * b.size.y


func _on_UpdateButton_pressed():
	rects.sort_custom(Callable(self, "sortByHeight"))
	var bestWeight: = 999999999
	var bestRects: Array
	var bestHeight: int
	for height in range(10, 50):
		var placedRects: = []
		for rect in rects:
			placeRect(rect, placedRects, height)

		if placedRects.size() < rects.size():
			continue

		var weight = getWeight(placedRects)
		if weight < bestWeight:
			bestWeight = weight
			bestRects = placedRects
			bestHeight = height
	renderBackground(bestRects)
	renderRects(bestRects, bestHeight)

func getWeight(r: Array):
	var weight: = 0
	for rect in r:
		weight += pow(rect.position.x, 3) + pow(rect.position.y, 3) + rect.position.x * rect.position.y
	return weight

func renderBackground(r: Array):
	var p: PackedVector2Array = []
	for rect in r:
		p.append(rect.position)
		p.append(Vector2(rect.end.x, rect.position.y))
		p.append(rect.end)
		p.append(Vector2(rect.position.x, rect.end.y))
	var hullPoints = Geometry2D.convex_hull(p)
	var poly = Polygon2D.new()
	poly.color = Color.ALICE_BLUE
	poly.set_polygon(hullPoints)
	add_child(poly)

func renderRects(r: Array, height: int):
	for p in polies:
		p.queue_free()
	polies.clear()

	var maxX: = 0
	var maxY: = 0
	var i: = 0
	for rect in r:
		maxX = max(rect.end.x, maxX)
		maxY = max(rect.end.y, maxY)
		var poly = Polygon2D.new()
		var p: PackedVector2Array = []
		p.append(rect.position)
		p.append(Vector2(rect.end.x, rect.position.y))
		p.append(rect.end)
		p.append(Vector2(rect.position.x, rect.end.y))
		poly.color = colors[i]
		poly.set_polygon(p)
		add_child(poly)
		polies.append(poly)
		i += 1

	$ReferenceRect1.size.x = maxX + 2
	$ReferenceRect1.size.y = maxY + 2
	$ReferenceRect2.size.x = 164
	$ReferenceRect2.size.y = height + 4

	$CanvasLayer / Label.text = str(maxX) + "x" + str(maxY) + " = " + str(maxX * maxY)
	$CanvasLayer / Label.text = str(getWeight(r) * 0.001)

func placeRect(rect: Rect2, placedRects: Array, allowedHeight: int, allowedWidth: = 200):
	for x in range(0, allowedWidth):
		for y in range(0, allowedHeight):
			if allowedHeight <= y + rect.size.y:
				break
			rect.position.x = x
			rect.position.y = y
			var intersect: = false
			for p in placedRects:
				if rect.intersects(p):
					intersect = true
					break
			if intersect:
				continue
			else:
				var r = Rect2(x, y, rect.size.x, rect.size.y)
				placedRects.append(r)
				return

func _on_HSlider_value_changed(value):
	var placedRects: = []
	for rect in rects:
		placeRect(rect, placedRects, value)
	$CanvasLayer / SliderValue.text = str(value)
	renderRects(placedRects, value)
