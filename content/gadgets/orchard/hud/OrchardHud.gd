extends HudElement

enum State{EMPTY, GROWING, READY, CONSUMING}

const PLANT_SIZE: = 14.0
const PLANT_POSY: = -7

var hadAbilityOvercharge: bool

var buffed: bool
var buffDuration: float
var maxBuffDuration: float
var growth: float
var currentState = -1

@onready var PlantGrowing = $Background / PlantGrowing
@onready var PlantEating = $Background / PlantEating

func init():
	super.init()
	var durationCycles: float = Data.ofOr(teamId + ".orchard.buffduration", 0.0)
	maxBuffDuration = GameWorld.getTimeBetweenWaves(teamId) * durationCycles
	Data.listen(self, playerId + ".orchard.remainingbuffduration", true)
	Data.listen(self, teamId + ".orchard.currentgrowth", true)
	Data.listen(self, teamId + ".orchard.battleabilityuses", true)
	Data.listen(self, teamId + ".orchard.remainingbattleuses", true)
	Data.listen(self, teamId + ".orchard.overchargeabilityuses")
	Data.listen(self, teamId + ".orchard.overcharged")
	update()

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".orchard.overcharged":
		if newValue:
			$Slot2 / Blocked.visible = false
			hadAbilityOvercharge = true
	elif property == teamId + ".orchard.battleabilityuses":
		updateSlots()
	elif property == teamId + ".orchard.overchargeabilityuses":
		updateSlots()
	elif property == teamId + ".orchard.remainingbattleuses":
		$Slot1 / Charge.visible = newValue >= 1
		$Slot2 / Charge.visible = newValue >= 2
		if newValue == 0:
			hadAbilityOvercharge = false
		elif newValue == 2:
			hadAbilityOvercharge = true
		$Slot2 / Blocked.visible = not hadAbilityOvercharge and not Data.of(teamId + ".orchard.overcharged")
	elif property == teamId + ".orchard.currentgrowth":
		growth = newValue
		update()
	elif playerId + ".orchard.remainingbuffduration":
		buffed = newValue > 0.0
		if maxBuffDuration < newValue:
			maxBuffDuration = newValue
		buffDuration = newValue
		update()

func updateSlots():
	var slots = Data.of(teamId + ".orchard.battleabilityuses") + Data.of(teamId + ".orchard.overchargeabilityuses")
	$Background.position.y = 9 + slots * 5
	element_size.y = 3 + slots
	$Slot1.visible = slots >= 1
	$Slot2.visible = slots >= 2
	emit_signal("request_rebuild")

func update():
	var state: = -1
	if buffed:
		state = State.CONSUMING
	else:
		if growth > 0.0:
			if growth >= 1.0:
				state = State.READY
			else:
				state = State.GROWING
		else:
			state = State.EMPTY


	if state != currentState:
		match state:
			State.EMPTY:
				PlantEating.visible = false
				PlantGrowing.visible = false
				$Background.play("empty")
			State.GROWING:
				$Background.play("producing")
				PlantGrowing.visible = true
				PlantEating.visible = false
				PlantGrowing.position.y = PLANT_POSY
				PlantGrowing.region_rect.position.y = 0
				PlantGrowing.region_rect.size.y = PLANT_SIZE
			State.READY:
				$Background.play("ready")
				PlantGrowing.visible = true
				PlantEating.visible = false
				PlantGrowing.position.y = PLANT_POSY
				PlantGrowing.region_rect.position.y = 0
				PlantGrowing.region_rect.size.y = PLANT_SIZE
			State.CONSUMING:
				$Background.play("consuming")
				PlantGrowing.visible = false
				PlantEating.visible = true
				PlantEating.position.y = PLANT_POSY
				PlantEating.region_rect.position.y = 0
				PlantEating.region_rect.size.y = PLANT_SIZE

	currentState = state

	match currentState:
		State.GROWING:
			var rel = PLANT_SIZE * growth
			PlantGrowing.region_rect.size.y = rel
			PlantGrowing.region_rect.position.y = PLANT_SIZE - rel
			PlantGrowing.position.y = PLANT_POSY + PlantGrowing.region_rect.position.y
		State.CONSUMING:
			var rel = PLANT_SIZE * buffDuration / maxBuffDuration
			PlantEating.region_rect.size.y = rel
			PlantEating.region_rect.position.y = PLANT_SIZE - rel
			PlantEating.position.y = PLANT_POSY + PlantEating.region_rect.position.y
