class_name LiftOrb
extends CharacterBody2D

enum State{UPWARDS, DOWNWARDS, WAITING_UPWARDS, TRANSITION}
var state: int = State.WAITING_UPWARDS

var teamId: String
var uid: int

var carry: = []
var carryLines: = {}

const maxCarryLineLength: = 50.0
const transitionDuration: = 1.0
@onready var lift = get_parent()

func _ready():
	modulate.a = 0.0
	$Tween.interpolate_property(self, "modulate:a", 0.0, 1.0, 0.5)
	$Tween.start()
	$Sprite2D.play("on")
	$OrbAmb.startSound()

	var count: = get_tree().get_nodes_in_group(teamId + "-lift_orbs").size()
	add_to_group(teamId + "-lift_orbs")
	name = "LiftOrb-%d" % count

	Style.init(self)

func serialize() -> Dictionary:
	var data = {
		"position": position.y, 
		"state": state, 
		"teamId": teamId, 
		"uid": uid
	}
	return data

func deserialize(data: Dictionary):
	teamId = data.get("teamId", "team1")
	uid = int(data.get("uid", randi()))
	position.y = data["position"]
	setState(int(data["state"]))

func setState(s: int) -> void :
	state = s
	if state == State.DOWNWARDS or state == State.TRANSITION:
		state = State.DOWNWARDS
		goDown()
	if state == State.UPWARDS:
		goUp()

func _physics_process(delta):
	var speed = Data.of(teamId + ".lift.speed")
	if GameWorld.paused:
		speed = 0


	updateCarryLines()
	var top = lift.getTopOfLift()
	var bottom = lift.getBottomOfLift()
	var factor = 0.3 + 0.7 * clamp(min(abs(bottom - position.y), abs(top - position.y)) / 24.0, 0.0, 1.0)
	match int(state):
		State.UPWARDS:
			if position.y <= top:
				$SpawnSound.startSound()
				dropAllCarries(false)
				$Tween.interpolate_property(self, "modulate", modulate, Color(0.5, 0.5, 0.5), transitionDuration)
				$Tween.interpolate_property($OrbAmb, "fadeVolume", $OrbAmb.fadeVolume, -12, transitionDuration)
				$Tween.interpolate_callback(self, transitionDuration, "set", "state", State.DOWNWARDS)
				$Tween.start()
				z_index -= 1
				state = State.TRANSITION
				goDown()
			else:
				set_velocity(Vector2(0, - factor * speed))
				move_and_slide()
		State.DOWNWARDS:
			if position.y >= bottom:
				$SpawnSound.startSound()
				$Tween.interpolate_property(self, "modulate", modulate, Color.WHITE, transitionDuration)
				$Tween.interpolate_property($OrbAmb, "fadeVolume", $OrbAmb.fadeVolume, 0, transitionDuration)
				$Tween.interpolate_callback(self, transitionDuration, "set", "state", State.WAITING_UPWARDS)
				$Tween.start()
				state = State.TRANSITION
			else:
				set_velocity(Vector2(0, factor * speed))
				move_and_slide()
				if z_index != -1 and position.y > CONST.DOME_CELLAR_ENTRANCE_Y:
					z_index = -1
					modulate = Color(0.3, 0.3, 0.3, 1.0)
		State.WAITING_UPWARDS:
			var orbs = get_tree().get_nodes_in_group(teamId + "-lift_orbs")
			var idealDistance = (2 * lift.getLength()) / orbs.size()
			var lowestOrb
			var lowestD: = 99999999
			for orb in orbs:
				if orb.state != State.UPWARDS:
					continue
				var d = abs(orb.position.y - position.y)
				if d < lowestD:
					lowestD = d
					lowestOrb = orb
			if not lowestOrb or lowestD >= idealDistance - GameWorld.TILE_SIZE:
				state = State.TRANSITION
				goUp()

func goDown():
	$CarryArea / CollisionShape2D.disabled = true
	$Sprite2D.play("off")
	$Trail.emitting = false

func goUp():
	$CarryArea / CollisionShape2D.disabled = false
	state = State.UPWARDS
	z_index = 12
	$Sprite2D.play("on")
	$Trail.emitting = true

func updateCarryLines():
	var longest = 0
	if multiplayer.is_server():
		for c in carry.duplicate():
			if not is_instance_valid(c):
				lift.network_drop_carry_from_lift_orb(uid, c.UID)
				continue

			if c.independent:
				lift.network_drop_carry_from_lift_orb(uid, c.UID)

			var d = (global_position - c.position).length()
			if d > longest:
				longest = d
			if d > maxCarryLineLength:
				lift.network_drop_carry_from_lift_orb(uid, c.UID)

		var strength: = 0.15
		for c in carry:
			var dist = global_position - c.position


			if dist.length() < 12.0:
				dist *= 0.0
			else:
				dist -= dist.normalized() * 12
			if dist.y < 0:
				dist.y -= 2.0 * pow(1.0 + dist.length() / maxCarryLineLength, 4)

			var factor: = 1.0
			var off = dist.length() - 0.15 * maxCarryLineLength
			if off > 0:
				var fill = abs(off / (0.8 * maxCarryLineLength))
				if randf() < fill:
					factor = 10.0 * fill
			c.apply_central_impulse(dist * strength * factor)
			strength *= 0.6

	var dome: Dome = Level.getDome(teamId)
	if not dome:
		return
	for t in carryLines:
		if not is_instance_valid(t):
			continue
		var line = carryLines[t]
		line.set_point_position(0, Vector2(global_position.x - dome.global_position.x, global_position.y))
		line.set_point_position(1, Vector2(t.position.x - dome.global_position.x, t.position.y))

func attachCarry(body):
	if not is_instance_valid(body):
		return

	body.unfocusCarry(self)
	var po = CarryablePhysicsOverride.new(self)
	po.linear_damp = 2
	po.angular_damp = 2
	po.gravity_scale = 0.1
	body.addPhysicsOverride(po)
	carry.append(body)
	body.setCarriedBy(self)
	body.moveToPhysicsBackLayer()
	var infl = body.getCarryInfluence()
	if infl:
		infl.exitBundle()
	$Pickup.startSound()

	var carryLine = preload("res://content/keeper/Carryline.tscn").instantiate()
	carryLine.add_point(global_position)
	carryLine.add_point(body.position)
	get_parent().add_child(carryLine)
	carryLines[body] = carryLine

	Style.init(carryLine)

	GameWorld.incrementRunStat("lift_carried_drops", teamId)

func dropCarry(body):
	carry.erase(body)
	if is_instance_valid(body):
		body.freeCarry(self)
		$Drop.startSound()


		var brk = Data.CARRYLINE_BREAK.instantiate()
		brk.global_position = global_position
		brk.target = body.global_position
		Level.viewports.addElement(brk)


	carryLines[body].queue_free()
	carryLines.erase(body)

func _dropCarryInternal(carryable: Carryable) -> void :
	dropCarry(carryable)

func dropAllCarries(moveToPhysicsFrontLayer: bool):
	for body in carry.duplicate():
		dropCarry(body)
		if moveToPhysicsFrontLayer:
			body.moveToPhysicsFrontLayer()

func _on_CarryArea_body_entered(body):
	if not multiplayer.is_server():
		return




	if carry.size() < Data.of(teamId + ".lift.capacity")\
	and not body.isCarried()\
	and body.is_in_group("drops")\
	and ( not body.hasCarryInfluence() or not body.getCarryInfluence().isBundled())\
	and body.canFocusCarry():
		lift.network_attach_drop_to_lift_orb(uid, body.UID)
