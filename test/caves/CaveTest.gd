extends Stage

@onready var _battle_ambience: Node = $Monsters / BattleAmbience

func _ready():
	Style.setPalette("palette_1_1")
	GameWorld.prepareCleanData()
	Level.map = $Map
	Level.monstersByTeamId["team1"] = $Monsters
	Level.domesByTeamId["team1"] = $Dome
	Level.stage = self
	Level.loadout = Loadout.new()
	Level.initialized = true
	$Camera2D.init($Keeper)
	_battle_ambience.init("team1")

	GameWorld.addUpgrade("keeper1")
	GameWorld.addUpgrade("dome1")
	Data.apply("keeper1.maxSpeed", 100)
	Options.loadOptions()

	$Map.setTileData($TileData)
	$Map.init()
	GameWorld.isHalloween = true
	var caves: = [
		preload("res://content/caves/drillicave/DrillbertCave.tscn").instantiate(), 
		preload("res://content/caves/teleportcave/TeleportCave.tscn").instantiate(), 
		preload("res://content/caves/mushroomcave/MushroomCave.tscn").instantiate(), 
		preload("res://content/caves/bombcave/BombCave.tscn").instantiate(), 
		preload("res://content/caves/helmetextensioncave/HelmetCave.tscn").instantiate(), 
		preload("res://content/caves/seedcave/SeedCave.tscn").instantiate(), 
		preload("res://content/caves/dronecave/DroneCave.tscn").instantiate(), 
		preload("res://content/caves/scannercave/ScannerCave.tscn").instantiate(), 
		preload("res://content/caves/cobaltcave/CobaltCave.tscn").instantiate(), 
		preload("res://content/caves/halloweencave/HalloweenSkeletonCave.tscn").instantiate(), 
		preload("res://content/map/chamber/nest/NestCave.tscn").instantiate()
	]
	for layerIndex in 20:
		prints("layer", layerIndex)
		for cave in caves:
			var biomeFits = cave.biome == "" or $Map.biomes[layerIndex] == cave.biome
			var minLayerFits = cave.minLayer <= layerIndex
			var relativeDepth = layerIndex / float(20)
			var minDepthFits = round(relativeDepth * cave.minRelativeDepth) <= layerIndex
			var maxDepthFits = layerIndex <= round(cave.maxRelativeDepth * 20)
			prints(cave.name, biomeFits, minLayerFits, minDepthFits, maxDepthFits)
			if biomeFits and minLayerFits and minDepthFits and maxDepthFits:
				$Map.addCave(cave, layerIndex, 0)
				caves.erase(cave)
				break

	for c in $TileData.get_resource_cells_by_id(10):
		$TileData.clear_resource(c)

	find_child("Hud").init()
	GameWorld.levelInitialized()
	$Map.revealInitialState()

	var keeperInputProcessor = preload("res://content/keeper/Keeper1InputProcessor.gd").new()
	keeperInputProcessor.keeper = $Keeper
	keeperInputProcessor.integrate(self)

func openPauseMenu(keeper: Keeper):
	GameWorld.setShowMouse(true)
	var i = preload("res://content/pause/PauseInputProcessor.gd").new()
	i.blockAllKeys = true
	i.globalInput = true
	i.popup = load("res://content/pause/PauseMenu.tscn").instantiate()
	add_child(i.popup)
	i.integrate(self)
	i.connect("stopping", Callable(i.popup, "fadeOut").bind(0.3))
	i.connect("onStop", Callable(self, "pauseClosed"))
	i.popup.connect("close", Callable(i, "desintegrate"))
	pause()

func pauseClosed():
	GameWorld.setShowMouse(false)
	unpause()

func unpause():
	GameWorld.unpause()
	get_tree().call_group("monster", "unpause")

func pause():
	GameWorld.pause()
	get_tree().call_group("monster", "pause")

func toggleCheats():
	var c = find_child("Cheats")
	c.visible = not c.visible
	if c.visible:
		Audio.sound("gui_cheats")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		GameWorld.setShowMouse(true)
	else:
		Audio.sound("gui_cheats")
		if not GameWorld.showMouse:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
