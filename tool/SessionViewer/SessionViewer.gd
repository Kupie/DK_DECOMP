extends Node

var resolution: = 1000.0
@onready var listingContainer = find_child("Listing")

var currentData
var currentEntry
var displayMode: = 0
var selectedVersions: = []
var filesByVersion: Dictionary

func _ready():
	Backend.login()

	await Backend.loggedIn

	get_window().mode = Window.MODE_MAXIMIZED if (true) else Window.MODE_WINDOWED
	get_window().content_scale_size = CONST.BASE_RESOLUTION
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

	var versionsFile = FileAccess.open("user://sessions-by-version.txt", FileAccess.ModeFlags.READ)
	if versionsFile != null:
		var test_json_conv = JSON.new()
		filesByVersion = JSON.parse_string(versionsFile.get_as_text())
		var versions: = []
		for r in filesByVersion:
			versions.append(r)
		versions.sort()
		var group = ButtonGroup.new()
		for i in range(0, versions.size()):
			var v = versions[i]
			var b = Button.new()
			b.focus_mode = Button.FOCUS_NONE
			b.text = v
			b.toggle_mode = true
			b.button_group = group
			b.connect("toggled", Callable(self, "setVersionFilter").bind(v))
			find_child("VersionButtons").add_child(b)
		versionsFile.close()

	Style.init(self)

	start()

func setVersionFilter(active: bool, version: String):
	if active:
		selectedVersions.append(version)
	else:
		selectedVersions.erase(version)
	updateView()

func updateView():
	var sessions: = []
	for v in selectedVersions:
		sessions.append_array(filesByVersion[v])
	find_child("Listing").displayCachedSessions(sessions)

func start():
	find_child("RawDataPanel").visible = false
	find_child("PlottedDataPanel").visible = false
	listingContainer.visible = true
	listingContainer.start("Sessions", "compiled-sessions", "*.txt")
	listingContainer.connect("received_entry", showEntry)

func showEntryAsChart(entry):
	if not entry:
		return

	currentEntry = entry

	var data = JSON.parse_string(entry)
	find_child("PlottedDataPanel").visible = true
	find_child("RawDataPanel").visible = false

	clearContainer("RunButtons")

	var runs: = Backend.parseRunsFromSession(data)

	if runs.size() == 0:
		var l = Label.new()
		l.text = "no new runs"
		find_child("RunButtons").add_child(l)

	var i: = 1
	var buttonGroup = ButtonGroup.new()
	for run in runs:
		var b = Button.new()
		b.focus_mode = Button.FOCUS_NONE
		b.text = "Run " + str(i)
		b.button_group = buttonGroup
		b.toggle_mode = true
		b.connect("pressed", Callable(self, "plotRun").bind(run))
		if i == 1:
			plotRun(run)
			b.button_pressed = true
		find_child("RunButtons").add_child(b)
		Style.init(b)
		i += 1

func clearContainer(n: String):
	var container = find_child(n)
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()

