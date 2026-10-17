class_name Egg
extends Drop

signal pet_added(petId: String)
signal egg_broken()

var countDown: = 50.0
var settling: = false
var hatching: = false
var hatched: = false

var forcePetId: String
var animatedDropSprite: AnimatedSprite2D

func _ready():
	super._ready()
	Style.init(self)
	Achievements.addIfOpen(self, "PET_FOUND", teamId)
	Data.listen(self, "inventory.totalrelic")

	var dome: Dome = Level.domesByTeamId[teamId]
	dome.petSynchronizer.connect_egg_signals(self)

func _notification(what: int) -> void :
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		animatedDropSprite = dropSprite as AnimatedSprite2D

func propertyChanged(property: String, oldValue, newValue):
	if newValue > 0:
		countDown = 0.0


func grow():
	if not (hatched or hatching):
		settling = true

func settled():
	animatedDropSprite.play("rooting")
	disablePhysics()
	hatching = true
	settling = false
	position.x = round(position.x)
	position.y = round(position.y)

func disablePhysics():
	z_index = 3
	$CollisionShape2D.disabled = true
	deactivate()
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true
	set_physics_process(false)

func _physics_process(delta):
	super._physics_process(delta)
	if settling:
		if linear_velocity.length() < 1.0 and abs(rotation_degrees) < 3.0:
			settled()

func hatch():
	if not multiplayer.is_server():
		return

	var petId: String
	if forcePetId and forcePetId != "":
		petId = forcePetId
	elif GameWorld.unlockablePets.size() == 0:
		if not GameWorld.unlockedPets.has("pet8"):

			petId = "pet8"
	else:
		petId = GameWorld.unlockablePets[randi() % GameWorld.unlockablePets.size()]

	egg_broken.emit()
	if petId:
		pet_added.emit(petId)

func breakEgg() -> void :
	animatedDropSprite.play("broken")
	hatching = false
	hatched = true

func _process(delta):
	if not multiplayer.is_server():
		return

	if hatching and not hatched:
		if GameWorld.devMode and Input.is_action_just_pressed("f4"):
			hatch()
			return
		if countDown > 0.0:
			countDown -= delta
			return

		for keeper in Keepers.getAllOfTeam(teamId):
			if keeper.global_position.y < 400:
				return

		hatch()

func serialize() -> Dictionary:
	var data = super.serialize()
	data["countDown"] = countDown
	data["settling"] = settling
	data["hatched"] = hatched
	data["hatching"] = hatching
	data["forcePetId"] = forcePetId
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	countDown = data["countDown"]
	settling = data["settling"]
	hatching = data.get("hatching", false)
	hatched = data["hatched"]
	forcePetId = data["forcePetId"]

	if hatched:
		animatedDropSprite.play("broken")
		disablePhysics()
	elif hatching:
		animatedDropSprite.play("rooting")
		disablePhysics()
