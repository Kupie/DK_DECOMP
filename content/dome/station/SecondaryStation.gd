extends DomeStation

func _ready():
	super._ready()
	$Sprite2D.play("idle")
	$SpriteBackground.visible = false
	$KeeperSprite.visible = false

func keeperEnteredStation():
	$KeeperSprite.sprite_frames = keeperInStation.keeper_sprite.sprite_frames
	$Sprite2D.play("on")
	$Usable.updateFocus()

func keeperExitedStation():
	$KeeperSprite.visible = false
	$Sprite2D.play("off")
	$Usable.updateFocus()
	if Data.of(teamId + ".monsters.wavepresent"):
		$Sprite2D.play("attack")

func waveAlertOn():
	$Sprite2D.play("attack")

func _on_sprite_2d_animation_looped() -> void :
	_on_Sprite_animation_finished()

func _on_Sprite_animation_finished() -> void :
	if $Sprite2D.animation.begins_with("on"):
		$Sprite2D.play("running")
	elif $Sprite2D.animation == "off":
		$Sprite2D.play("idle")

func enable():
	visible = true
	$Usable.monitorable = true
	$Usable.monitoring = true
	$KunaiStickSurface.set_active(true)

func disable():
	visible = false
	$Usable.monitorable = false
	$Usable.monitoring = false
	$KunaiStickSurface.set_active(false)

func _on_Sprite_frame_changed():
	if $Sprite2D.animation == "on" and $Sprite2D.frame == 6:
		$KeeperSprite.visible = true
		$SpriteBackground.visible = true
	elif $Sprite2D.animation == "off" and $Sprite2D.frame == 3:
		$SpriteBackground.visible = false
