extends StaticBody2D

class_name Tile

signal tile_hit(dir: Vector2, dmg: float, teamId: String, keeperTechId: String)
signal destroyed(teamId: String, keeperTechId: String)

@export var type: = ""
var max_health: int
var layer: int
var hardness: int
var health: float
var hardnessMultiplier: float
var maxDamagePerHit: float = -1
var richness: float
var coord: Vector2
var biome: String
var last_damage_from: Vector2
var tileOverlayType: String = ""
var tileOverlay
var exploded: = false
var hitTween: Tween

@onready var res_sprite = $ResourceSprite

func _ready():
	setType(type)

	if res_sprite:
		Style.init(res_sprite)











func setType(type: String):
	self.type = type
	var baseHealth: float = Data.of("map.tileBaseHealth")

	var rng: = RandomNumberGenerator.new()
	rng.seed = Level.levelSeed + hash(coord)

	match type:
		"border":
			if res_sprite:
				res_sprite.hide()
				res_sprite.queue_free()
				res_sprite = null
			set_meta("destructable", false)
		"dirt":
			res_sprite.hide()
			set_meta("destructable", true)
			initResourceSprite(Vector2(5, 0))
		CONST.IRON:
			set_meta("destructable", true)
			initResourceSprite(Vector2(rng.randi_range(2, 6), 11))
			baseHealth += Data.of("map.ironAdditionalHealth")
		CONST.SAND:
			set_meta("destructable", true)
			initResourceSprite(Vector2(2, 3))
			baseHealth += Data.of("map.sandAdditionalHealth")
		CONST.WATER:
			set_meta("destructable", true)
			initResourceSprite(Vector2(rng.randi_range(2, 3), 7))
			baseHealth += Data.of("map.waterAdditionalHealth")
		CONST.GADGET:
			set_meta("destructable", true)
			initResourceSprite(Vector2(4, 1))
			baseHealth += Data.of("map.gadgetAdditionalHealth")
		CONST.POWERCORE:
			set_meta("destructable", true)
			initResourceSprite(Vector2(4, 1))
			baseHealth += Data.of("map.gadgetAdditionalHealth")
		CONST.RELIC:
			set_meta("destructable", true)
			initResourceSprite(Vector2(4, 2))
			baseHealth += Data.of("map.relicAdditionalHealth")
		CONST.RELICSWITCH:
			set_meta("destructable", true)
			initResourceSprite(Vector2(4, 2))
			baseHealth += Data.of("map.relicAdditionalHealth")
		CONST.NEST:
			set_meta("destructable", true)
			initResourceSprite(Vector2(5, 0))

	var healthMultiplier: float = 1.0
	match int(hardness):
		0:
			hardnessMultiplier = Data.of("map.hardnessMultiplier0")
		1:
			hardnessMultiplier = Data.of("map.hardnessMultiplier1")
		2:
			hardnessMultiplier = Data.of("map.hardnessMultiplier2")
		3:
			hardnessMultiplier = Data.of("map.hardnessMultiplier3")
		4:
			hardnessMultiplier = Data.of("map.hardnessMultiplier4")
		5:
			hardnessMultiplier = Data.of("map.hardnessMultiplier5")
		_:
			hardnessMultiplier = 1

	healthMultiplier *= hardnessMultiplier
	healthMultiplier *= (pow(Data.of("map.tileHealthMultiplierPerLayer"), layer))

	max_health = max(1, round(healthMultiplier * baseHealth))
	if health == 0:
		health = max_health
	else:

		health = min(health, max_health)

func initResourceSprite(v: Vector2):
	res_sprite.set_frame_coords(v)

func remote_hit(dir: Vector2, dmg: float, teamId: String, keeperTechId: String = ""):
	if health <= 0:


		return
	_add_damage(dir, dmg, teamId, false, keeperTechId)

func hit(dir: Vector2, dmg: float, teamId: String = "", keeperTechId: String = ""):
	if health <= 0:

		return

	tile_hit.emit(dir, dmg, teamId, keeperTechId)
	_add_damage(dir, dmg, teamId, true, keeperTechId)

