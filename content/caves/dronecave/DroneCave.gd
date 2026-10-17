extends "res://content/caves/Cave.gd"

@export var synchronizer: DroneCaveSynchronizer

var hasDrone: = true
var opening: = false
var teamId: String

func _ready():
	super._ready()
	$Drone.visible = true
	$Door.play("default")
	$Drone.play("idle")

	Style.init($Drone)

func serialize() -> Dictionary:
	var data = super.serialize()
	data["hasDrone"] = hasDrone
	data["opening"] = opening
	data["teamId"] = teamId
	data["resourceused"] = $ResourceGrabber.spent
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	hasDrone = data["hasDrone"]
	opening = data["opening"]
	teamId = data.get("teamId", "team1")
	$DroneDispatcher.init(teamId)
	$ResourceGrabber.spent = data.get("resourceused", false)
	$ResourceGrabber.teamId = teamId

	if not hasDrone:
		$Drone.visible = false
		$Door.visible = false
	if opening:
		$Door.play("opening")

	if currentState == State.REVEALED:
		find_child("AmbSound").startSound()

func onRevealed():
	find_child("AmbSound").startSound()

func _on_door_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Door_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	if $Door.animation == "opening" and hasDrone:
		$Door.visible = false
		if multiplayer.is_server():
			$Tween.interpolate_callback(self, 2.0, "networkSpawnDrone")
			$Tween.start()

func networkSpawnDrone() -> void :
	synchronizer.network_rpc(spawnDrone.bind(randi(), $ResourceGrabber.teamId), true)

@rpc("reliable")
func spawnDrone(uid: int, teamId: String):
	$DroneDispatcher.init(teamId)

	if teamId == "":
		Logger.error("would like to spawn squidley, but the resource grabber does not have a team set via the drop that was delivered", "DroneCave.spawnDrone")
		return
	var gizmo = preload("res://content/gadgets/droneyard/Squidley.tscn").instantiate()
	gizmo.UID = uid
	gizmo.position = $Drone.global_position
	gizmo.teamId = teamId
	$Drone.queue_free()
	Level.map.addDrop(gizmo)
	$DroneDispatcher.assignDrone(gizmo)
	$DroneDispatcher.teamId = teamId
	hasDrone = false
	opening = false
	$Background / DroneTakenSound.startSound()

func _on_ResourceGrabber_grabbed_resource():
	synchronizer.network_rpc(playOpeningVisuals.bind($ResourceGrabber.teamId), true)

@rpc("reliable")
func playOpeningVisuals(teamId: String) -> void :
	$Door.play("opening")
	$DoorOpenSound.startSound()
	opening = true
	self.teamId = teamId
