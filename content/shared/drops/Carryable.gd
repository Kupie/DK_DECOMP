extends RigidBody2D

class_name Carryable

const ProximityProxyScn: PackedScene = preload("res://systems/proximiter/proximity_proxy/proximity_proxy.tscn")
const CLIENT_MIN_PHYSICS_SIMULATION_FRAMES = 100

signal drop_event(buffer: PackedByteArray)
signal drop_message(peer_id: int, buffer: PackedByteArray)


@export var additionalSlowdown: = 0.0

@export var carryableType: = ""
@export var canTeleport: = false

var teamId: String: set = setTeam
var lastCarriedPlayerId: String

var carriedBy: = []
var inFocusArea: = []
var focussed: = false
var deactivated: = false
var independent: = false
var isAutoTransported: = false
var UID: = -1

var isLocal: = false

var beingSynced: = true

var forceHide: bool = false

var physicsOverrides: = []
var carryInfluence
@export var carryInfluenceSize: = 1.0


@export var focus_sprite: Sprite2D
@export var carry_sprite: Sprite2D


var sync_transform: Transform2D
var sync_linear_velocity: Vector2
var _translation_on_server: Vector2


var position_buffer: PositionBuffer = PositionBuffer.new()
var _clientFramesInSimulationLeft: int = CLIENT_MIN_PHYSICS_SIMULATION_FRAMES
var _physicsAwakeCounter: int = 0

var teleportDestination

func _ready():
	if not is_instance_valid(physics_material_override):
		physics_material_override = PhysicsMaterial.new()
	var originalPhysics: = CarryablePhysicsOverride.new(self)
	originalPhysics.linear_damp = linear_damp
	originalPhysics.angular_damp = angular_damp
	originalPhysics.gravity_scale = gravity_scale
	originalPhysics.friction = physics_material_override.friction
	physicsOverrides.append(originalPhysics)

	focus_sprite.visible = false
	carry_sprite.visible = false

	add_to_group("carryable")
	add_to_group("pauseL")

	freeze = !is_multiplayer_authority()
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	if not is_multiplayer_authority():


		collision_mask = collision_mask & (1 << 9)



	sync_transform = transform
	sync_linear_velocity = linear_velocity
	var proximity_proxy: ProximityProxy = ProximityProxyScn.instantiate()
	add_child.bind(proximity_proxy, false, InternalMode.INTERNAL_MODE_BACK).call_deferred()
	sleeping_state_changed.connect(_on_sleeping_state_changed)

func _on_sleeping_state_changed() -> void :
	if sleeping:

		sync_linear_velocity = Vector2.ZERO

func setTeam(newTeamId: String) -> void :
	teamId = newTeamId

func teleport(to: Vector2):
	teleportDestination = to

func _integrate_forces(state: PhysicsDirectBodyState2D):
	if is_multiplayer_authority():
		if teleportDestination:
			state.transform.origin = teleportDestination
			teleportDestination = null

		sync_transform = state.transform
		sync_linear_velocity = Vector2.ZERO if state.sleeping else state.linear_velocity

func _physics_process(delta) -> void :
	if is_multiplayer_authority():
		if _physicsAwakeCounter > 0:
			_physicsAwakeCounter -= 1
			sleeping = false
		return

func _clientPhysics(delta: float) -> void :
	if _clientFramesInSimulationLeft < 0:
		if _translation_on_server.distance_squared_to(position) < 0.001:
			return
	position_buffer.update_correction(delta)
	var sample: = position_buffer.sample(position, rotation)
	var sample_transform: = Transform2D(sample.rotation, sample.position)
	var isProcessedBySolver: bool = freeze_mode == RigidBody2D.FREEZE_MODE_KINEMATIC
	var sqrDstToNewTransform: float = transform.origin.distance_squared_to(sample_transform.origin)
	var isAnyMovement: bool = not is_zero_approx(sqrDstToNewTransform)
	var timeSinceLastNetworkUpdate: int = (Time.get_ticks_msec() - position_buffer.last_received_time)
	var is_syncing = timeSinceLastNetworkUpdate < 1000
	if isAnyMovement and is_syncing:
		var was_frozen: bool = freeze_mode != FreezeMode.FREEZE_MODE_KINEMATIC
		_ensureProcessedBySolver()
		transform = sample_transform
		linear_velocity = sample.velocity
		if was_frozen:
			reset_physics_interpolation()

	elif isProcessedBySolver:
		_clientFramesInSimulationLeft -= 1

	if isProcessedBySolver and _clientFramesInSimulationLeft < 0:
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC

	if is_syncing and not visible:
		beingSynced = true
	elif visible and not is_syncing:
		var peerId: = multiplayer.get_unique_id()
		var localKeepers: = Keepers.get_peer(peerId).getAll()
		var visibleToOneKeeper: = false
		for keeper: Keeper in localKeepers:
			if Network.is_point_visible_by_keeper(global_position, keeper):
				visibleToOneKeeper = true
				break
		if not visibleToOneKeeper:
			beingSynced = false

func _ensureProcessedBySolver() -> void :
	_clientFramesInSimulationLeft = CLIENT_MIN_PHYSICS_SIMULATION_FRAMES
	if freeze_mode != RigidBody2D.FREEZE_MODE_KINEMATIC:
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		position_buffer.reset()

