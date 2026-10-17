extends "res://content/caves/Cave.gd"

signal hit(keeper: Keeper)

var hasSkeleton: = true
var keeper: Keeper

func _ready():
	super._ready()
	%Skeleton3D.play()

	%Explosion.visible = false

func serialize() -> Dictionary:
	var data = super.serialize()
	data["hasSkeleton"] = hasSkeleton
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	hasSkeleton = data["hasSkeleton"]
	setInitialState()

func setInitialState() -> void :
	%Skeleton3D.visible = hasSkeleton
	if currentState == State.REVEALED:
		%AmbSound.startSound()

func onRevealed():
	%AmbSound.startSound()
	%DiscoverySound.startSound()

func canFocusUse(keeper: Keeper) -> bool:
	return hasSkeleton and keeper.techId == "keeper1"

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if not hasSkeleton:
		return false

	hit.emit(keeper)
	return true

func registerHit(playerId: String) -> void :
	keeper = Keepers.getKeeper(playerId)
	hasSkeleton = false
	if keeper.is_multiplayer_authority():
		keeper.externallyMoved = true
		keeper.move *= 0

		var tween: = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(keeper, "global_position", %Usable.global_position, 0.2)
		tween.tween_callback(takeSkeleton).set_delay(0.3)
	else:
		var tween: = create_tween()
		tween.tween_callback(takeSkeleton).set_delay(0.5)

func _on_Explosion_animation_finished():
	%Explosion.visible = false

func takeSkeleton():
	keeper.externallyMoved = false
	%ActivatedSound.startSound()
	%Explosion.visible = true
	%Explosion.frame = 0
	%Explosion.play()

func _on_Explosion_frame_changed():
	if %Explosion.frame == 2:
		%Skeleton3D.visible = false
		if keeper and keeper.techId == "keeper1":
			keeper.setSkin("skin3")
			if multiplayer.is_server():
				GameWorld.newSkinsToUnlock.append({"keeperId": "keeper1", "skinId": "skin3"})
