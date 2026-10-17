class_name SwordBombExplosion
extends Explosion

signal hit_monster(monster: Monster, source: String, damage: float, stun: float)

func _on_Area2D_area_entered(area):
	if not area is Monster:
		return

	var monster: = area as Monster
	hit_monster.emit(monster, damageSource, damage, stun)
