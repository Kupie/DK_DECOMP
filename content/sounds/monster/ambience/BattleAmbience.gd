extends Node

var ambiences: = []
var canRun: = true
var _disabled: bool = false
var _team_id: String = ""


func init(inTeamID: String) -> void :
	_team_id = inTeamID
	Data.listen(self, _team_id + ".monsters.wavepresent")
	Data.listen(self, "game.over")
	for c in get_children():
		if c is AudioStreamPlayer:
			ambiences.append(c)

func disable() -> void :
	_disabled = true
	set_process(false)

func propertyChanged(property: String, oldValue, newValue):
	if _disabled:
		return
	var wave_present: String = _team_id + ".monsters.wavepresent"
	match property:

		wave_present:
			if newValue:
				canRun = true
				for c in ambiences:
					c.roundStarts()
			else:
				canRun = false
				for c in ambiences:
					c.update(0)
		"game.over":
			if newValue == "won" or newValue == "lost":
				canRun = false
				for c in ambiences:
					c.update(0)

func _process(delta):
	if _disabled:
		return
	if not canRun and not GameWorld.forceBattleAmbienceEnabled:
		return

	var monsters = get_tree().get_nodes_in_group(_team_id + "-monster")
	var countByType: = {}
	for m in monsters:
		countByType[m.techId] = countByType.get(m.techId, 0) + 1

	for c in ambiences:
		var type = c.name.substr(0, c.name.find("_")).to_lower()
		c.update(countByType.get(type, 0))