func plotRun(data):
	currentData = data
	clearContainer("PlotContainer")
	clearContainer("Labels")

	if not data:
		return

	find_child("DurationLabel").text = "Duration: %.0fm" % (data.get("duration", 1) / 60000.0)
	find_child("ResultLabel").text = "Result: " + data.get("state", "unknown")
	find_child("VersionLabel").text = "Version: " + data["meta"].get("version", "unknown")
	find_child("PlatformLabel").text = "Platform: " + data["meta"].get("platform_name", "unknown")
	var time: Dictionary = data["meta"].get("date", {})
	find_child("DateLabel").text = "%02d/%02d/%d %02d:%02d" % [time.day, time.month, time.year, time.hour, time.minute]

	var plotContainer = find_child("PlotContainer")
	var lineBottom = plotContainer.size.y - 200

	var line: Line2D
	for d in data.get("waves"):
		var t = timeToX(d)
		if not line:
			line = Line2D.new()
			line.width = 500
			line.default_color = Color("0D2B45")
			line.add_point(Vector2(t, lineBottom - 250))
		else:
			line.add_point(Vector2(t, lineBottom - 250))
			plotContainer.add_child(line)
			line = null

	var ironLine = Line2D.new()
	ironLine.width = 3
	ironLine.default_color = Color.YELLOW
	var waterLine = Line2D.new()
	waterLine.width = ironLine.width
	waterLine.default_color = Color.CORNFLOWER_BLUE
	var sandLine = Line2D.new()
	sandLine.width = ironLine.width
	sandLine.default_color = Color.PURPLE



	var domeHealth = Line2D.new()
	domeHealth.width = ironLine.width
	domeHealth.default_color = Color.BROWN

	var indexLabel = Label.new()
	indexLabel.text = "iron"
	indexLabel.add_theme_color_override("font_color", Color.YELLOW)
	find_child("Labels").add_child(indexLabel)
	indexLabel = Label.new()
	indexLabel.text = "water"
	indexLabel.add_theme_color_override("font_color", Color.CORNFLOWER_BLUE)
	find_child("Labels").add_child(indexLabel)
	indexLabel = Label.new()
	indexLabel.text = "sand"
	indexLabel.add_theme_color_override("font_color", Color.PURPLE)
	find_child("Labels").add_child(indexLabel)
	indexLabel = Label.new()
	indexLabel.text = "health"
	indexLabel.add_theme_color_override("font_color", Color.BROWN)
	find_child("Labels").add_child(indexLabel)

	var allMetrics = data.get("cycles")
	for d in allMetrics:
		var metrics = d.get("data")
		var t = timeToX(d)
		ironLine.add_point(Vector2(t, lineBottom - metrics.get("i", 1) * 10))
		waterLine.add_point(Vector2(t, lineBottom - 3 - metrics.get("w", 1) * 10))
		sandLine.add_point(Vector2(t, lineBottom - 6 - metrics.get("s", 1) * 10))

		domeHealth.add_point(Vector2(t, lineBottom - metrics.get("health", 1) * 0.3))
	plotContainer.add_child(ironLine)
	plotContainer.add_child(waterLine)
	plotContainer.add_child(sandLine)

	plotContainer.add_child(domeHealth)
	var lastX = timeToX(allMetrics.back())
	plotContainer.custom_minimum_size.x = lastX + 100

	var bound = Line2D.new()
	bound.width = 8
	bound.default_color = Style.STRUCT_DARK
	bound.add_point(Vector2(4, lineBottom + 6))
	bound.add_point(Vector2(lastX + 4, lineBottom + 6))
	bound.add_point(Vector2(lastX + 4, 135))
	bound.add_point(Vector2(4, 135))
	bound.add_point(Vector2(4, lineBottom + 6))
	plotContainer.add_child(bound)

	var upgrades = data.get("upgrades")
	var last: = -100.0
	var off: = 0
	for d in upgrades:
		var l = Label.new()
		l.set("theme_override_fonts/font", preload("res://gui/fonts/FontSmall.tres"))
		l.set_rotation(PI * 0.25)
		l.text = d.get("data").capitalize()
		l.position.x = timeToX(d) + 6
		l.position.y = plotContainer.size.y - 180
		if abs(last - l.position.x) < 20:
			off += 26 + (l.position.x - last)
			l.position.y += off
		else:
			off = 0
		plotContainer.add_child(l)
		last = l.position.x

	var gadgets = data.get("gadgets")
	last = -100.0
	off = 0
	for d in gadgets:
		var l = Label.new()
		l.set("theme_override_fonts/font", preload("res://gui/fonts/FontSmall.tres"))
		l.set_rotation(PI * 1.75)
		l.text = d.get("data").capitalize()
		l.position.x = timeToX(d) + 6
		l.position.y = lineBottom - 650
		if abs(last - l.position.x) < 20:
			off += 28
			l.position.y += off
		else:
			off = 0
		plotContainer.add_child(l)
		last = l.position.x

	var gadgetUses = data.get("gadgetUses")
	last = -100.0
	off = 0
	for d in gadgetUses:
		var l = Label.new()
		l.set("theme_override_fonts/font", preload("res://gui/fonts/FontSmall.tres"))
		l.set_rotation(PI * 0.25)
		l.text = d.get("data").capitalize()
		l.position.x = timeToX(d) + 6
		l.position.y = lineBottom - 620
		if abs(last - l.position.x) < 20:
			off += 28
			l.position.y += off
		else:
			off = 0
		plotContainer.add_child(l)
		last = l.position.x

func timeToX(d: Dictionary):
	return 10 + d.get("time", 0) / resolution

func sortByTime(a, b):
	return a["time"] < b["time"]

func sortById(a, b):
	return a["id"] < b["id"]

func showEntryAsEventList(entry):
	if not entry:
		return

	currentEntry = entry

	var data = JSON.parse_string(entry)
	data.sort_custom(Callable(self, "sortById"))
	find_child("RawDataPanel").visible = true
	find_child("PlottedDataPanel").visible = false

	var grid = find_child("RawDataGridContainer")
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()

	for d in data:
		var type = d.get("type", "missing")
		var l = Label.new()
		l.set("theme_override_fonts/font", preload("res://gui/fonts/FontSmall.tres"))

		l.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		l.text = str(d.get("id", -1))
		grid.add_child(l)
		l = Label.new()
		l.set("theme_override_fonts/font", preload("res://gui/fonts/FontSmall.tres"))
		l.text = type.to_lower().replace("_", " ")
		grid.add_child(l)
		l = Label.new()
		l.set("theme_override_fonts/font", preload("res://gui/fonts/FontSmall.tres"))
		l.text = "%.0fs" % (d.get("time", 0) / 1000)

		l.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(l)
		l = Label.new()
		l.set("theme_override_fonts/font", preload("res://gui/fonts/FontSmall.tres"))
		l.size_flags_horizontal = Label.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AutowrapMode.AUTOWRAP_WORD_SMART
		l.text = str(d.get("data", ""))
		grid.add_child(l)

func _on_Listing_entry_selected() -> void :
	clearContainer("RunButtons")
	clearContainer("PlotContainer")
	find_child("DurationLabel").text = ""
	find_child("ResultLabel").text = ""
	find_child("VersionLabel").text = ""
	find_child("PlatformLabel").text = ""

func _on_ButtonPlus_pressed() -> void :
	resolution *= 0.5
	plotRun(currentData)

func _on_ButtonMinus_pressed() -> void :
	resolution *= 2
	plotRun(currentData)

func _on_ModeTextButton_pressed() -> void :
	displayMode = 1
	showEntry(currentEntry)

func _on_ModeChartsButton_pressed() -> void :
	displayMode = 0
	showEntry(currentEntry)

func showEntry(entry):
	if displayMode == 0:
		showEntryAsChart(entry)
	elif displayMode == 1:
		showEntryAsEventList(entry)
