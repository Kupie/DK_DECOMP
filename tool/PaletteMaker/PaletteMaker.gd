extends Node2D

var world
var dome
var keeper
var lastModifiedPalette: = 0.0
var paletteIndex

func _ready():
	Style.FOCUS_MODULATE.r = 1.0
	Style.FOCUS_MODULATE.g = 1.0
	Style.FOCUS_MODULATE.b = 1.0

	$CanvasLayer.visible = true

	Engine.max_fps = 60

	var dir = DirAccess.open("res://content/worlds/")
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		if not file.begins_with(".") and dir.current_is_dir() and file.to_lower().begins_with("world"):
			find_child("WorldsList").add_item(file)

	dir = DirAccess.open("res://content/dome/")
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		if not file.begins_with(".") and dir.current_is_dir() and file.to_lower().begins_with("dome"):
			find_child("DomesList").add_item(file)

	dir = DirAccess.open("res://content/gadgets/")
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		if not file.begins_with(".") and dir.current_is_dir():
			find_child("GadgetsList").add_item(file)

	dir = DirAccess.open("res://content/keeper/")
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		if not file.begins_with(".") and dir.current_is_dir() and file.to_lower().begins_with("keeper"):
			find_child("KeepersList").add_item(file)

	dir = DirAccess.open("res://systems/style/palettes/")
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		if file.to_lower().begins_with("palette_") and file.to_lower().ends_with(".png"):
			var start = file.find("_") + 1
			find_child("PaletteList").add_item(file.substr(start, file.find(".") - start))

	GameWorld.prepareCleanData()
	Level.map = $Map
	Level.stage = self

	Style.init($CanvasLayer)
	Style.init($Monsters)
	Style.init($Underground)
	Style.init($Skull)
	Style.init($PanelContainer)
	Style.setPalette("palette_1_1")
	$Skull.visible = false

	var tileData = load("res://tool/PaletteMaker/TileDataPalette.tscn").instantiate()
	$Map.setTileData(tileData)
	$Map.init()
	$Map.revealInitialState()

	$Map.find_child("BorderDecorations").runDecoration()
	$Map.find_child("BorderDecorations").runDecoration()
	$Map.find_child("BorderDecorations").runDecoration()



	find_child("PaletteList").select(0)
	_on_PaletteList_item_selected(0)
	find_child("WorldsList").select(0)
	_on_WorldsList_item_selected(0)
	find_child("DomesList").select(0)
	_on_DomesList_item_selected(0)
	find_child("KeepersList").select(0)
	_on_KeepersList_item_selected(0)

	$CanvasLayer / ReloadLabel.visible = false

	var i = preload("res://content/shared/MoveCameraInput.gd").new()
	i.camera = $Camera2D
	i.integrate(self)

	Data.apply("team1.monsters.wavepresent", true)
	Data.apply("team1.stunLaser.autonomy", true)
	var d = preload("res://content/monster/driller/Driller.tscn").instantiate()
	d.path = $Monsters / Path2D
	d.position = Vector2(520, -80)
	$Monsters.add_child(d)
	d.phase = -1

	GameWorld.addUpgrade("drill")

func register_action_hint(a, b):
	return 0

func set_action_hint_visible(a, b):
	pass

func _process(delta):
	if Input.is_action_just_pressed("f2"):
		find_child("GuiExample").visible = not find_child("GuiExample").visible

	if Input.is_action_just_pressed("cheats"):
		find_child("Controls").visible = not find_child("Controls").visible

	if paletteIndex:
		var mod = FileAccess.get_modified_time("res://systems/style/palettes/" + str(paletteIndex) + ".png")
		if lastModifiedPalette == 0.0:
			lastModifiedPalette = mod

		if mod != lastModifiedPalette:
			await get_tree().process_frame
			Style.setPalette(paletteIndex, true)
			lastModifiedPalette = mod
			$CanvasLayer / ReloadLabel.visible = true
			$CanvasLayer / ReloadLabel / Timer.start()

func _on_WorldsList_item_selected(index):
	if world:
		world.queue_free()
		world = null

	var worldName = find_child("WorldsList").get_item_text(index)
	var scene = load("res://content/worlds/" + worldName + "/" + worldName.capitalize().replace(" ", "") + ".tscn")
	if not scene:
		return
	world = scene.instantiate()
	add_child(world)
	world.addBackgroundHub(preload("res://content/gamemode/prestige/rocket/RocketHub.tscn").instantiate())
	Style.init(world)

func _on_DomesList_item_selected(index):
	updateDome(index)

