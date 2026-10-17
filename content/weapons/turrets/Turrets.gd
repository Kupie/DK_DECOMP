extends PrimaryWeapon

var WeaponMountingPoints: Node2D

func init(cupulaPath: Path2D):

	WeaponMountingPoints = cupulaPath.get_parent().find_child("WeaponMountingPoints")
	assert (WeaponMountingPoints != null)

	Data.listen(self, teamId + ".turrets.weapon0", true)
	Data.listen(self, teamId + ".turrets.weapon1", true)
	Data.listen(self, teamId + ".turrets.weapon2", true)
	Data.listen(self, teamId + ".turrets.weapon3", true)
	Data.listen(self, teamId + ".turrets.weapon4", true)

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".turrets.weapon0":
		add_turret(0, newValue)
	elif property == teamId + ".turrets.weapon1":
		add_turret(1, newValue)
	elif property == teamId + ".turrets.weapon2":
		add_turret(2, newValue)
	elif property == teamId + ".turrets.weapon3":
		add_turret(3, newValue)
	elif property == teamId + ".turrets.weapon4":
		add_turret(4, newValue)

func add_turret(slot: int, type: String):
	match type:
		"machinegun":
			for left in [true, false]:
				var machinegun = preload("res://content/weapons/turrets/MachineGunTurret.tscn").instantiate()
				var container = WeaponMountingPoints.get_mounting_point(left, slot)
				machinegun.teamId = teamId
				machinegun.left = left
				machinegun.threshold_x = global_position.x + (30 if left else -30)
				machinegun.teamId = teamId
				container.add_child(machinegun)

func start():
	for turret in get_tree().get_nodes_in_group(teamId + "-turrets"):
		turret.start()

func stop():
	for turret in get_tree().get_nodes_in_group(teamId + "-turrets"):
		turret.stop()
