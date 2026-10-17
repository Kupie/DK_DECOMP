extends DomeStation

func _ready():
	super._ready()
	$Fill.play("default")
	$FillBG.play("default")
	$WaveAlarm.visible = false
	await StageManager.stage_started

func keeperEnteredStation():
	$KeeperSprite.sprite_frames = keeperInStation.keeper_sprite.sprite_frames
	$Fill.play("fill")
	$FillBG.play("fill")
	$AnimationPlayer.play("fill")
	$AirBubbles.show()
	$AirBubbles.emitting = true
	$KeeperSprite.show()
	$Usable.updateFocus()
	$WaveAlarm.visible = false

func keeperExitedStation():
	$KeeperSprite.material.set_shader_parameter("water_strength", 0.0)
	$Fill.play("flush")
	$FillBG.play("flush")
	$Cables.play("default")
	$AirBubbles.hide()
	$AirBubbles.emitting = false
	$KeeperSprite.hide()
	$Usable.updateFocus()
	if Data.of(teamId + ".monsters.wavepresent"):
		$WaveAlarm.visible = true

func waveAlertOn():
	$WaveAlarm.visible = true
	$WaveAlarm.frame = 0
	$WaveAlarm.play()

func waveAlertOff():
	$WaveAlarm.visible = false

func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "fill":
		$AnimationPlayer.play("idle")
		$Cables.play("active")
