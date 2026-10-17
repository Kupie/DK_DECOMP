extends "res://content/caves/Cave.gd"

signal hit

@export var synchronizer: ScannerCaveSynchronizer
@export var leftRes: ResourceGrabber
@export var rightRes: ResourceGrabber

var hasScanner: = true
var activated: = false
var grabs: = 0

func _ready():
	super._ready()
	Style.init($Background / Left / Resource)
	Style.init($Background / Right / Resource)
	$Background / Left / Resource.visible = false
	$Background / Right / Resource.visible = false

	$Background.frame = 0

	Data.listen(self, "map.revealdistance")

func propertyChanged(property: String, oldValue, newValue):
	if property != "map.revealdistance":
		return

	Level.map.tileCoordsToReveal.append(Vector2(0, -1))
	Level.map.floodRevealTiles(true)
	Level.map.removeAllEmptyBorderTilesVisually()

func serialize() -> Dictionary:
	var data = super.serialize()
	data["hasScanner"] = hasScanner
	data["activated"] = activated
	data["grabs"] = grabs
	if is_instance_valid(leftRes):
		data["resourceleftused"] = leftRes.spent
	else:
		data["resourceleftused"] = true
	if is_instance_valid(rightRes):
		data["resourcerightused"] = rightRes.spent
	else:
		data["resourcerightused"] = true
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	hasScanner = data["hasScanner"]
	activated = data["activated"]
	grabs = data["grabs"]
	if hasScanner:
		var usedLeft = data.get("resourceleftused", false)
		var usedRight = data.get("resourcerightused", false)
		leftRes.spent = usedLeft
		rightRes.spent = usedRight
		$Background / Left / Resource.visible = usedLeft
		$Background / Right / Resource.visible = usedRight
		if usedLeft:
			$Background / Left.play("idle")
		if usedRight:
			$Background / Right.play("idle")

		if grabs == 2 or (usedLeft and usedRight):
			$Background / Scanner / Spitze.play("spitze_idle")
			activated = true
		elif grabs == 1:
			$Background / Scanner.play("base_idle")
		if grabs >= 1:
			%ActiveAmbSound.startSound()
	else:
		$Background.frame = 1
		$Background / Left.queue_free()
		$Background / Right.queue_free()
		$Background / Scanner.queue_free()

func canFocusUse(keeper: Keeper) -> bool:
	return hasScanner and activated

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if not hasScanner:
		return false

	hit.emit(keeper)
	return true

func registerHit(playerId: String) -> bool:
	if not hasScanner:
		return false

	$ScannerTakenSound.startSound()
	hasScanner = false
	%ActiveAmbSound.stop()
	$Background.frame = 1
	$Background / Left.queue_free()
	$Background / Right.queue_free()
	$Background / Scanner.queue_free()

	if multiplayer.is_server():
		Data.apply("map.revealdistance", 2)

	return true

func _on_left_animation_looped() -> void :
	_leftAnimationFinishedCheck()

func _on_Left_animation_finished() -> void :
	_leftAnimationFinishedCheck()

func _leftAnimationFinishedCheck() -> void :
	if $Background / Left.animation == "start":
		$Background / Left.play("idle")

func _on_right_animation_looped() -> void :
	_rightAnimationFinishedCheck()

func _on_Right_animation_finished():
	_rightAnimationFinishedCheck()

func _rightAnimationFinishedCheck() -> void :
	if $Background / Right.animation == "start":
		$Background / Right.play("idle")

func _on_scanner_animation_looped() -> void :
	_scannerAnimationFinishedCheck()

func _on_Scanner_animation_finished():
	_scannerAnimationFinishedCheck()

func _scannerAnimationFinishedCheck() -> void :
	if $Background / Scanner.animation == "base_start":
		$Background / Scanner.play("base_idle")

func _on_spitze_animation_looped() -> void :
	_spitzeAnimationFinishedCheck()

func _on_Spitze_animation_finished():
	_spitzeAnimationFinishedCheck()

func _spitzeAnimationFinishedCheck() -> void :
	if $Background / Scanner / Spitze.animation == "spitze_start":
		$Background / Scanner / Spitze.play("spitze_idle")
		activated = true

func _on_ResourceGrabberLeft_grabbed_resource():
	synchronizer.network_rpc(playGrabResourceAnimations.bind(false), true)

func _on_ResourceGrabberRight_grabbed_resource():
	synchronizer.network_rpc(playGrabResourceAnimations.bind(true), true)

@rpc("reliable")
func playGrabResourceAnimations(isRightSide: bool) -> void :
	if isRightSide:
		$Background / Right.play("start")
		$Background / Right / Resource.visible = true
	else:
		$Background / Left.play("start")
		$Background / Left / Resource.visible = true
	onResourceGrabbed()

func onResourceGrabbed():
	grabs += 1
	if grabs == 1:
		%ActiveAmbSound.startSound()
		$Background / Scanner.play("base_start")
	elif grabs >= 2:
		$Background / Scanner / Spitze.play("spitze_start")
