extends Node2D
class_name Shockwave

signal hit_monster(monster: Monster, source: String, damage: float, stun: float, immediateStun: bool)

var teamId: String

var progress: = 0.0
var handledMonsters: = []
var speed: = 700
var affect_enemies: = true
var hit_damage: = 0.0
var hit_stun_strength: = 0.0
var hit_stun_duration: = 0.0
var max_size: = 800
var tier: = 0

@onready var dust_r = $DustParticles
var dust_l

func setup(tier, speed, affect_enemies, hit_damage: = 0.0, hit_stun_strength: = 0.0, hit_stun_duration: = 0.0, max_size: = 800):
	self.tier = tier
	self.speed = speed
	self.affect_enemies = affect_enemies
	self.hit_damage = hit_damage
	self.hit_stun_duration = hit_stun_duration
	self.hit_stun_strength = hit_stun_strength
	self.max_size = max_size

func _ready() -> void :
	$vis.scale = Vector2()
	if affect_enemies:
		$OuterArea / CollisionShape2D.shape = $OuterArea / CollisionShape2D.shape.duplicate()
		$InnerArea / CollisionShape2D.shape = $InnerArea / CollisionShape2D.shape.duplicate()
	else:
		$OuterArea.queue_free()
		$InnerArea.queue_free()

	dust_r.emitting = false
	dust_r.self_modulate = Style.mapColor("#687bc8") * 1.2

	dust_l = dust_r.duplicate()
	self.add_child(dust_l)

func get_ground_interesct_pos():
	var a = progress
	var b = abs(position.y) - 10
	var c = sqrt(a * a - b * b)
	return Vector2(c, -10)

func _physics_process(delta: float) -> void :
	if GameWorld.paused:
		return

	progress += delta * speed

	if progress >= max_size:
		queue_free()
		return

	var size = 2.0 * progress / $vis.texture.get_width()
	$vis.scale = Vector2(size, size)
	var sm = $vis.material as ShaderMaterial
	sm.set_shader_parameter("radius", progress)
	sm.set_shader_parameter("floorHeight", global_position.y)
	sm.set_shader_parameter("strength", 1 - progress / max_size)

	if progress > abs(position.y) - 10:
		if not dust_r.emitting:
			dust_r.restart()
		if not dust_l.emitting:
			dust_l.restart()

		var intersect = get_ground_interesct_pos()
		var dome: Dome = Level.domesByTeamId[teamId]
		var dust_l_intersect = Vector2( - intersect.x, intersect.y)
		dust_r.global_position = intersect + dome.global_position
		dust_l.global_position = dust_l_intersect + dome.global_position

	if affect_enemies:
		$OuterArea / CollisionShape2D.shape.radius = max(1, progress)
		$InnerArea / CollisionShape2D.shape.radius = max(1, progress - 20)
		var monstersToIgnore = $InnerArea.get_overlapping_areas()
		for monster in $OuterArea.get_overlapping_areas():
			if not handledMonsters.has(monster) and not monstersToIgnore.has(monster) and monster.canBeHit():
				handledMonsters.append(monster)
				get_damage_sound().startSound()
				if hit_damage > 0.0:
					hit_monster.emit(monster, "shockwave", hit_damage, 0, true)
				if multiplayer.is_server() and hit_stun_duration > 0.0 and hit_stun_strength > 0.0:
					monster.sustainStun(hit_stun_strength, hit_stun_duration)


func get_damage_sound():
	match tier:
		0:
			return $DealDamageSound
		1:
			return $DealDamageSound1
		_:
			return $DealDamageSound2
