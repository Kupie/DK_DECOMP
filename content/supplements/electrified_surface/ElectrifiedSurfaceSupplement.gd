extends Node2D

var teamId: String

@onready var electrifiedSurfaceParticles = $ElectrifiedSurfaceParticles
var active: = false

func init(teamId: String):
	self.teamId = teamId
	hide()
	set_process(false)
	Data.listen(self, teamId + ".dome.electrifiedsurface")
	Data.listen(self, teamId + ".monsters.wavepresent")


func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".monsters.wavepresent":
		active = newValue
		electrifiedSurfaceParticles.emitting = active
	elif property == teamId + ".dome.electrifiedsurface":
		if newValue:
			show()
			set_process(true)

func _process(delta):


	var particlePos: Vector3 = get_parent().getCupolaPosition(wrapf(Time.get_ticks_msec() / 100.0, 0.05, 0.97), teamId)
	electrifiedSurfaceParticles.global_position = Vector2(particlePos.x, particlePos.y) + Vector2(0, -10).rotated(particlePos.z)
	electrifiedSurfaceParticles.rotation = particlePos.z
