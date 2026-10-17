class_name BallSplitArea
extends "res://content/keeper/keeper2/BallHandlerArea.gd"

var catching: = false

func _ready() -> void :
	super._ready()
	$AnimatedSprite2D.visible = false

func start(playerId):
	self.playerId = playerId
	Data.listen(self, playerId + ".keeper2.spheresplit", true)
	$AnimatedSprite2D.visible = false

func propertyChanged(property: String, oldValue, newValue):
	if not is_physics_processing() and newValue:
		visible = true
		Level.addTutorial(self, "assessor2_split", playerId)
		$BallCatchCollision.disabled = false
		set_physics_process(newValue)

func _physics_process(delta):
	if GameWorld.paused:
		return

	if catching:
		if is_multiplayer_authority():
			for sphere: Pinball in get_overlapping_bodies():
				if not handledSpheres.has(sphere.UID) and sphere.size > 0.3:
					if sphere.generation >= 4:
						Achievements.triggerIfOpen("KEEPER2_SPLITS", playerId)

					var sphereKeeper = Keepers.getKeeper(sphere.playerId)
					sphereKeeper.synchronizer.network_rpc(sphereKeeper.synchronizer.catch_pinball.bind(sphere.UID), true)

					var newSize = sphere.size * Data.of(playerId + ".keeper2.splitlifetime")

					var areaKeeper = get_parent()
					var areaKeeperCoord = Level.map.getTileCoord(areaKeeper.global_position)
					var newPos = Level.map.getTilePos(areaKeeperCoord)

					var newSphere1: int = randi()
					var newSphere2: int = randi()

					sphereKeeper.synchronizer.network_rpc(sphereKeeper.networkShootPinball.bind(
						newPos + Vector2.ONE * GameWorld.TILE_SIZE * randf_range(-0.2, 0.2), 
						newSize, 
						0.0, 
						sphere.playerId, 
						100 * sphere.linear_velocity.rotated(CONST.PI_HALF).normalized(), 
						sphere.generation + 1, 
						newSphere1, 
						false, 
					), true)

					sphereKeeper.synchronizer.network_rpc(sphereKeeper.networkShootPinball.bind(
						newPos + Vector2.ONE * GameWorld.TILE_SIZE * randf_range(-0.2, 0.2), 
						newSize, 
						0.0, 
						sphere.playerId, 
						100 * sphere.linear_velocity.rotated( - CONST.PI_HALF).normalized(), 
						sphere.generation + 1, 
						newSphere2, 
						false, 
					), true)

					handledSpheres.append(sphere.UID)
					handledSpheres.append(newSphere1)
					handledSpheres.append(newSphere2)

					areaKeeper.ballActionCooldown = Data.of(playerId + ".keeper2.actioncooldown")
					InputSystem.shakeTarget(self, 100, 0.2)
		elif get_parent().ballActionCooldown <= 0.0:
			for sphere: Pinball in get_overlapping_bodies():
				if not handledSpheres.has(sphere.UID) and sphere.size > 0.3:
					get_parent().ballActionCooldown = Data.of(playerId + ".keeper2.actioncooldown")

	if catching:
		$AnimatedSprite2D.play("reflect")
	elif get_parent().ballActionCooldown > 0.0:
		$AnimatedSprite2D.play("active")
	elif $AnimatedSprite2D.visible:
		$AnimatedSprite2D.visible = false
		$SplitReady.startSound()

	$AnimatedSprite2D.rotation = randf() * TAU

func catch():
	catching = true
	$AnimatedSprite2D.visible = true
	$SplitActivated.startSound()

func stopCatching():
	catching = false
	handledSpheres.clear()
