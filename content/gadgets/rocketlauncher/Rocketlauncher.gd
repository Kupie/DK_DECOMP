extends Node2D

@export var synchronizer: Synchronizer

var teamId: String

var targetedMonsters: = []
var rocketSprites: = []
var restockCooldownPerSlot: = {}
var rocketSlotsArmed: = []
var active = false
@onready var rocket_parent_front = $Sprite0 / rocket_parent_front


var rockets: = {}

func _ready() -> void :
	for i in range(1, 11):
		var sprite = find_child("Rocket" + str(i))
		rocketSprites.append(sprite)
		sprite.scale.y = 0.0

	Data.listen(self, teamId + ".monsters.wavepresent")
	Data.listen(self, teamId + ".rocketlauncher.rockets", true)
	Data.listen(self, teamId + ".rocketlauncher.rocketstage", true)
	Data.listen(self, teamId + ".rocketlauncher.rechargetime", true)

	add_to_group(teamId + "-dome_ability2")

	Style.init(self)

func adjust_rocket_rendering(value):
	if value < 6:
		return

	var rpf = rocket_parent_front
	rpf.get_parent().remove_child(rpf)
	$Sprite1.add_child(rpf)

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".rocketlauncher.rocketstage":
		for sprite in rocketSprites:
			sprite.frame = newValue - 1
			sprite.show_behind_parent = newValue <= 2
	elif property == teamId + ".rocketlauncher.rockets":
		adjust_rocket_rendering(newValue)


		if Data.of(teamId + ".monsters.wavepresent") and oldValue and newValue > oldValue:
			add_rockets(newValue - oldValue)

		match newValue:
			1:
				$Sprite0.frame_coords.y = 0
				$Sprite1.frame_coords.y = 0
				$Sprite2.frame_coords.y = 0
			3:
				$Sprite0.frame_coords.y = 1
				$Sprite1.frame_coords.y = 1
				$Sprite2.frame_coords.y = 1
			6:
				$Sprite0.frame_coords.y = 2
				$Sprite1.frame_coords.y = 2
				$Sprite2.frame_coords.y = 2
			10:
				$Sprite0.frame_coords.y = 3
				$Sprite1.frame_coords.y = 3
				$Sprite2.frame_coords.y = 3
	elif property == teamId + ".monsters.wavepresent":
		if newValue:
			start()
		else:
			stop()
	elif property == teamId + ".rocketlauncher.rechargetime":
		for positionIndex in rocketSlotsArmed.size():
			if not rocketSlotsArmed[positionIndex]:
				restockCooldownPerSlot[positionIndex] = Data.of(teamId + ".rocketlauncher.rechargetime")

func _process(delta: float) -> void :
	if GameWorld.paused or not active:
		return

	for slot in restockCooldownPerSlot:
		var cooldown = restockCooldownPerSlot[slot]
		if cooldown > 0.0:
			cooldown -= delta
			if cooldown <= 0.0:
				refillRocket(slot)
			restockCooldownPerSlot[slot] = cooldown

func start():
	active = true
	var count = Data.of(teamId + ".rocketlauncher.rockets")
	rocketSlotsArmed.clear()
	for x in count:
		rocketSlotsArmed.append(true)

	var t = create_tween()
	for i in count:
		var sprite = rocketSprites[i]
		sprite.visible = true
		t.tween_property(sprite, "scale:y", 1.0, randf_range(0.06, 0.15))
		t.tween_interval(randf_range(0.01, 0.2))

func refillRocket(i: int):
	var sprite = rocketSprites[i]
	sprite.visible = true
	var t = create_tween()
	t.tween_property(sprite, "scale:y", 1.0, randf_range(0.06, 0.15))
	t.tween_callback( func(): rocketSlotsArmed[i] = true)

func add_rockets(count):
	var current = rocketSlotsArmed.size()

	var t = create_tween()
	for i in count:
		var sprite = rocketSprites[current + i]
		sprite.visible = true
		t.tween_property(sprite, "scale:y", 1.0, randf_range(0.06, 0.15))
		t.tween_interval(randf_range(0.01, 0.2))
		t.tween_callback( func(): rocketSlotsArmed.append(true))

func stop():
	active = false
	restockCooldownPerSlot.clear()
	var t = create_tween()
	for i in 10:
		var sprite = rocketSprites[i]
		t.tween_property(sprite, "scale:y", 0.0, randf_range(0.06, 0.15))
		t.tween_interval(randf_range(0.01, 0.2))

func executeBattle2():
	if not multiplayer.is_server():
		return

	if not can_shoot():
		$CannotFireSound.startSound()
	else:
		var rocketUID: = randi()
		synchronizer.network_rpc(shoot_rocket.bind(rocketUID, findRocketTarget()), true)

@rpc("reliable")
func shoot_rocket(rocketUID: int, targetUID: int) -> void :
	var positionIndex = rocketSlotsArmed.find(true)
	var sprite = rocketSprites[positionIndex]
	sprite.scale.y = 0.0
	$FireSound.startSound()

	var fx = preload("res://content/gadgets/rocketlauncher/rocket_fire_effects.tscn").instantiate()
	fx.global_position = sprite.global_position
	Level.map.add_child(fx)

	var rocket: = preload("res://content/gadgets/rocketlauncher/Rocket.tscn").instantiate()
	rockets[rocketUID] = rocket
	rocket.UID = rocketUID
	rocket.teamId = teamId
	rocket.position = sprite.global_position
	rocket.request_new_target.connect(rocketRequestedNewTarget.bind(rocket))
	rocket.target_hit.connect(rocketHitTarget)
	rocket.rocket_destroyed.connect(on_rocket_destroyed)
	setRocketTarget(rocketUID, targetUID)
	Level.map.add_child(rocket)
	rocketSlotsArmed[positionIndex] = false

	restockCooldownPerSlot[positionIndex] = Data.of(teamId + ".rocketlauncher.rechargetime")

@rpc("reliable")
func remoteExecuteBattle2() -> void :

	pass

func rocketHitTarget(target):
	targetedMonsters.erase(target)

func can_shoot() -> bool:
	return rocketSlotsArmed.any( func(x): return x) and \
	not get_tree().get_nodes_in_group(teamId + "-monster").is_empty()

func findRocketTarget() -> int:
	var monsters = get_tree().get_nodes_in_group(teamId + "-monster")
	if monsters.is_empty():
		return -1

	monsters.sort_custom(sort_by_max_health)

	for i in 2:
		for monster in monsters:
			if (targetedMonsters.has(monster) and i == 0):
				continue

			if not monster.canBeHit() or monster.invulnerable or not monster.alive():
				continue

			targetedMonsters.append(monster)
			return monster.UID

	return -1

func sort_by_max_health(a, b):
	return a.maxHealth > b.maxHealth

func getBattleAbilityName() -> String:
	return tr("upgrades.missile.abilityname")

func rocketRequestedNewTarget(rocket) -> void :
	var newTarget = findRocketTarget()
	synchronizer.network_rpc(setRocketTarget.bind(rocket.UID, newTarget), true)

@rpc("reliable")
func setRocketTarget(rocketUID: int, targetUID: int) -> void :
	var monsters: = Level.monstersByTeamId[teamId] as Monsters
	if not rockets.has(rocketUID) or not monsters.hasMonster(targetUID):
		return

	rockets[rocketUID].target = monsters.getMonster(targetUID)

func on_rocket_destroyed(rocket: Rocket) -> void :
	rockets.erase(rocket.UID)
	rocket.queue_free()
