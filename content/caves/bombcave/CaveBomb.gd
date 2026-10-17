class_name CaveBomb
extends Carryable

signal state_updated

var type: = CONST.CAVEBOMB
var activated: = false
var untilExplosion: = 0.0
var maxUntilExplosion: = 0.0
var exploded: = false
var lastVelocity

func _ready():
	super._ready()
	Style.init($CarrySprite)
	Style.init($FocusSprite)
	$Sprite2D.play("normal")

func serialize() -> Dictionary:
	var data = super.serialize()
	data["activated"] = activated
	data["untilExplosion"] = untilExplosion
	data["maxUntilExplosion"] = maxUntilExplosion
	data["exploded"] = exploded
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	activated = data["activated"]
	untilExplosion = data["untilExplosion"]
	maxUntilExplosion = data["maxUntilExplosion"]
	exploded = data["exploded"]
	updateState(true)

func get_bomb_state() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_bool(activated)
	stream.encode_half(untilExplosion)
	stream.encode_half(maxUntilExplosion)
	stream.encode_bool(exploded)
	return stream.data

func set_bomb_state(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	activated = stream.decode_bool()
	untilExplosion = stream.decode_half()
	maxUntilExplosion = stream.decode_half()
	exploded = stream.decode_bool()
	updateState()

func updateState(initial: bool = false) -> void :
	if activated:
		activate()
	else:
		deactivate()

	if exploded:
		if initial:
			queue_free()
		else:
			explode()

func canFocusCarry(carrierTeamId: = "") -> bool:
	return not exploded

func onCarried(keeper: Keeper):
	deactivate()

func deactivate():
	activated = false
	untilExplosion = 0.0
	state_updated.emit()
	$Sprite2D.play("normal")
	$ActivateSound.stop()

func activate():
	maxUntilExplosion = 3.0
	untilExplosion = maxUntilExplosion
	activated = true
	state_updated.emit()
	$Sprite2D.play("activated")
	$ActivateSound.startSound()

func onDropped(keeper_or_kunaicarrier):
	activate()

func _physics_process(delta):
	super._physics_process(delta)
	if GameWorld.paused or exploded:
		return

	if multiplayer.is_server():
		server_process(delta)
	else:
		client_process(delta)

func client_process(delta: float) -> void :
	if not activated:
		return

	if untilExplosion > 0.0:
		untilExplosion -= delta
		$Sprite2D.speed_scale = 0.3 + 1.7 * (1.0 - untilExplosion / maxUntilExplosion)
		$CountdownSound.startSound()

func server_process(delta: float) -> void :
	if not activated and not isCarried():
		if linear_velocity.length() > 20:
			activated = true
			state_updated.emit()
			$Sprite2D.play("activated")
			$ActivateSound.startSound()

	if not activated:
		return

	lastVelocity = linear_velocity
	if untilExplosion > 0.0:
		untilExplosion -= delta
		$Sprite2D.speed_scale = 0.3 + 1.7 * (1.0 - untilExplosion / maxUntilExplosion)
		$CountdownSound.startSound()
	else:
		explode()

func explode():
	$ActivateSound.stop()
	if Level.map:
		for dir in CONST.DIRECTIONS:
			if multiplayer.is_server():
				Level.map.damageTileDirection(global_position, dir.normalized(), 30, 10000, teamId, 0.1)
			var ex = load("res://content/caves/bombcave/ExplosionCaveBomb.tscn").instantiate()
			ex.position = position + dir * GameWorld.TILE_SIZE * 0.75
			get_parent().add_child(ex)
			if not exploded:
				ex.playSound()
				exploded = true
	deactivated = true
	state_updated.emit()
	queue_free()
