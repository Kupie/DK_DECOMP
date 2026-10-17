extends HudElement

var stage: int
var maxFilling: int
var currentgrowth: float
var pxFromRepellentStrength: float
var pxFromCharges: float
var maxAbilityDuration: = 0.0

func init():
	super.init()
	Data.listen(self, teamId + ".repellent.remainingbattleuses", true)
	Data.listen(self, teamId + ".repellent.battleuses", true)

	Data.listen(self, teamId + ".repellent.stage", true)
	Data.listen(self, teamId + ".repellent.currentgrowth", true)
	Data.listen(self, teamId + ".repellent.overcharged", true)
	Data.listen(self, teamId + ".repellent.remainingabilityduration", true)

	$Bar.visible = true
	$Bar / RepellentFilling.visible = true
	$Bar / AbilityDurationFilling.size.y = 0
	$Bar / OverchargeOverlay.hide()

func updateFilling():
	var fill = Data.of(teamId + ".repellent.currentgrowth")
	$Bar / RepellentFilling.size.y = fill * maxFilling
	if fill >= 1.0:
		$Bar / RepellentFilling.color = Style.mapColor(Color("38663c"))
	else:
		$Bar / RepellentFilling.color = Style.mapColor(Color("8861dc"))

func setStage(stage: int):
	self.stage = stage
	match int(stage):
		1:
			$Bar.texture = preload("res://content/gadgets/repellent/hud/bar1.png")
			maxFilling = 7
			pxFromRepellentStrength = 18
		2:
			$Bar.texture = preload("res://content/gadgets/repellent/hud/bar2.png")
			maxFilling = 11
			pxFromRepellentStrength = 22
		3:
			$Bar.texture = preload("res://content/gadgets/repellent/hud/bar3.png")
			maxFilling = 15
			pxFromRepellentStrength = 26
		4:
			$Bar.texture = preload("res://content/gadgets/repellent/hud/bar4.png")
			maxFilling = 19
			pxFromRepellentStrength = 30
	$Bar / RepellentFilling.position.y = 1 + maxFilling
	$Bar / AbilityDurationFilling.position.y = 1 + maxFilling
	$Bar / OverchargeOverlay.position.y = 5 + maxFilling

	var sy = (pxFromCharges + pxFromRepellentStrength) / 6.0
	var rest = sy - floor(sy)
	if sy - floor(sy) < 0.2:
		sy = floor(sy)
		rest = 0
	else:
		sy = ceil(sy)
	element_size.y = sy
	element_size.x = 2

	$Bar.position.y = pxFromCharges + rest * 1.5

	emit_signal("request_rebuild")

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".repellent.remainingbattleuses":
		updateCharges(newValue)
	if property == teamId + ".repellent.battleuses":
		updateSlots(newValue)
	if property == teamId + ".repellent.currentgrowth":
		currentgrowth = newValue
		updateFilling()
	if property == teamId + ".repellent.stage":
		setStage(newValue)
	if property == teamId + ".repellent.overcharged":
		if newValue:
			$Bar / OverchargeOverlay.play("overcharged")
			$Bar / OverchargeOverlay.show()
		else:
			$Bar / OverchargeOverlay.hide()
	if property == teamId + ".repellent.remainingabilityduration":
		if oldValue == null or newValue > oldValue:
			maxAbilityDuration = newValue
		var fill = maxFilling * clamp(newValue / maxAbilityDuration, 0.0, 1.0)
		$Bar / AbilityDurationFilling.size.y = fill

func updateSlots(amount):
	for i in range(1, 4):
		get_node("Slot" + str(i)).visible = amount >= i

	match int(amount):
		1:
			pxFromCharges = 5
		2:
			pxFromCharges = 8
		3:
			pxFromCharges = 11

	setStage(stage)

func updateCharges(charges):
	for i in range(1, 4):
		find_child("Charge" + str(i)).visible = charges >= i
