extends "res://content/caves/Cave.gd"

@export var drillbots: DrillbotSynchronizer

@onready var DrillMother = %Drillmother

var cooldown: = 0.0
var sleeping: = true
var woke: = false
var triggered: = false
var looking: = false
var transitioning: = false
var triggerCount: = 0

func _ready():
	super._ready()
	Level.map.addSpriteToBGAlpha($AlphaMap)

func _process(delta):
	if currentState == State.REVEALED:
		if triggered or transitioning:
			return

		if cooldown > 0.0:
			cooldown -= delta
			return

		var keeperDist: float = 999990.0
		for keeper in Keepers.getAll():
			keeperDist = min(keeperDist, (keeper.global_position - DrillMother.global_position).length())

		var minTreatDist: = 999
		for treat in get_tree().get_nodes_in_group("treat"):
			minTreatDist = min(minTreatDist, (DrillMother.global_position - treat.global_position).length())

		var minDrillbertDist: = 999
		for drillbert in get_tree().get_nodes_in_group("drillbots"):
			minDrillbertDist = min(minDrillbertDist, (DrillMother.global_position - drillbert.global_position).length())

		if (minTreatDist < 100 or minDrillbertDist < 100) and sleeping and not triggered:
			DrillMother.play("wake")
			%RaiseSound.startSound()
			%SleepingLoop.stop()
			transitioning = true
			return

		if woke and minTreatDist > 140 and minDrillbertDist > 140:
			DrillMother.play("liedown")
			%LieDownSound.startSound()
			%SleepingLoop.startSound()
			transitioning = true
			return

		if sleeping:
			if looking:
				if keeperDist > 100:
					transitioning = true
					DrillMother.play("closeeyes")
					%SleepingLoop.startSound()
			else:
				if keeperDist < 60:
					transitioning = true
					DrillMother.play("openeyes")
					%LookingSound.startSound()
					%SleepingLoop.stop()

func onRevealed():
	DrillMother.play("sleeping")
	%SleepingLoop.startSound()

func _on_drillmother_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Drillmother_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	transitioning = false
	match DrillMother.animation:
		"openeyes":
			looking = true
		"closeeyes":
			DrillMother.play("sleeping")
			looking = false
		"liedown":
			DrillMother.play("sleeping")
			sleeping = true
			looking = false
			woke = false
		"wake":
			DrillMother.play("idle")
			sleeping = false
			woke = true
		"eat":
			if triggerCount == 0:
				GameWorld.runModifiersToUnlock.append("drillbert")
			triggerCount += 1
			cooldown = 60 * triggerCount
			triggered = false
			woke = false
			sleeping = true
			$ResourceGrabber.spent = false
			DrillMother.play("sleeping")
			%SleepingLoop.startSound()

func _on_ResourceGrabber_grabbed_resource():
	triggered = true
	DrillMother.play("eat")
	%EatSound.startSound()

func spawnDrillbot():
	if $ResourceGrabber.teamId == "":
		Logger.error("would like to spawn drillbert, but the resource grabber does not have a team set via the drop that was delivered", "DrillbertCave.spawnDrillbot")
		return

	if multiplayer.is_server():
		var drillbot: Drillbot = Level.drops.network_spawn({
			"type": CONST.DRILLBOT, 
			"team": $ResourceGrabber.teamId, 
			"position": %DropPosition.global_position, 
			"carriers": [], 
			"impulse": Vector2(-30, -2), 
			"gravityScale": 0.0
		})
		drillbots.network_track_drillbot(drillbot)
		drillbot.stableTime = -1.0
		drillbot.startFalling(false)
		drillbot.fadeIn()
		drillbots.network_fade_in(drillbot.UID)

func _on_Drillmother_frame_changed():
	if triggered and (DrillMother.frame == 13 or DrillMother.frame == 30):
		spawnDrillbot()
