extends Node2D

const IDLE_POS: = 375.0
const TARGET_POS: = 320.0

var teamId: String

var targetPos: = 0.0
var time: = 0.0
var speed: = 1.0
var levelIdlePos: = 0.0

@onready var crystalCenter = $"%CrystalCenter"

func init(teamId: String) -> void :
	self.teamId = teamId
	Data.listen(self, teamId + ".tesla.powervfx")

func _ready():
	$BG / RingBG.material.set_shader_parameter("palette", Style.palette)
	$"%CrystalPolarEffect".material.set_shader_parameter("palette", Style.palette)
	$"%TeslaCrystalAdditive".material.set_shader_parameter("palette", Style.palette)

const particleScale: = [0.4, 0.6, 0.9, 1.4, 2.0]
const particleAmount: = [2, 3, 4, 6, 8]
const idlePositions: = [0.0, 3.0, 8.0, 16.0, 28.0]
const polarSize: = [1.2, 1.4, 2.0, 2.6, 3.6]
func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".tesla.powervfx":
		$"%TeslaCrystal".frame = int(newValue)
		$"%TeslaCrystalAdditive".frame = int(newValue)
		$"%TeslaCrystalParticle".scale = Vector2.ONE * particleScale[int(newValue)]
		$"%TeslaCrystalParticle".amount = particleAmount[int(newValue)]
		$"%CrystalPolarEffect".scale = Vector2.ONE * polarSize[int(newValue)]
		levelIdlePos = idlePositions[int(newValue)]

func _process(delta):
	time = wrapf(time + delta, 0, TAU)
	var idlePos = IDLE_POS + levelIdlePos
	crystalCenter.position.y = lerp(crystalCenter.position.y, remap(targetPos, 0.0, 1.0, idlePos, TARGET_POS) + (sin(time) * 5.0 * targetPos), delta * speed)

func start():
	if Dome.weaponsStarted(teamId, 2):
		return
	$Crystal / StartDelay.start()

func stop():
	if Dome.weaponsStarted(teamId, 1):
		return
	$Crystal / StartDelay.stop()
	targetPos = 0
	speed = 6.0

func _on_StartDelay_timeout():
	targetPos = 1
	speed = 4.0
	$GoUpImpact / GoUpSparks.restart()
	$GoUpImpact / GoUpStatic.restart()
