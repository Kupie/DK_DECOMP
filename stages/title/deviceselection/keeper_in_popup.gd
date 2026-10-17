extends MarginContainer

var player_id: String

func set_data(player_id: String, sprite_frames: SpriteFrames):
	self.player_id = player_id
	%KeeperInUI.set_sprite_frames(sprite_frames)
