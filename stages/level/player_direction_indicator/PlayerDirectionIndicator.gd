class_name PlayerDirectionIndicator
extends Control

const ICON_SCALE: = 2.0
const ARROW_SCALE: = 4.0
const ARROW_DISTANCE: = 26.0
const ARROW_OPAQUE_EXTENTS_FROM_PIVOT: = Vector2(3.0, 6.0)
const TRANSITION_DURATION: = 0.5

var keeper: Keeper

var _transition: = 0.0
var _separationDiameter: float

func init(inKeeper: Keeper) -> void :
	keeper = inKeeper
	var colorId = keeper.colorId
	if keeper.remapColorIdPerPalette:
		var mapping: Array = Data.palette_rgby.get(Style.paletteId)
		if mapping:
			colorId = "color" + str(mapping[int(keeper.colorId.substr(5))] - 1)
		else:
			Logger.error("wanted to remap keeper color, but palette does not have mapping table", "PlayerDirectionIndicator.init", {"playerId": keeper.playerId, "skinId": keeper.skinId, "colorId": keeper.colorId, "paletteId": Style.paletteId})

	var keeperIcon: Texture2D = load("res://content/icons/loadout_%s-%s-%s.png"\
	%[keeper.techId, keeper.skinId, colorId])

	%KeeperIcon.texture = keeperIcon
	%KeeperIcon.scale = Vector2.ONE * ICON_SCALE
	%Arrow.position = Vector2.RIGHT * ARROW_DISTANCE
	%Arrow.scale = Vector2.ONE * ARROW_SCALE
	_separationDiameter = calculateSeparationDiameter(keeperIcon.get_size())
	Style.init(self)

func updateTransition(shouldShow: bool, delta: float) -> float:
	var target: = 1.0 if shouldShow else 0.0
	_transition = move_toward(_transition, target, delta / TRANSITION_DURATION)
	return _transition

func hideImmediately() -> void :
	_transition = 0.0
	hide()

func getSeparationDiameter() -> float:
	return _separationDiameter

func placeAt(edgePosition: Vector2, projectedKeeperPosition: Vector2) -> void :
	var transitionWeight: = smoothstep(0.0, 1.0, _transition)
	position = projectedKeeperPosition.lerp(edgePosition, transitionWeight)
	%AimIndicator.rotation = (projectedKeeperPosition - edgePosition).angle()
	modulate.a = transitionWeight

static func calculateSeparationDiameter(iconTextureSize: Vector2) -> float:
	var iconRadius: = (iconTextureSize * ICON_SCALE).length() * 0.5
	var arrowRadius: = ARROW_DISTANCE + (ARROW_OPAQUE_EXTENTS_FROM_PIVOT * ARROW_SCALE).length()
	return maxf(iconRadius, arrowRadius) * 2.0
