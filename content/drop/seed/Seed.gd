class_name Seed
extends Drop

signal seed_settled
signal grown
signal tile_targeted(coord: Vector2)

@export var roots_sprite: AnimatedSprite2D

var countDown: = 30.0

var settling: = false
var growing: = false
var averageAngularVelocity: = 0.0
var averageLinearVelocity: = 0.0
var targetedTile
var triedSettling: bool = false

var cave_UID: int

func _ready():
	super._ready()
	roots_sprite.visible = false
	if isCarried():
		settling = false
	else:
		settling = true

	Level.addTutorial(self, "mineraltree", teamId)


func serialize() -> Dictionary:
	var data = super.serialize()
	data["settling"] = settling
	data["growing"] = growing
	data["triedSettling"] = triedSettling
	data["countDown"] = countDown
	data["caveUID"] = cave_UID
	if targetedTile:
		data["targetedTile"] = var_to_str(targetedTile.coord)
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)

	var caves: Array = Level.get_tree().get_nodes_in_group("cave")

	cave_UID = data["caveUID"]
	for cave in caves:
		if cave is SeedCave and cave.UID == cave_UID:

			cave.registerSeed(self)

	settling = data["settling"]
	triedSettling = data["triedSettling"]
	countDown = data["countDown"]
	if data["growing"]:
		roots_sprite.rotation = - rotation
		settled(global_position)
	if data.has("targetedTile"):
		targetedTile = Level.map.tiles[BackwardCompatibilityUtils.str_to_var(data["targetedTile"])]
		targetedTile.connect("destroyed", Callable(self, "onTargetTileDestroyed"))

func settled(pos: Vector2):
	global_position = pos
	roots_sprite.rotation = - rotation
	if Data.ofOr("world.inversegravity", false):
		roots_sprite.rotation += PI

	roots_sprite.visible = true
	roots_sprite.frame = 0
	roots_sprite.play("rooting")
	$TreePlantSound.startSound()


	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true
	growing = true
	position.x = round(position.x)
	position.y = round(position.y)
	z_index = 1
	set_physics_process(false)

func onCarried(p):
	triedSettling = false
	if targetedTile:
		removeSeededTile(targetedTile.coord)
		targetedTile.disconnect("destroyed", Callable(self, "onTargetTileDestroyed"))
		targetedTile = null

	if is_multiplayer_authority():
		uprooted()
	teamId = p.teamId

func onDropped(keeper_or_kunaicarrier):
	settling = true
	countDown = 30

func uprooted():
	if targetedTile:
		removeSeededTile(targetedTile.coord)
	settling = false
	growing = false
	freeze = false
	set_physics_process(true)
	roots_sprite.visible = false

func _physics_process(delta):
	super._physics_process(delta)
	if not multiplayer.is_server():
		return

	averageAngularVelocity = averageAngularVelocity * (1 - delta) + abs(angular_velocity * delta)
	averageLinearVelocity = averageLinearVelocity * (1 - delta) + linear_velocity.length() * delta
	if settling:
		if targetedTile:
			var deltaX = targetedTile.global_position.x - global_position.x
			if abs(deltaX) <= 0.1:
				if averageAngularVelocity < 0.3:
					seed_settled.emit(global_position)
			else:
				apply_central_impulse(Vector2(sign(deltaX) * (abs(deltaX) + 1), 0))
		elif averageLinearVelocity < 1.0 and not triedSettling:
			for i in get_colliding_bodies():
				if i is Tile\
				and (i.global_position.y > global_position.y or Data.ofOr("world.inversegravity", false))\
				and abs(global_position.x - i.global_position.x) <= GameWorld.TILE_SIZE * 0.5\
				and i.type != "border"\
				and i.health > 0:

					triedSettling = true
					tile_targeted.emit(i.coord)
					return

func targetTile(tile: Tile) -> void :
	targetedTile = tile
	targetedTile.connect("destroyed", Callable(self, "onTargetTileDestroyed"))

func onTargetTileDestroyed(inTeamId: String, keeperTechId: String):
	targetedTile = null
	if is_multiplayer_authority():
		uprooted()
	settling = true

func removeSeededTile(coord: Vector2):
	var seededTiles = Data.of(teamId + "seededTiles")
	seededTiles.erase(coord)
	Data.apply(teamId + "seededTiles", seededTiles)

func _process(delta):
	if GameWorld.softPaused(teamId):
		return
	if not multiplayer.is_server():
		return

	if growing:
		if GameWorld.devMode and Input.is_action_just_pressed("f4"):
			grown.emit(global_position)
			return

		if countDown > 0.0:
			countDown -= delta
			return

		grown.emit(global_position)

func grow(pos: Vector2) -> MineralTree:
	global_position = pos
	var tree: = sprout()
	tree.cave_UID = cave_UID
	growing = false
	queue_free()

	return tree

func sprout() -> MineralTree:
	var tree = preload("res://content/gadgets/mineraltree/MineralTree.tscn").instantiate()
	tree.name = str(UID)
	tree.teamId = teamId
	tree.UID = UID
	tree.global_position = global_position
	tree.growOnTile(targetedTile.coord)
	get_parent().add_child(tree)

	return tree
