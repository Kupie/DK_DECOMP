extends PanelContainer

signal select

const BUTTON_DISABLED_STYLE = preload("res://gui/buttons/button_disabled.tres")
const BUTTON_EMPTY_STYLE = preload("res://gui/panels/panel_inside_frame.tres")
const PANEL_INSIDE_DARK_STYLE = preload("res://gui/panels/panel_inside_dark.tres")

var filling: = 0.0
var disabled: = false
var clientOnlyMode: = false

func _ready():
	Style.init(self)

	_on_resized()

func _process(delta):
	if disabled:
		if filling > 0:
			filling = 0
			$VBoxContainer / ProgressBar.value = roundf(filling)
		return

	var nmbOfKeepersNeededToStart = _getNmbOfKeepersToStart()
	var count = %Usable.get_overlapping_bodies().size()
	var goalFill = 100 * (0 if nmbOfKeepersNeededToStart == 0 else count / float(nmbOfKeepersNeededToStart))
	var diff = (1.0 * goalFill) - filling
	var was_not_finished: = filling < 100.0
	filling = clampf(filling + (diff * 2 + sign(diff) * 10) * delta, 0.0, 100.0)
	modulate = Color.WHITE

	if filling >= 100.0:
		if was_not_finished:
			$AllReadySound.play()
		set("theme_override_styles/panel", PANEL_INSIDE_DARK_STYLE)
		%LabelHint.visible = false
	else:
		set("theme_override_styles/panel", BUTTON_EMPTY_STYLE)
		%LabelHint.visible = true



	$VBoxContainer / ProgressBar.value = roundf(filling)

func _getNmbOfKeepersToStart() -> int:
	if clientOnlyMode:
		return Keepers.local.getCount()

	var allKnownKeepers: Array = Keepers.getAll()

	var allKnownPeers: PackedInt32Array = multiplayer.get_peers()
	var localPeerId: int = multiplayer.get_unique_id()
	allKnownPeers.append(localPeerId)

	var doPeerHaveKeeper: Dictionary = {}
	for peerId: int in allKnownPeers:
		doPeerHaveKeeper[peerId] = false
	for keeper: Keeper in allKnownKeepers:
		doPeerHaveKeeper[keeper.peerId] = true

	var nmbOfPeersWithoutKeeper: int = 0
	for peerId in doPeerHaveKeeper:
		if not doPeerHaveKeeper[peerId]:
			nmbOfPeersWithoutKeeper += 1

	return allKnownKeepers.size() + nmbOfPeersWithoutKeeper

func isAnyPeerOutsideStartButton() -> bool:
	return _geKeepersInsideStartArea().size() != _getNmbOfKeepersToStart()

func _geKeepersInsideStartArea() -> Array:
	return %Usable.get_overlapping_bodies()

func set_enabled(enable: bool):
	if enable:
		disabled = false
		modulate.a = 1.0
		%LockIcon.hide()
		$Usable.monitorable = true
		$Usable.monitoring = true
	else:
		disabled = true
		modulate.a = 0.5
		%LockIcon.show()
		set("theme_override_styles/panel", BUTTON_DISABLED_STYLE)
		$Usable.monitorable = false
		$Usable.monitoring = false

func setChoice(titleKey: String, id: String, icon: Texture2D, hint = null):
	if titleKey == "":
		%LabelTitle.visible = false


	else:
		%LabelTitle.visible = true
		%LabelTitle.text = tr(titleKey)

func shakeBar(amount: float):
	var pb = find_child("ProgressBar")
	pb.pivot_offset = pb.size * 0.5
	pb.scale = (1.0 + amount * randf() * 0.2) * Vector2.ONE
	pb.rotation = amount * randf() * 20

func canFocusUse(keeper: Keeper) -> bool:
	return true

func useHold(keeper: Keeper) -> bool:
	return false

func useHit(keeper: Keeper) -> bool:
	if filling >= 100.0 and not isAnyPeerOutsideStartButton():
		select.emit()
	else:
		Audio.sound("loadout_cannot_start")
	return true

func checkReady() -> bool:
	if $VBoxContainer / ProgressBar.value >= 1:
		return true
	else:
		$Tween.interpolate_method(self, "shakeBar", 1.0, 0.0, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
		$Tween.start()
		return false

func _on_resized() -> void :
	var shape: = RectangleShape2D.new()
	shape.size.x = size.x - 16
	shape.size.y = size.y - 16
	%Usable.find_child("CollisionShape2D").shape = shape
	%Usable.position = size * 0.5
