extends Line2D

const MAT_INACTIVE: = preload("res://content/map/chamber/relicswitch/NewCable/cable_segment_inactive.tres")

@onready var orig_points: = points

var matActive: ShaderMaterial
var isShadow: = false
var cableLength: float = 10.0
var cableTotalLength: float = 10.0
var cableOffset: float = 0.0
var time: = 0.0
var activationPower: = 0.0
var t: Tween


func _ready():
	material = MAT_INACTIVE
	Style.init(self)
	set_process(false)
	cableLength = cableTotalLength * 0.03
	modulate.r = points[-1].direction_to(points[0]).angle() + PI / 2
	if not isShadow:
		if cableOffset > 0:
			modulate.b = cableOffset / 160.0
		else:
			modulate.b = 0.0
		modulate.g = cableTotalLength / 160.0
		$Entry.queue_free()
		$Exit.queue_free()
	else:
		var rotations: Array = [0.0, PI * 0.5, PI, PI * 1.5]
		rotations.shuffle()
		$Entry.rotation = rotations.pop_front()
		$Entry.position = points[0]

		$Exit.rotation = rotations.pop_front()
		$Exit.position = points[-1]
		material = null
		modulate = Color(0, 0, 0, 0.3)
		z_index = 9
		for i in orig_points.size():
			orig_points[i].y += cableTotalLength * 0.3 * sin(remap(i, 0, (orig_points.size() - 1) * 2.0, 0, TAU))
		points = orig_points


func activate(with_tween: = false):
	if not isShadow:
		material = matActive
		modulate.a = 0.1
	if with_tween:
		t = create_tween()
		t.tween_method(setActivationPower, 0.0, 1.0, 1.0)


func deactivate(with_tween: = false):
	if not isShadow:
		modulate.a = 1.0
	t = create_tween()
	if with_tween:
		t.set_parallel().tween_method(setActivationPower, 1.0, 0.0, 1.0)
	t.tween_callback(setInactiveMat).set_delay(1.0)


func setActivationPower(v: float):
	material.set_shader_parameter("activation_power", v)


func setInactiveMat():
	material = MAT_INACTIVE
