extends Node2D

var keeperInStation: Keeper
var virtualCameraTarget
var screenEffect
var teamId: String
var tw
var keeperId: String
var inputProcessor = null

func _ready():
	$Sprite2D.play("idle")
	$SpriteBackground.visible = false
	$KeeperSprite.visible = false

func init(teamId: String):
	Style.init(self)

	self.teamId = teamId

	var other_team = "team" + str(3 - int(teamId.substr(4, 1)))
	if Level.worldsByTeamId.has(other_team):
		virtualCameraTarget = preload("res://content/gadgets/remotecontrol/VirtualCameraTarget.tscn").instantiate()
		virtualCameraTarget.position = Level.worldsByTeamId.get(other_team).getDomePosition()
		virtualCameraTarget.teamId = other_team
		Level.map.add_child(virtualCameraTarget)

func setCamOnDome():
	var cam = InputSystem.getCamera(keeperInStation.playerId)
	if cam:
		cam.target = virtualCameraTarget
		cam.updateCameraRestPosition()
		cam.jump()

func setCamOnKeeper():
	var cam = InputSystem.getCamera(keeperInStation.playerId)
	if cam:
		var keeper: Keeper = Keepers.getKeeper(keeperInStation.playerId)
		cam.target = keeperInStation
		cam.updateCameraRestPosition()
		keeperInStation.virtuallyIsInsideDome = false
		keeperInStation.isInsideDome = false
		cam.jump()
		Style.setPalette(Style.paletteId)
		Level.stage.getVignette(keeper).modulateOnPlayerY = true

func getHud(keeper: Keeper):
	for hud in get_tree().get_nodes_in_group("hud"):
		if keeper.playerId == hud.playerId:
			return hud
	return null

func transitionToDome(keeper):
	var hud = getHud(keeper)
	hud.moveOut()

	if not screenEffect:
		screenEffect = preload("res://content/gadgets/remotecontrol/RemoteStationScreenEffects.tscn").instantiate()
		screenEffect.teamId = teamId
		Level.stage.showPopup(screenEffect, keeper, "", LevelStage.PopupCanvas.PLAYER_WORLD)

	keeper.virtuallyIsInsideDome = true

	screenEffect.set_effects_active(false)
	screenEffect.set_visible(true)
	screenEffect.fade_out()

	if tw:
		tw.kill()

	tw = create_tween()
	tw.tween_callback( func():
		screenEffect.set_effects_active(true)
		screenEffect.fade_in()
		$ActivateSound.startSound()
		Level.stage.getVignette(keeper).modulateOnPlayerY = false
		setCamOnDome()
	).set_delay(1)

func canFocusUse(keeper: Keeper) -> bool:
	return not keeperInStation and keeper.canEnterRemoteStation()


func useHold(keeper: Keeper) -> bool:
	return false

func useHit(keeper: Keeper) -> bool:
	if not canFocusUse(keeper):
		return false

	keeperId = keeper.techId
	keeper.enterStation(self, false)
	$EnterStationSound.startSound()
	keeperInStation = keeper
	$KeeperSprite.sprite_frames = keeperInStation.keeper_sprite.sprite_frames

	$Sprite2D.play("on")
	$Usable.updateFocus()


	$KeeperSprite.sprite_frames = keeperInStation.keeper_sprite.sprite_frames
	$KeeperSprite.visible = true

	var i = preload("res://content/dome/spycam/SpyCamInputProcessor.gd").new()
	i.teamId = teamId
	i.deviceId = keeper.deviceId
	i.keeper = keeper
	i.station = self
	i.integrate(self)
	inputProcessor = i
	i.popup = preload("res://content/hud/Hud.tscn").instantiate()
	i.popup.playerId = keeper.playerId
	var other_team = "team" + str(3 - int(teamId.substr(4, 1)))
	i.popup.teamId = other_team
	i.popup.calculate_locations()
	if Data.of(teamId + ".versus.spyinventory"):
		var inv = preload("res://content/hud/inventory/Inventory.tscn").instantiate()
		inv.layoutWeights = Vector2(1, 10)
		i.popup.addHudElement(inv)
	var hm = preload("res://content/hud/healthmeter/HealthMeter.tscn").instantiate()
	hm.layoutWeights = Vector2(1, 10)
	hm.layoutPriority = 5
	i.popup.addHudElement(hm)
	i.popup.addHudElement(preload("res://content/dome/spycam/TitleHudElement.tscn").instantiate())
	Level.stage.showPopup(i.popup, keeper)
	i.popup.anchors_preset = Control.PRESET_BOTTOM_LEFT

	return true

func exitStation():
	var hud = getHud(keeperInStation)
	hud.moveIn()

	$KeeperSprite.visible = false
	if is_instance_valid(keeperInStation) and keeperInStation.peerId == multiplayer.get_unique_id():
		if screenEffect:
			closeScreenEffect()
			var tw = create_tween()
			tw.tween_callback( func():
				keeperInStation = null
				$Sprite2D.play("off")
			).set_delay(1.5)
		else:
			setCamOnKeeper()
			$ExitStationSound.startSound()
			$Sprite2D.play("off")

	if is_instance_valid(keeperInStation):
		keeperInStation.exitStation()

	if not screenEffect:
		keeperInStation = null

func closeScreenEffect():
	if not screenEffect:
		return

	if tw:
		tw.kill()

	screenEffect.set_effects_active(true)
	screenEffect.set_visible(true)
	screenEffect.fade_out()
	tw = create_tween()
	tw.tween_callback( func():
		if screenEffect:
			screenEffect.set_effects_active(false)
			screenEffect.fade_in()
		setCamOnKeeper()
		$ExitStationSound.startSound()
	).set_delay(1)
	tw.tween_callback( func():
		if screenEffect:
			screenEffect.queue_free()
			screenEffect = null
	).set_delay(0.5)

func getKeeperPosition():
	return $KeeperPosition.global_position

func enable():
	visible = true
	$Usable.monitorable = true
	$Usable.monitoring = true

func disable():
	visible = false
	$Usable.monitorable = false
	$Usable.monitoring = false

func _on_sprite_2d_animation_finished() -> void :
	if $Sprite2D.animation.begins_with("on"):
		$Sprite2D.play("running")
	elif $Sprite2D.animation == "off":
		$Sprite2D.play("idle")

func _on_sprite_2d_animation_looped() -> void :
	_on_sprite_2d_animation_finished()

func _on_sprite_2d_frame_changed() -> void :
	if $Sprite2D.animation == "on" and $Sprite2D.frame == 6:
		$KeeperSprite.visible = true
		$SpriteBackground.visible = true
	elif $Sprite2D.animation == "off" and $Sprite2D.frame == 3:
		$SpriteBackground.visible = false
