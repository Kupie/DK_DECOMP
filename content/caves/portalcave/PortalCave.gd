extends "res://content/caves/Cave.gd"

@export var synchronizer: Synchronizer

var cooldown: = 0.0

func onRevealed():
	find_child("Amb").startSound()
	$Sprites / Sprite.play("idle2")

func _physics_process(delta: float) -> void :
	if not multiplayer.is_server():
		return

	if GameWorld.paused:
		return

	if cooldown > 0.0:
		cooldown -= delta
		return

	var bods: Array = $TeleportArea.get_overlapping_bodies()
	if bods.size() > 0:
		var drop = bods.pick_random()
		drop.floatToDropTarget(self)
		cooldown = 0.2

		synchronizer.network_rpc(playTeleportAnimation.bind(drop.UID), true)

@rpc("reliable")
func playTeleportAnimation(dropUID: int) -> void :
	if not Level.drops.has_drop(dropUID):
		return
	var drop: Drop = Level.drops.get_drop(dropUID)
	drop.dropTargetRef = self
	drop.shrink(drop.teamId if drop.teamId != "" else "team1")
	drop.deactivate()
	drop.noCollisions()
	$Sprites / Sprite.play("teleport2")

func _on_sprite_animation_finished() -> void :
	if $Sprites / Sprite.animation == "teleport2":
		$Sprites / Sprite.play("idle2")
	elif $Sprites / Sprite.animation == "teleport1":
		$Sprites / Sprite.play("idle1")

func dropTarget():
	return $GravityArea.global_position

func arrived(drop):
	pass