func applySyncData(tick: int, in_transform: Transform2D, in_linear_velocity: Vector2, total_drops: int) -> void :
	assert ( not Network.is_server())
	_translation_on_server = in_transform.origin
	position_buffer.expected_tick_gap = float(total_drops) / float(DropSynchronizer.MAX_DROP_SYNCS_PER_PEER_PER_FRAME)
	position_buffer.push_packet(tick, in_transform.origin, in_linear_velocity, in_transform.get_rotation())
	_ensureProcessedBySolver()

func clearSyncBuffer() -> void :
	position_buffer.reset()

var oldVelocity = Vector2()
func pauseChanged():
	if not is_multiplayer_authority():
		return
	if GameWorld.paused and not independent:
		oldVelocity = linear_velocity
		set_axis_velocity(Vector2.ZERO)
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		freeze = true
	else:
		freeze = false
		if not independent:
			set_axis_velocity(oldVelocity)

func serialize() -> Dictionary:
	var data = {}

	data["carriedBy"] = []
	for carrier in carriedBy:
		if carrier and carrier is Keeper:
			data["carriedBy"].append(carrier.playerId)

	data["meta.priority"] = 100
	data["meta.kind"] = "generic"
	data["UID"] = UID
	data["lastCarrierPlayerId"] = lastCarriedPlayerId

	return data

func deserialize(data: Dictionary):
	UID = data["UID"]
	Level.drops.track_drop(self)
	lastCarriedPlayerId = data.get("lastCarrierPlayerId", "")
	for carrierPlayerId in data["carriedBy"]:
		if not Keepers.hasKeeper(carrierPlayerId):
			continue
		var keeper = Keepers.getKeeper(carrierPlayerId)
		if keeper:
			keeper.attachCarry(self)

func setIndependent(b: bool):
	independent = b
	process_mode = Node.PROCESS_MODE_ALWAYS if independent else Node.PROCESS_MODE_INHERIT
	if independent:
		focus_sprite.visible = false

func focusCarry(p):
	inFocusArea.append(p)
	updateFocus()

func unfocusCarry(p):
	inFocusArea.erase(p)
	updateFocus()

func updateFocus():
	if canFocusCarry() and inFocusArea.size() > 0:
		focussed = true
		focus_sprite.visible = true
	else:
		focussed = false
		focus_sprite.visible = false

func isCarried() -> bool:
	return carriedBy.size() > 0

func isCarriedBy(carrier) -> bool:
	return carriedBy.has(carrier)

func canFocusCarry(carrierTeamId: = "") -> bool:
	return not independent

func setCarriedBy(p):
	carry_sprite.visible = true
	carriedBy.append(p)
	if carriedBy.size() == 1:
		onCarried(p)
	if p is Keeper:
		for carrier in carriedBy:
			if carrier != p and carrier is Keeper:

				return
		lastCarriedPlayerId = p.playerId

func freeCarry(p):
	removePhysicsOverride(p)
	carriedBy.erase(p)
	if carriedBy.size() == 0:
		carry_sprite.visible = false
		onDropped(p)

	if p is Keeper:
		if lastCarriedPlayerId == p.playerId:

			for carrier in carriedBy:
				if carrier != p and carrier is Keeper:
					lastCarriedPlayerId = carrier.playerId
					return

func freeByPlayerId(playerId: String):
	for c in carriedBy.duplicate():
		if not is_instance_valid(c):
			carriedBy.erase(c)
		elif c is Keeper:
			if c.playerId == playerId:
				carriedBy.erase(c)

	for f in inFocusArea.duplicate():
		if not is_instance_valid(f):
			inFocusArea.erase(f)
		elif f is Keeper:
			if f.playerId == playerId:
				inFocusArea.erase(f)

	updateFocus()

	for p in physicsOverrides.duplicate():
		if not is_instance_valid(p.creator):
			physicsOverrides.erase(p)
		elif p.creator is Keeper:
			if p.creator.playerId == playerId:
				physicsOverrides.erase(p)

	_updatePhysicsOverrides()
	if carriedBy.size() == 0:
		carry_sprite.visible = false
		onDropped(null)
	else:
		lastCarriedPlayerId = carriedBy.front().playerId


func onCarried(p):
	pass


func onDropped(p):
	pass

func carrierCount() -> int:
	return carriedBy.size()

func getOrCreateCarryInfluence(carrier):
	if carryInfluence == null:
		carryInfluence = load("res://content/shared/drops/CarryInfluence.tscn").instantiate()
		add_child(carryInfluence)
	carryInfluence.carrier = carrier
	return carryInfluence

func dissolveCarryInfluence():
	if carryInfluence:

		carryInfluence.dissolve()

func hasCarryInfluence() -> bool:
	return carryInfluence != null

func getCarryInfluence():
	return carryInfluence

func addPhysicsOverride(physics: CarryablePhysicsOverride):
	physicsOverrides.append(physics)
	_updatePhysicsOverrides()

func removePhysicsOverride(creator):
	for p in physicsOverrides.duplicate():
		if p.creator == creator:
			physicsOverrides.erase(p)
	_updatePhysicsOverrides()

func _updatePhysicsOverrides():
	for p in physicsOverrides:
		p.apply(self)

func ensurePhysicsProcessed() -> void :
	_physicsAwakeCounter = 10
