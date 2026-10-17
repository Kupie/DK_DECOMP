extends "res://stages/loadout/LoadoutChoice.gd"

var assignmentId: String
var progress: int
var assignmentProgress: int

func onLocaleChanged():
	setAssignment(assignmentId, progress, assignmentProgress)

func setAssignment(_assignmentId: String, _progress: int, _assignmentProgress: int):
	assignmentId = _assignmentId
	progress = _progress
	assignmentProgress = _assignmentProgress

	setChoice(tr("assignment." + assignmentId + ".title"), assignmentId, null, "")

	%Badge1.visible = progress >= 1
	%Badge2.visible = progress == 2

	var assignment: Assignment = Data.assignments.get(assignmentId)
	%ModIcon.visible = assignment.isMod

	var missingBadges = assignment.tier - assignmentProgress
	if assignment.tier > assignmentProgress:
		set_enabled(false)
		%LabelDesc.text = tr("level.assignment.badges.unlock") % missingBadges
		%LabelDesc.visible = true
