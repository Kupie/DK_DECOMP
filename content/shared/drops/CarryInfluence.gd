class_name CarryInfluence
extends Node2D

var lastStrength: = 0.0
var strength: = 0.0
var bundle
var cooldown: = 0.0
var beingPulled: = false
var totalDuration: float = 5.0
var carryable: Node = null

var carrier

var particle_fx: GPUParticles2D

func _ready():
	if not Options.reducedParticles:
		particle_fx = preload("res://content/shared/drops/CarryInfluenceParticles.tscn").instantiate()
		add_child(particle_fx)
		particle_fx.emitting = true

	var po = CarryablePhysicsOverride.new(self)
	po.gravity_scale = 0.0
	po.linear_damp = 0.0
	po.angular_damp = 0.0
	po.friction = 0.0
	getCarryable().addPhysicsOverride(po)

func _physics_process(delta):
	carryable = getCarryable()
	if carryable.isAutoTransported and not beingPulled and not (bundle and bundle.startedInCenter()):
		dissolve()
		return

	if carryable.isCarriedBy(carrier) or carryable.independent:
		exitBundle()
		strength = 0
		return

	if strength <= 0.0 or carryable.deactivated:
		dissolve()
		return

	if particle_fx != null:
		particle_fx.global_rotation = 0
		if strength < 3.0 / totalDuration:
			particle_fx.modulate.a = ease(clamp(strength, 0.0, 1.0), 0.5)
			particle_fx.emitting = false
		else:
			particle_fx.modulate.a = clamp(strength, 0.0, 1.0)
			particle_fx.emitting = true

	if bundle:
		if cooldown > 0.0:
			cooldown -= delta
			return

	lastStrength = strength

func applyBundle(bundle):
	self.bundle = bundle
	carryable = getCarryable()
	var po = CarryablePhysicsOverride.new(bundle)
	po.gravity_scale = 0.0
	po.linear_damp = 4.0
	po.angular_damp = 1.0
	carryable.addPhysicsOverride(po)
	totalDuration = max(1.0, strength)

func isBundled() -> bool:
	return bundle != null

func getBundle():
	return bundle

func exitBundle(removeCarryInfluence: = true):
	if bundle:
		carryable = getCarryable()
		carryable.removePhysicsOverride(bundle)
		Utils.wakeUpDrop(carryable)
		if is_instance_valid(bundle):
			bundle.removeCarryInfluence(self)
		bundle = null

func getCarryable():
	return get_parent()

func dissolve():
	exitBundle()
	carryable = getCarryable() as Carryable

	var hasKeeper2Carrier: = false
	for carrier in carryable.carriedBy:
		if not is_instance_valid(carrier):
			continue
		if carrier is Keeper2:
			hasKeeper2Carrier = true
			break

	if hasKeeper2Carrier:
		return
	carryable.remove_child(self)
	carryable.removePhysicsOverride(self)
	carryable.carryInfluence = null
	if particle_fx != null:
		particle_fx.emitting = false
	Utils.wakeUpDrop(carryable, true)
	queue_free()
