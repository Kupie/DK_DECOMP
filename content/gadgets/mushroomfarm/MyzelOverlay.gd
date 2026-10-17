extends Sprite2D

signal state_changed

@export var synchronizer: Synchronizer

var teamId: String

var coord: Vector2
var cooldown: float
var hasMushroom: = false
var mushroomSprite
var direction: Vector2
var s: int
var random: RandomNumberGenerator

var sprites = [
	preload("res://content/gadgets/mushroomfarm/tilemyzel.png"), 
	preload("res://content/gadgets/mushroomfarm/tilemyzel2.png"), 
	preload("res://content/gadgets/mushroomfarm/tilemyzel3.png"), 
	preload("res://content/gadgets/mushroomfarm/tilemyzel4.png"), 
	]

func serialize() -> Dictionary:
	var data = {
		"teamId": teamId, 
		"hasMushroom": hasMushroom, 
		"coord": var_to_str(coord), 
		"cooldown": cooldown, 
	}
	return data

func deserialize(data: Dictionary):
	coord = str_to_var(data.get("coord"))
	cooldown = float(data.get("cooldown"))
	hasMushroom = data.get("hasMushroom")
	teamId = data.get("teamId")
	$AutoPickArea / CollisionShape2D.disabled = not hasMushroom
	if hasMushroom:
		spawnMushroom()

func to_bytes() -> PackedByteArray:
	var data = {
		"hasMushroom": hasMushroom, 
		"coord": var_to_str(coord), 
		"cooldown": cooldown, 
		"direction": direction
	}

	return var_to_bytes(data)

func from_bytes(data: PackedByteArray) -> void :
	var dataDictionary: Dictionary = bytes_to_var(data)
	coord = str_to_var(dataDictionary.get("coord"))
	cooldown = float(dataDictionary.get("cooldown"))
	hasMushroom = dataDictionary.get("hasMushroom")
	$AutoPickArea / CollisionShape2D.disabled = not hasMushroom
	if hasMushroom:
		spawnMushroomVisuals(dataDictionary.get("direction"))

func _ready() -> void :
	random = RandomNumberGenerator.new()
	random.seed = s

	flip_h = random.randf() > 0.5
	flip_v = random.randf() > 0.5
	Style.init(self)

	cooldown = random.randf_range(1, 2)
	if multiplayer.is_server():
		Data.listen(self, teamId + ".monsters.wavepresent")
	Data.listen(self, teamId + ".mushroom.autopickup", true)

	$poof.visible = false
	$mushroom_l.visible = false
	$mushroom_d.visible = false
	$mushroom_r.visible = false
	$mushroom_t.visible = false

	var randomSpriteIndex = random.randi_range(0, sprites.size() - 1)

	self.texture = sprites[randomSpriteIndex]
	self.flip_h = random.randi_range(0, 1) == 0

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".mushroom.autopickup":
		$AutoPickArea.monitoring = newValue
	elif property == teamId + ".monsters.wavepresent":
		if not newValue:
			var tile = get_parent()
			if tile.health < tile.max_health:
				Level.map.networkSetTileHealth(tile.coord, min(tile.max_health, tile.health + 0.5 * tile.max_health))
				Level.map.networkSetTileDamage(0, Vector2.ZERO, tile.position)

@rpc("reliable")
func setMushroomAutoPickup(newValue) -> void :
	$AutoPickArea.monitoring = newValue

func _process(delta: float) -> void :
	if GameWorld.paused:
		return

	if not multiplayer.is_server():
		return

	if not hasMushroom:
		cooldown -= delta * float(Keepers.getAllOfTeam(teamId).size())
		if cooldown <= 0:
			spawnMushroom()

func spawnMushroom():
	if not multiplayer.is_server():
		return

	var dirs = CONST.DIRECTIONS
	dirs.shuffle()
	for d in dirs:
		var neighborCoord = d + coord
		if Level.map.visibleTileCoords.has(neighborCoord) and not Level.map.tiles.has(neighborCoord):
			synchronizer.network_rpc(spawnMushroomVisuals.bind(d), true)
			return

	cooldown = 10.0

@rpc("reliable")
func spawnMushroomVisuals(d: Vector2) -> void :
	direction = d
	hasMushroom = true
	$AutoPickArea / CollisionShape2D.disabled = false

	if d.x < 0:
		mushroomSprite = $mushroom_l
	elif d.x > 0:
		mushroomSprite = $mushroom_r
	elif d.y < 0:
		mushroomSprite = $mushroom_t
	elif d.y > 0:
		mushroomSprite = $mushroom_d

	mushroomSprite.visible = true
	$Usable.position = mushroomSprite.position
	$poof.position = mushroomSprite.position + d * 6
	mushroomSprite.scale *= 0
	Style.init(mushroomSprite)
	$SpawnSound.startSound()

	var t = create_tween()
	t.tween_property(mushroomSprite, "scale", Vector2.ONE * 1.5, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(mushroomSprite, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var delay = random.randf_range(5, 15)
	t.tween_callback(periodic_poof).set_delay(delay)

func periodic_poof():
	if not hasMushroom:
		return

	var tw = create_tween()

	tw.tween_property(mushroomSprite, "scale", Vector2.ONE * 1.25, 1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback( func():
		$poof.visible = true
		$poof.play()
		$PoofSound.startSound()

		).set_delay(0.5)
	tw.tween_property(mushroomSprite, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var delay = random.randf_range(5, 15)
	tw.tween_callback(periodic_poof).set_delay(delay)

func canFocusUse(keeper: Keeper) -> bool:
	return hasMushroom

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func incr_buff(keeper: Keeper, bufname, bufamount: float, bufdur: float):
	var allowStack: = bool(Data.of(teamId + ".mushroom.stack"))

	var buf: TemporaryBuff = keeper.getTemporaryBuff(bufname, "myzel")
	if buf:
		if allowStack:
			buf.remainingDuration += bufdur
		else:
			buf.remainingDuration = bufdur
		if buf.amount != bufamount:
			var diff = bufamount - buf.amount
			Data.changeByInt(keeper.playerId + "." + buf.property, diff)
			buf.amount = bufamount
	else:
		keeper.addTemporaryBuff(bufname, bufamount, bufdur, "myzel")

func useHit(keeper: Keeper) -> bool:
	if hasMushroom:
		synchronizer.network_rpc(registerHit.bind(keeper.playerId), true)
		return true
	return false

@rpc("reliable", "any_peer")
func registerHit(playerId: String) -> void :
	var keeper: = Keepers.getKeeper(playerId)

	$poof.play()
	$PickupSound.startSound()
	$AutoPickArea / CollisionShape2D.disabled = true
	mushroomSprite.visible = false

	hasMushroom = false

	if not multiplayer.is_server():
		return

	incr_buff(keeper, "keeper.speedbuff", float(Data.of(teamId + ".mushroomfarm.speedbuff")), float(Data.of(teamId + ".mushroomfarm.speedbuffduration")))
	incr_buff(keeper, "keeper.drillbuff", float(Data.of(teamId + ".mushroomfarm.drillbuff")), float(Data.of(teamId + ".mushroomfarm.drillbuffduration")))

	cooldown = Data.stabilizedRandomFloat(30, 50, teamId + ".mushroomfarm.myzelgrowth", 40)

func removeFromTile():
	pass

func _on_auto_pick_area_body_entered(body: Node2D) -> void :
	if hasMushroom:
		useHit(body)
