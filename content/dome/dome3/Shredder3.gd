extends "res://content/dome/shredder/Shredder.gd"

func processDrop(drop):
	drop.z_index -= 10
	drop.dropTargetRef = null
	drop.dropTargetPosition = $ShrinkPosition.global_position
	drop.shrink(teamId)

	$Splash.frame = 0
	$Splash.play()
