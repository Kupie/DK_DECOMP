class_name ResourcePackerEffect
extends Area2D

var UID: int
var teamId: String

var lifetime: float = 1.7

signal packedDropCreated(UID: int, dropsAndPositions)

@export
var wiggle_over_lifetime: Curve
var overwritten_body_physics: = []
var triggered: bool
var carrier: Keeper
var bundle
var bundleInfluence
const maxCarryDistance: = 100.0

var nextDropsAndPositions: Dictionary

func _ready():
	$AbsorbParticles.emitting = true
	$PackingLoop.startSound()
	if StageManager.isInLevel():
		Level.drops.synchronizer.drop_spawned.connect(on_drop_spawned, CONNECT_DEFERRED)
	else:


		process_mode = Node.PROCESS_MODE_DISABLED
		await get_tree().create_timer(1.0).timeout
		queue_free()

func on_drop_spawned(drop: Carryable) -> void :
	if not drop is PackedDrop:
		return

	var packedDrop: = drop as PackedDrop

	packedDrop.addDrops(nextDropsAndPositions)
	if is_instance_valid(bundle) and is_instance_valid(bundleInfluence):
		bundle.addCarryable(packedDrop, bundleInfluence.strength)
	packedDrop.pack()
	nextDropsAndPositions.clear()

func cleanupPackedOriginals(uids: Array) -> void :
	for uid in uids:
		if Level.drops.has_drop(uid):
			Level.drops.get_drop(uid).remove()

func _physics_process(delta):
	if GameWorld.paused or triggered or not multiplayer.is_server():
		return

	lifetime -= delta
	var innerDrops: = _getRelevantBodies($InnerArea)
	if lifetime <= 0:
		if innerDrops.size() > 1:
			var dropsAndPositions: = {}
			for drop in innerDrops:
				dropsAndPositions[drop.UID] = drop.global_position
			packedDropCreated.emit(UID, dropsAndPositions)
		create_tween().tween_callback(queue_free).set_delay(2)
		return
	elif lifetime < 1.5:
		for x in innerDrops:

			if randf() < wiggle_over_lifetime.sample_baked(remap01clamped(lifetime, 0.0, 1.0)):
				x.position += Vector2(randi_range(-1, 1), randi_range(-1, 1))

	var multi = remap01clamped(lifetime, 1.2, 0.3);
	for drop in _getRelevantBodies(self):
		var diff = global_position - drop.global_position
		drop.apply_central_impulse(diff * multi)

func remap01clamped(val, istart, istop):
	return clamp(remap(val, istart, istop, 0.0, 1.0), 0.0, 1.0)

func sort_by_distance_asc(a, b):
	return (a.position - position).length() < (b.position - position).length()

func _getRelevantBodies(area: Area2D) -> Array:
	var maxCount = Data.of(teamId + ".resourcepacker.packcount")
	var drops: = []
	for drop in area.get_overlapping_bodies():
		if drop is Drop and (drop.type == "iron" or drop.type == "water" or drop.type == "sand"):
			drops.append(drop)
			var inf = drop.getCarryInfluence()
			if inf and inf.bundle:
				bundle = inf.bundle
				bundleInfluence = inf

	drops.sort_custom(sort_by_distance_asc)

	while (drops.size() > maxCount):
		drops.pop_back()

	return drops

func set_carrier(keeper: Keeper):
	carrier = keeper

func _on_inner_area_body_entered(body):
	body.linear_damp = 10
	$ResourceEnterSound.startSound()

func _on_inner_area_body_exited(body):
	body._updatePhysicsOverrides()

func create_packed_drop(dropsAndPositions: Dictionary) -> void :
	nextDropsAndPositions = dropsAndPositions
	triggered = true

	$SuccessParticles.restart()
	$PackingLoop.stop()
	$PackedSound.startSound()

	if not multiplayer.is_server():
		get_tree().create_timer(0.2).timeout.connect(cleanupPackedOriginals.bind(dropsAndPositions.keys()))
		return
	var isCarrying = false
	for uid in dropsAndPositions.keys():
		if not Level.drops.has_drop(uid):
			continue
		var drop: = Level.drops.get_drop(uid)
		if drop.canFocusCarry() and drop.isCarried() and drop.carriedBy.all( func(carrier): return carrier is not KunaiCarrier):
			isCarrying = true
	var spawnData: = {
		"type": CONST.PACK, 
		"position": position, 
		"team": teamId, 
	}

	if isCarrying and (global_position - carrier.global_position).length() <= maxCarryDistance:
		spawnData["carriers"] = [carrier.playerId]

	Level.drops.network_spawn(spawnData)