func addElement(e):
	add_child(e)

func addDome(dome, teamId: String):
	pass

func addKeeper(instance):
	pass

func updateDome(index: = -1):
	if dome:
		dome.free()
		Data.apply("shield.stage", 0)
		dome = null

	if index == -1:
		if find_child("DomesList").get_selected_items().size() == 0:
			return
		else:
			index = find_child("DomesList").get_selected_items()[0]

	var domeName = find_child("DomesList").get_item_text(index)
	var scene = load("res://content/dome/" + domeName + "/" + domeName.capitalize().replace(" ", "") + ".tscn")
	if not scene:
		return
	dome = scene.instantiate()
	dome.position = $DomePosition.position
	Level.domesByTeamId["team1"] = dome
	add_child(dome)
	dome.init()
	GameWorld.addUpgrade(dome.primaryWeapon)
	dome.addWeapon()
	var weapon = dome.find_child("WeaponContainer").get_children().front()
	if weapon:
		weapon.start()
	dome.find_child("CracksOverlay").visible = false
	Style.init(dome)
	unlockGadgets()
	Data.apply("team1.dome.health", Data.of("team1.dome.maxhealth"))

	Audio.set_bus_volume(Audio.BUS_MASTER, -60)
	_on_CellarOnButton_pressed()

func _on_KeepersList_item_selected(index):
	updateKeeper(index)

func updateKeeper(index: = -1):
	if keeper:
		keeper.queue_free()
		keeper = null

	var keeperName = find_child("KeepersList").get_item_text(index)
	var scene = load("res://content/keeper/" + keeperName + "/" + keeperName.capitalize().replace(" ", "") + ".tscn")
	if not scene:
		return
	keeper = scene.instantiate()
	keeper.playerId = "player1"
	keeper.deviceId = 0
	keeper.peerId = multiplayer.get_unique_id()
	keeper.position = $KeeperPosition.position
	GameWorld.addUpgrade(keeper.techId)
	add_child(keeper)
	Style.init(keeper)
	keeper.init()

	var keeper2 = scene.instantiate()
	keeper2.position = Vector2(-24, 0)
	keeper2.playerId = "player2"
	keeper.add_child(keeper2)
	keeper2.init()
	Style.init(keeper2)

	var keeper3 = scene.instantiate()
	keeper3.position = Vector2(-2, 204)
	keeper3.playerId = "player3"
	keeper.add_child(keeper3)
	keeper3.init()
	Style.init(keeper3)

	Style.init($KeeperMinePosition)

	Keepers.registerKeeper(keeper)

func _on_GadgetsList_multi_selected(index, selected):
	updateDome()

func unlockGadgets():
	for i in find_child("GadgetsList").get_selected_items():
		var gadgetName = find_child("GadgetsList").get_item_text(i)
		unlockGadget(gadgetName.to_lower())

func unlockGadget(id: String):
	GameWorld.addUpgrade(id)

func _on_PaletteList_item_selected(index):
	var n = find_child("PaletteList").get_item_text(index)
	paletteIndex = "palette_" + n
	Style.setPalette(paletteIndex)

func _on_Timer_timeout():
	find_child("ReloadLabel").visible = false

func _on_ShowMonstersButton_pressed():
	$Monsters.visible = find_child("ShowMonstersButton").button_pressed

func _on_UseWeaponButton_pressed():
	if find_child("UseWeaponButton").button_pressed:
		setWeaponFire(1.0, 0.0)
	else:
		$WeaponTween.remove_all()

func setWeaponFire(fire: float, special: float, dir: Vector2 = Vector2.DOWN):
	var weapon = dome.get_node("WeaponContainer").get_children().front()
	if weapon:
		weapon.inputs(dir, fire, special)
		$WeaponTween.interpolate_callback(self, 1.2, "setWeaponFire", dir * Vector2.UP)
		$WeaponTween.start()

func _on_SpecialWeaponButton_pressed():
	if find_child("SpecialWeaponButton").pressed:
		setWeaponFire(0.0, 1.0)
	else:
		$WeaponTween.remove_all()
		setWeaponFire(0.0, 0.0)

func _on_CellarOnButton_pressed():
	if dome:
		if find_child("CellarOnButton").button_pressed:
			dome.find_child("RelicActivation").play("activate")
		else:
			dome.find_child("RelicActivation").play("none")
			dome.find_child("SpinningRelic").play("none")

func _on_FireRocketButton_pressed():
	Data.changeByInt("prestige.sentiron", 1)

func _on_FireRelicButton_pressed():
	$Skull.visible = not $Skull.visible
