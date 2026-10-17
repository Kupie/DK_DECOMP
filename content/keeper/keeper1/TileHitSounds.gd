extends Node2D

func hit(tile, buffed: bool, playHitPitch: bool):

	var soundPlayer = get_node("TileHitHardness" + str(tile.hardness))
	soundPlayer.startSound()

	if playHitPitch:
		$TileHitPitch.pitch_scale = 0.8 + 0.4 * (1.0 - tile.health / tile.max_health)
		$TileHitPitch.startSound()


	if has_node("TileHit" + tile.type.capitalize()):
		soundPlayer = get_node("TileHit" + tile.type.capitalize())
		soundPlayer.startSound()

	if buffed:
		$TileHitBuffed.startSound()
