class_name Chamber
extends Node2D

signal hit(keeper: Keeper)

@export var drop_type: String = ""
@export var type: = "chamber"
@export var tileCover: TileMap

enum State{HIDDEN, REVEALED, OPENING, OPEN, EMPTY}
var currentState = State.HIDDEN
var additionalState: int = 0

var tileCoords: = []
var coord: Vector2

var chamberType

func _ready():
	Style.init(self)

	tileCover.modulate = Style.TILE_COVER_MODULATE
	_updateTileCoverForEmptyTiles()

func serialize() -> Dictionary:
	var tileCoverData: = {}
	if has_node("TileCover"):
		for c in tileCover.get_used_cells(MapData.DEFAULT_LAYER):
			tileCoverData[var_to_str(c)] = tileCover.get_cell_source_id(MapData.DEFAULT_LAYER, Vector2i(c.x, c.y))

	var data = {
		"coord": var_to_str(coord), 
		"tileCoords": var_to_str(tileCoords), 
		"currentState": currentState, 
		"type": type, 
		"tileCover": tileCoverData
	}

	data["meta.priority"] = 100
	data["meta.kind"] = "chamber"
	data["meta.chamberType"] = chamberType
	data["meta.scenepath"] = scene_file_path

	return data

func deserialize(data: Dictionary):
	coord = BackwardCompatibilityUtils.str_to_var(data["coord"])
	tileCoords = BackwardCompatibilityUtils.str_to_var(data["tileCoords"])
	currentState = int(data["currentState"]) as State
	type = data["type"]

	if currentState == State.HIDDEN:
		if not Level.map.tiles.has(coord) and Level.map.visibleTileCoords.has(coord):
			currentState = State.REVEALED
			Logger.error("chamber was hidden but should have been revealed", "Chamber.deserialize", data)

	tileCover.clear()
	for key in (data["tileCover"] as Dictionary).keys():
		var c = BackwardCompatibilityUtils.str_to_var(key)
		var v = int(data["tileCover"][key])
		tileCover.set_cell(MapData.DEFAULT_LAYER, c, v, Vector2i(0, 0))

	onStateUpdated()

func onStateUpdated() -> void :
	_updateTileCoverForEmptyTiles()




	for c in tileCoords:
		var absCoord = coord + Vector2(c)
		if tileCover.get_cell_source_id(MapData.DEFAULT_LAYER, c) == CONST.TILEMAP_INVALID_CELL:
			Level.map.onTileRemoved(absCoord)

	var remainingCells = tileCover.get_used_cells(MapData.DEFAULT_LAYER).size()
	if remainingCells == 0 and currentState == State.REVEALED:
		onExcavated()

	if currentState == State.REVEALED:
		show()
		onRevealed()
	if currentState == State.OPEN or currentState == State.OPENING:
		show()
		currentState = State.OPEN
	if currentState == State.EMPTY:
		show()
		onUsed()

func _updateTileCoverForEmptyTiles() -> void :
	for c in tileCoords:
		var absCoord = coord + Vector2(c)
		var isEmpty = Level.map.is_tile_empty(absCoord)
		if isEmpty:
			tileCover.set_cell(MapData.DEFAULT_LAYER, Vector2i(c.x, c.y), CONST.TILEMAP_INVALID_CELL)

func place(c: Vector2):
	var cells = tileCover.get_used_cells(MapData.DEFAULT_LAYER)
	for cell in cells:
		tileCoords.append(cell)
	coord = c
	position = coord * GameWorld.TILE_SIZE - Vector2(GameWorld.TILE_SIZE, GameWorld.TILE_SIZE) * 0.5
	visible = false

func tileDestroyed(tileCoord: Vector2):
	var c = tileCoord - coord
	tileCover.set_cell(MapData.DEFAULT_LAYER, Vector2i(c.x, c.y), CONST.TILEMAP_INVALID_CELL)
	var remainingCells = tileCover.get_used_cells(MapData.DEFAULT_LAYER).size()

	if remainingCells == 0 and currentState == State.REVEALED:
		onExcavated()


func open():
	currentState = State.OPENING
	tileCover.queue_free()
	for c in tileCoords:
		Level.map.removeTileDestroyedListener(self, coord + Vector2(c))
	onOpening()
	Backend.event("chamber", {"status": "opened", "coord": tileCoords, "type": type})

func onRevealed():
	pass

func onExcavated():
	pass

func onUsed():
	pass

func onOpening():
	pass

func addCable(cable):
	pass

func tileRevealed(tileCoord: Vector2):
	if currentState == State.HIDDEN:
		currentState = State.REVEALED
		onRevealed()
		visible = true
		Backend.event("chamber", {"status": "revealed", "coord": tileCoords, "type": type})

func canFocusUse(keeper: Keeper) -> bool:
	return currentState == State.OPEN

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if currentState == State.OPEN:
		hit.emit(keeper)
		return true
	else:
		return false

func registerHit(playerId: String) -> void :
	if multiplayer.is_server():
		if drop_type != "":
			var teamId = Keepers.getKeeper(playerId).teamId
			var gizmo_position = find_child("GizmoSpawn").global_position
			Level.drops.network_spawn({
				"type": drop_type, 
				"position": gizmo_position, 
				"carriers": [playerId], 
				"team": teamId, 
			})
	currentState = State.EMPTY
	onUsed()
	Backend.event("chamber", {"status": "used", "coord": tileCoords, "type": type})

func getCenter() -> Vector2:
	return $Usable.position

func getTileType() -> int:
	return Data.TILE_GADGET

func isRevealed() -> bool:
	return currentState != State.HIDDEN
