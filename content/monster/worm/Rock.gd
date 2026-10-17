class_name WormRock
extends "res://content/monster/Monster.gd"

const reflectable: = false
var target: Vector2
var damage: float

func init():
	var random: = RandomNumberGenerator.new()
	random.seed = UID

	damage = Data.of("rock.damage")
	var peakY = (target.y + position.y) * 0.5 - 80 + random.randf() * 40
	var halfTime: = 1.0
	var delay: = 0.0
	$Sprite2D.play("flying")
	updateHitboxState()
	moveTween.interpolate_property(self, "position:x", position.x, target.x, halfTime * 2, Tween.TRANS_LINEAR, Tween.EASE_IN, delay)
	moveTween.interpolate_property(self, "position:y", position.y, peakY, halfTime, Tween.TRANS_QUAD, Tween.EASE_OUT, delay)
	moveTween.interpolate_property(self, "position:y", peakY, target.y, halfTime, Tween.TRANS_QUAD, Tween.EASE_IN, delay + halfTime)
	moveTween.interpolate_callback(self, delay + 2 * halfTime, "hitDome")
	moveTween.start()

func hitDome():
	var dome = Level.domesByTeamId[teamId]
	dome.requestMeleeDamage(damage * damageModifier, global_position, self)
	InputSystem.shake(60, 0.4, 8, global_position)
	animation("hit")
	$DieSoundImpact.startSound()
	die()

func domeAcceptsDamage():
	pass

func domeReflectsDamage(returnedDamage: = 0.0, returnedSpeed: = 1.0, damageModifier: = 1.0, duration: = 0.0):
	receiveDamage = returnedDamage

func onGameLost():
	if currentHealth > 0:
		die()
		animateDeath()

func animateDeath():
	animation("destroyed")
	$DieSoundDestroyed.startSound()

func _on_Sprite_animation_finished():
	if $Sprite2D.animation == "hit" or $Sprite2D.animation == "destroyed":
		super.removeFreeBlocker()

func domeAbsorbsDamage():
	if not dead:
		die()
		$DieSoundDestroyed.startSound()
		$Sprite2D.play("hit")

static func get_spawn_data(variant: String, teamId: String, flip_h: bool, spawnPosition: Vector2, targetPosition: Vector2, damageSource: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_bool(flip_h)
	stream.encode_vector2(spawnPosition)
	stream.encode_vector2(targetPosition)
	stream.encode_var(damageSource)


	return stream.data

func set_spawn_data(buffer: PackedByteArray):
	var stream: = PackedByteStream.from_bytes(buffer)

	setFlip(stream.decode_bool())
	position = stream.decode_vector2()
	target = stream.decode_vector2()
	damageSource = stream.decode_var()
