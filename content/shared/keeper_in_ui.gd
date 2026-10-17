extends Control


func set_keeper(keeper: Keeper):
	set_sprite_frames(keeper.keeper_sprite.sprite_frames)

func set_sprite_frames(sf: SpriteFrames):
	$Control / AnimatedSprite2D.sprite_frames = sf
	$Control / AnimatedSprite2D.play("default")
