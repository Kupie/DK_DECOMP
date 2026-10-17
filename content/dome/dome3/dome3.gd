class_name Dome3 extends Dome

@onready var _flak_gun_particles: FlakGunParticles = $FlakGunParticles
@onready var _weapon_container: Marker2D = $WeaponContainer

func _process(delta: float) -> void :
	super._process(delta)
	if GameWorld.paused:
		return
	_update_flak_visuals()

func _update_flak_visuals() -> void :
	var nmb_of_shell_spawn_points: int = 0
	var shell_spawn_positions: PackedVector2Array = PackedVector2Array()
	var shell_normals: PackedVector2Array = PackedVector2Array()
	var weapons: Array[Node] = _weapon_container.get_children()
	for weapon in weapons:
		if not weapon is Artillery:
			continue
		if not weapon.started:
			continue

		weapon = weapon as Artillery
		var first_gun_barrel_in_use: bool = weapon.isFirstFlakInUse()
		var second_gun_barrel_in_use: bool = weapon.isSecondFlakInUse()
		if first_gun_barrel_in_use:
			nmb_of_shell_spawn_points += 1
			shell_spawn_positions.append(weapon.getFirstBarrelSpawnPosition())
			shell_normals.append(weapon.getFirstFlakNormal())
		if second_gun_barrel_in_use:
			nmb_of_shell_spawn_points += 1
			shell_spawn_positions.append(weapon.getSecondBarrelSpawnPosition())
			shell_normals.append(weapon.getSecondFlakNormal())

	var reload_speed: float = GunBarrel.getMachineGunReloadSpeedForTeam(teamId)
	_flak_gun_particles.update_weapon_particles(reload_speed, nmb_of_shell_spawn_points, 
		shell_spawn_positions, shell_normals)
