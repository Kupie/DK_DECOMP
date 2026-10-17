extends Node2D

@export var synchronizer: Synchronizer

var teamId: String

var damageReceived: = 0.0
var remainingStunTime: = 0.0

@onready var sprite_1_mat = $Sprite1.material
@onready var sprite_2_mat = $Sprite2.material

func _ready():
	Data.listen(self, teamId + ".domearmor.pulsedamagethreshold", true)
	Data.listen(self, teamId + ".domearmor.stage", true)

	Style.init(self)

func init(cupulaPath: Path2D):
	var curve: Curve2D = cupulaPath.curve
	var length = curve.get_baked_length()
	var a: = PackedVector2Array()
	var b: = PackedVector2Array()
	for i in 13:
		var pos = curve.sample_baked(length * (i / 12.0))
		a.append(pos)
		b.append(pos)

	for i in range(12, -1, -1):
		var pos: Vector2 = a[i]
		a.append(pos + pos.normalized() * 30.0)
		b.append(pos + pos.normalized() * 6.0)
	$StunArea / CollisionPolygon2D.polygon = a

	var tex = get_texture_by_dome()
	$Sprite1.texture = tex
	$Sprite2.texture = tex

	var offset = get_offset_by_dome()
	$Sprite1.position.y = offset
	$Sprite2.position.y = offset

func updateStage(stage):
	var val = clamp(floor(stage * 0.5), 0, 3)
	$Sprite1.frame = val
	$Sprite2.frame = val + 4



func get_offset_by_dome():
	var dome = Level.domesByTeamId[teamId]
	match dome.techId:
		"dome1":
			return -30
		"dome2":
			return -35
		"dome3":
			return -20
		"dome4":
			return -45
		_:
			return 0

func get_texture_by_dome():
	var dome = Level.domesByTeamId[teamId]
	match dome.techId:
		"dome1":
			return preload("res://content/gadgets/domearmor/domearmor_laser_sheet.png")
		"dome2":
			return preload("res://content/gadgets/domearmor/domearmor_sword_sheet.png")
		"dome3":
			return preload("res://content/gadgets/domearmor/domearmor_arty_sheet.png")
		"dome4":
			return preload("res://content/gadgets/domearmor/domearmor_tesla_sheet.png")
		_:
			return preload("res://content/gadgets/domearmor/domearmor_laser_sheet.png")

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".domearmor.stage":
		updateStage(newValue)
	if property == teamId + ".domearmor.pulsedamagethreshold":
		if newValue > 0.0:
			Data.listen(self, teamId + ".dome.health")
		else:
			Data.unlisten(self, teamId + ".dome.health")
	if property == teamId + ".dome.health":
		if not multiplayer.is_server():
			return

		var diff = oldValue - newValue
		if diff > 0:
			damageReceived += diff
			if damageReceived >= Data.ofOr(teamId + ".domearmor.pulsedamagethreshold", 200):
				damageReceived = -1000
				var monsters = $StunArea.get_overlapping_areas()
				var stunDuration = Data.ofOr(teamId + ".domearmor.pulsestunduration", 4.0)
				for mon in monsters:
					mon.sustainStun(3.0, stunDuration)

				networkPulse()

func networkPulse() -> void :
	synchronizer.network_rpc(pulse, true)

@rpc("reliable")
func pulse() -> void :
	$Tween.interpolate_callback(self, 3.2, "resetDamage")
	$Tween.interpolate_method(self, "zapMonsters", 0, 10, 3.7)
	$Tween.interpolate_method(self, "animate_sprites", 0, 20, 3.7)
	$Tween.interpolate_callback(self, 3.8, "reset_sprites")
	$Tween.start()

func zapMonsters(a):
	var rest = fmod(a, 1.0)
	if rest < 0.1:
		var mons = $StunArea.get_overlapping_areas()
		for shield in get_tree().get_nodes_in_group(teamId + "-dome-shield"):
			shield.zapMonsters(mons, 1, true)

func animate_sprites(a):
	sprite_1_mat.set_shader_parameter("replace_active", int(a) % 2 == 1)
	sprite_2_mat.set_shader_parameter("replace_active", int(a) % 2 == 1)

func reset_sprites():
	sprite_1_mat.set_shader_parameter("replace_active", false)
	sprite_2_mat.set_shader_parameter("replace_active", false)

func resetDamage():
	damageReceived = 0

func pauseChanged():
	if GameWorld.paused:
		$Tween.stop_all()
	else:
		$Tween.resume_all()
