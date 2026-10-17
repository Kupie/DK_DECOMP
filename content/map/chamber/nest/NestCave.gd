extends "res://content/caves/Cave.gd"

@export var synchronizer: NestCaveSynchronizer

signal hit(keeper: Keeper)

var hasEgg: = true

func _ready():
	super._ready()
	$Sprite2D.play("egged")

func serialize() -> Dictionary:
	var data = super.serialize()
	data["hasEgg"] = hasEgg
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	hasEgg = data["hasEgg"]
	if not hasEgg:
		$GizmoSpawn.queue_free()
		$Usable.queue_free()
		$Sprite2D.play("empty")

func updateUsedTileCoords():
	tileCoords.clear()
	tileCoords.append(Vector2(0, 0))
	tileCoords.append(Vector2(1, 0))
	tileCoords.append(Vector2(0, 1))
	tileCoords.append(Vector2(1, 1))

func canFocusUse(keeper: Keeper) -> bool:
	return hasEgg

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if not hasEgg:
		return false

	hit.emit(keeper)
	return true

func registerHit(playerId: String) -> void :
	if not hasEgg:
		return

	var keeper: = Keepers.getKeeper(playerId)

	hasEgg = false
	$Sprite2D.play("empty")
	$Usable.queue_free()
	$GizmoSpawn / AmbBird.stop()
	$GizmoSpawn / AmbCricket.stop()

	var eggSpawnDelayer: Timer = $EggSpawnDelayer as Timer
	eggSpawnDelayer.timeout.connect(_on_egg_spawn_delayer_timeout.bind(keeper), CONNECT_ONE_SHOT)
	eggSpawnDelayer.start(0.5)

func _on_egg_spawn_delayer_timeout(keeper) -> void :
	if multiplayer.is_server():
		Level.drops.network_spawn({
			"type": CONST.EGG, 
			"position": find_child("GizmoSpawn").global_position, 
			"carriers": [keeper.playerId], 
			"team": keeper.teamId, 
		})

	$GizmoSpawn.queue_free()

func onRevealed():
	$GizmoSpawn / AmbBird.startSound()
	$GizmoSpawn / AmbCricket.startSound()
