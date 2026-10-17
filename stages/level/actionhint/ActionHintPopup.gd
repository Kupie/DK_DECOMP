extends Container

@onready var container = $Container

var teamId: String

var entries: Array[Entry]

func _ready():
	Data.listen(self, "options.changed")
	update_visible(true)

func init(teamId: String) -> void :
	self.teamId = teamId
	Data.listen(self, teamId + ".event.keepers.insidestation")

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".event.keepers.insidestation":
		update_visible(false)
	elif property == "options.changed":
		update_visible(true)

var tw
func update_visible(instant):
	var vis = not Keepers.oneInsideStation() and not Options.hideActionHints
	if vis == self.visible:
		return

	if tw:
		tw.kill()

	if not vis or instant:
		self.visible = vis
	else:

		tw = create_tween()
		self.visible = true
		modulate = Color(1, 1, 1, 0)
		tw.tween_property(self, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(1)

func register_hint(action: String, label: String) -> int:
	var e = Entry.new()
	e.action = action
	e.label = label
	e.shown = false
	entries.append(e)
	return entries.size() - 1

func show_hint(index: int):
	if index == -1:
		return

	if entries[index].shown:
		return

	entries[index].shown = true
	rebuild_hints()

func hide_hint(index: int):
	if index == -1:
		return

	if not entries[index].shown:
		return

	entries[index].shown = false
	rebuild_hints()

func rebuild_hints():
	return










func add_modifiers_to_duplicate_action():

	var map: = {}

	for n in container.get_children():
		n = n.action
		var arr: = [n]

		while (n.clone):
			arr.append(n.clone)
			n = n.clone

		for x in arr:
			var key = x.label_text
			if key == "":
				key = x.texture.get_path()

			if map.has(key):
				map[key].append(x)
			else:
				map[key] = [x]

	for x in map:
		var arr = map[x]

		if arr.size() <= 1:
			continue
		for i in len(arr):
			arr[i].setModifier(i + 1)

func create_entry_for(e: Entry):
	var inst = preload("res://stages/level/actionhint/action_hint_entry.tscn").instantiate()
	container.add_child(inst)
	inst.setup(e.action, e.label)


class Entry:
	var action: String
	var label: String
	var shown: bool