func _add_damage(dir: Vector2, dmg: float, teamId: String, localHit: = true, keeperTechId: String = ""):

	var previous_health = health
	if maxDamagePerHit >= 0:
		dmg = min(maxDamagePerHit, dmg)
	health -= dmg

	apply_damage_to_shader(health, previous_health, dir)


	var factor = 0.2 + dmg / 5.0
	var mod = max(1.0, 1.5 * factor)
	if res_sprite:
		if hitTween:
			hitTween.kill()
		hitTween = create_tween()
		hitTween.tween_property(res_sprite, "modulate", Color.WHITE, 0.2).from(Color(mod, mod, mod, 1.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if health <= 0:
		last_damage_from = dir
		if res_sprite:
			res_sprite.modulate = Color(3, 3, 3, 1)
		if hitTween:
			hitTween.kill()
		hitTween = create_tween()
		if localHit:
			hitTween.tween_callback(emit_destroyed.bind(teamId, keeperTechId)).set_delay(0.02)
		else:

			emit_destroyed(teamId, keeperTechId)
		GameWorld.incrementRunStat("tiles_destroyed", teamId)

func emit_destroyed(inTeamId: String, keeperTechId: String = "") -> void :
	destroyed.emit(inTeamId, keeperTechId)

func setTileOverlay(overlayType: String, teamId: String = "", overlaySeed: int = -1):
	if hasTileOverlay() or overlayType == "":
		return
	tileOverlayType = overlayType

	match overlayType:
		Data.TILE_OVERLAY_ROOTS:
			var m = preload("res://content/gadgets/mineraltree/rootoverlay/RootOverlay.tscn").instantiate()
			add_child(m)
			tileOverlay = m
			maxDamagePerHit = max_health * 0.1
			health = max_health
			hardness = 4
			Level.map.setTileDamage(0, Vector2.ZERO, position)
		Data.TILE_OVERLAY_MYZEL:
			var m = preload("res://content/gadgets/mushroomfarm/MyzelOverlay.tscn").instantiate()
			m.s = overlaySeed
			m.teamId = teamId
			m.coord = coord
			add_child(m)
			tileOverlay = m
			maxDamagePerHit = max_health * 0.15
		Data.TILE_OVERLAY_WORMS:
			var m = preload("res://content/gadgets/extractor/WormOverlay.tscn").instantiate()
			m.s = overlaySeed
			m.teamId = teamId
			add_child(m)
			tileOverlay = m

func removeTileOverlay():
	if tileOverlay:
		tileOverlay.removeFromTile()
		tileOverlay = null
	tileOverlayType = ""

func getTileOverlay():
	return tileOverlay

func hasTileOverlay() -> bool:
	return tileOverlayType != ""

func isTileOverlayType(type: String) -> bool:
	return tileOverlayType == type

func relativeHealth() -> float:
	return clamp(float(health / max_health), 0.0, 1.0)

func apply_damage_to_shader(health, previous_health, direction):
	var proportional_damage = clamp(1 - health / max_health, 0, 1)
	var hit_power = (previous_health - health) / max_health
	Level.map.addTileDamage(hit_power, proportional_damage, direction, position)

func set_collider_disabled(c: bool):
	$CollisionShape2D.disabled = c

func queue_free():
	assert (false, """Use queueDelete() to destroy a tile. Overwriting build in methods results in an undocumented behaviour
			(works only depending on the context and result might vary between engine version)""")
	queueDelete()

func queueDelete() -> void :
	if is_queued_for_deletion():
		return
	var wakeup_call: = preload("res://content/map/tile/RigidBodyWakeupCall.tscn").instantiate()
	wakeup_call.position = position
	get_parent().add_child(wakeup_call)
	Tile.spawn_tile_break_particles(get_parent(), coord, position, last_damage_from, type, exploded, true)
	super.queue_free()

static func position_in_view(location: Vector2, root: Node2D) -> bool:
	var viewport: Viewport = root.get_viewport()
	if not viewport:
		return false
	var viewport_scale: = viewport.canvas_transform.get_scale()
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	var location_in_viewport: Vector2 = root.get_global_transform_with_canvas().origin + (location * viewport_scale)


	var node_rect: Rect2 = Rect2(location_in_viewport - (Vector2(24, 24) * viewport_scale), Vector2(48, 240.0) * viewport_scale)
	return viewport_rect.intersects(node_rect)

static func spawn_tile_break_particles(root, coord, location, direction, type, explosion, spawn_dirt):
	if not position_in_view(location, root):
		return

	var particles = Data.TILE_BREAK_PARTICLES.instantiate()
	particles.biome_color = Level.map.getBiomeColorByCoord(coord)
	if explosion:
		particles.dust_color = Style.mapColor("#505a8c")
	else:
		particles.dust_color = particles.biome_color * 1.3
	particles.impactDirection = direction
	particles.type = type
	particles.position = location
	particles.spawn_dirt = spawn_dirt
	root.add_child(particles)

func serialize() -> Dictionary:
	var data = {
		"type": type, 
		"max_health": max_health, 
		"hardnessMultiplier": hardnessMultiplier, 
		"layer": layer, 
		"hardness": hardness, 
		"health": health, 
		"richness": richness, 
		"coord": var_to_str(coord), 
		"biome": biome, 
		"last_damage_from": var_to_str(last_damage_from), 
		"tileOverlayTeamId": tileOverlay.teamId if is_instance_valid(tileOverlay) and "teamId" in tileOverlay else "", 
		"tileOverlayType": tileOverlayType, 
	}

	if tileOverlay:
		var extraData = tileOverlay.serialize()
		data["tileOverlay"] = extraData

	return data

func deserialize(data: Dictionary):
	var teamId: String = data.get("tileOverlayTeamId", "")
	setTileOverlay(data.get("tileOverlayType", ""), teamId)
	type = data["type"]
	max_health = data["max_health"]
	hardness = data["hardness"]
	hardnessMultiplier = data.get("hardnessMultiplier", Data.ofOr("map.hardnessMultiplier" + str(hardness), 2))
	layer = data["layer"]
	health = data.health
	richness = data["richness"]
	coord = BackwardCompatibilityUtils.str_to_var(data["coord"])
	biome = data["biome"]
	last_damage_from = BackwardCompatibilityUtils.str_to_var(data["last_damage_from"])

	if data.has("tileOverlay") and tileOverlay:
		tileOverlay.deserialize(data["tileOverlay"])
