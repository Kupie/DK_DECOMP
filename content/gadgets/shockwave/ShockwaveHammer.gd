extends Node2D

const _HAMMERSIZE_TO_OFFSET_READY: Dictionary = {
	0: Vector2(10, -5), 
	1: Vector2(10, -5), 
	2: Vector2(15, -5), 
	3: Vector2(15, -5), 
}
const _HAMMERSIZE_TO_OFFSET_RELOAD: Dictionary = {
	0: Vector2(5, 0), 
	1: Vector2(5, 0), 
	2: Vector2(10, 0), 
	3: Vector2(10, 0), 
}

@export
var crashCurve: Curve

var teamId: String

var active: = false

var in_cooldown: = false
var startPos: = 0.25
var cupolaCurve: Curve2D
var cupolaLength: float

var offset_ready: Vector2 = _HAMMERSIZE_TO_OFFSET_READY[0]
var offset_reloading: Vector2 = _HAMMERSIZE_TO_OFFSET_RELOAD[0]

var tween: Tween

func _ready():
	Style.init(self)
	Data.listen(self, teamId + ".shockwave.hammersize")

	$Sprite1.material.set_shader_parameter("flash_rate", 3.0)
	$Sprite1.material.set_shader_parameter("flash_magnitude", 0.0)
	$Sprite2.material.set_shader_parameter("flash_rate", 3.0)
	$Sprite2.material.set_shader_parameter("flash_magnitude", 0.0)

	add_to_group(teamId + "-dome_ability2")

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".shockwave.hammersize":
		$Sprite1.frame = newValue
		$Sprite2.frame = newValue
		offset_ready = _HAMMERSIZE_TO_OFFSET_READY[newValue]
		offset_reloading = _HAMMERSIZE_TO_OFFSET_RELOAD[newValue]

func init(cupolaPath: Path2D):
	self.cupolaCurve = cupolaPath.curve
	self.cupolaLength = cupolaPath.curve.get_baked_length()

	stop()
	set_pos(startPos, offset_ready)

func start():
	active = true
	$ActivateSound.startSound()

func stop():
	$StopSound.startSound()
	active = false

func executeBattle2() -> bool:
	if in_cooldown:
		$CannotFireSound.startSound()
		return false
	else:
		executeAttack()
		return true

@rpc("reliable")
func remoteExecuteBattle2() -> void :
	executeAttack()

func cooldown_sequence(tw: Tween):
	var max_cooldown = Data.of(teamId + ".shockwave.cooldown")

	tw.tween_method( func(m):
		set_pos(0.5, lerp(offset_ready, offset_reloading, m))
		, 0.0, 1.0, max_cooldown * 0.1).set_delay(max_cooldown * 0.3)

	tw.tween_method( func(m):
		var p = lerp(0.5, startPos, m)
		set_pos(p, offset_reloading)
		, 0.0, 1.0, max_cooldown * 0.3).set_delay(max_cooldown * 0.1)

	tw.tween_method( func(m):
		set_pos(startPos, lerp(offset_reloading, offset_ready, m))
		, 0.0, 1.0, max_cooldown * 0.1).set_delay(max_cooldown * 0.1)

	tw.tween_callback( func():
		in_cooldown = false
		$ReadySound.startSound()
		$Sprite1.material.set_shader_parameter("flash_magnitude", 0.7)
		$Sprite2.material.set_shader_parameter("flash_magnitude", 0.7)
		)

	tw.tween_callback( func():
		$Sprite1.material.set_shader_parameter("flash_magnitude", 0.0)
		$Sprite2.material.set_shader_parameter("flash_magnitude", 0.0)
		).set_delay(0.5)

func get_activate_sound():
	var s = Data.ofOr(teamId + ".shockwave.hammersize", 0)
	match s:
		0: return $ActivateSound
		1: return $Activate1Sound
		_: return $Activate2Sound

func get_fire_sound():
	var s = Data.ofOr(teamId + ".shockwave.hammersize", 0)
	match s:
		0: return $FireSound
		1: return $Fire1Sound
		_: return $Fire2Sound

func executeAttack():
	in_cooldown = true
	var tw = create_tween()
	get_activate_sound().startSound()
	tw.tween_method(set_pos_curve, 0.0, 1.0, 1.0)
	tw.tween_callback( func():
		var centerPos = cupolaCurve.sample_baked(0.5 * cupolaLength) + Vector2(0, -24)
		var dome: Dome = Level.domesByTeamId[teamId]
		var centerPosRelativeToDome: = Vector2(dome.global_position.x + centerPos.x, centerPos.y)

		get_fire_sound().startSound()
		$ImpactFx.position = centerPos + Vector2(0, 8)
		$ImpactFx.play()

		var shockwave = preload("res://content/gadgets/shockwave/Shockwave.tscn").instantiate()
		shockwave.teamId = teamId
		shockwave.position = centerPosRelativeToDome

		shockwave.hit_monster.connect(hit_monster)
		var damage = Data.of(teamId + ".shockwave.damage")
		damage += damage * Data.ofOr(teamId + ".shockwave.damagemod", 0.0)
		shockwave.setup(Data.ofOr(teamId + ".shockwave.hammersize", 0), 400, true, \
		damage, Data.of(teamId + ".shockwave.stunstrength"), Data.of(teamId + ".shockwave.stunduration"))
		Level.map.add_child(shockwave)
	)

	cooldown_sequence(tw)
	tween = tw

func hit_monster(monster: Monster, source: String, damage: float, stun: float, immediateStun: bool) -> void :
	if not multiplayer.is_server():
		return

	monster.hit(source, damage, stun, immediateStun)

func set_pos_curve(val):
	set_pos(lerp(startPos, 0.5, crashCurve.sample_baked(val)), offset_ready)

func set_pos(val, offset):
	$Sprite1.transform = cupolaCurve.sample_baked_with_rotation((1 - val) * cupolaLength)
	$Sprite2.transform = cupolaCurve.sample_baked_with_rotation(val * cupolaLength)
	$Sprite1.rotate(PI * -0.25)
	$Sprite2.rotate(PI * 0.25)





	$Sprite1.offset = offset
	$Sprite2.offset = Vector2( - offset.x, offset.y)

func getBattleAbilityName() -> String:
	return tr("upgrades.shockwave.abilityname")

func pauseChanged():
	if tween:
		if GameWorld.paused:
			tween.pause()
		else:
			tween.play()
