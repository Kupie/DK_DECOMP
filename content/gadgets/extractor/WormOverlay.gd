extends Node2D

var teamId: String

var playing: = false
var s: int
var random: RandomNumberGenerator

func _ready() -> void :
	random = RandomNumberGenerator.new()
	random.seed = s

	var speed = Data.of(teamId + ".extractor.wormanimationspeed")
	Style.init(self)
	var children: = get_children()
	var child: = pick_random_child(children)
	children.erase(child)
	child.queue_free()
	var t = create_tween()
	var i = 1
	for c in children:
		c.flip_h = random.randf() > 0.5
		c.modulate.a = 0.0
		c.speed_scale = speed
		t.tween_property(c, "modulate:a", 1.0, 0.15 / speed).set_delay(random.randf_range(0.01, 1.0) / speed)
		c.play("pos" + str(i) + "_idle")
		i += 1

func _on_animated_sprite_animation_finished(i: int) -> void :
	if not playing:
		return

	var node = get_node("AnimatedSprite" + str(i))
	if node.animation.ends_with("idle"):
		return

	var children = get_children()
	children.erase(node)
	var animatedChild = pick_random_child(children)
	animatedChild.play("pos" + str(animatedChild.get_index() + 1) + ("_pass" if random.randf() > 0.5 else "_peek"))

func removeFromTile():
	var speed = Data.of(teamId + ".extractor.wormanimationspeed")
	var t = create_tween()
	for c in get_children():
		t.tween_property(c, "modulate:a", 0.0, 0.15 / speed).set_delay(random.randf_range(0.2, 2.0) / speed)
	t.tween_callback(queue_free)

func play():
	var starter = pick_random_child(get_children())
	starter.play("pos" + str(starter.get_index() + 1) + "_pass")
	playing = true

func stop():
	playing = false

func serialize() -> Dictionary:
	var data = {
	}
	return data

func deserialize(data: Dictionary):
	pass

func to_bytes() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	stream.encode_bool(playing)
	return stream.data

func from_bytes(data: PackedByteArray) -> void :
	var stream: PackedByteStream = PackedByteStream.from_bytes(data)
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	playing = stream.decode_bool()
	s = random.seed

func pick_random_child(children: Array[Node]) -> Node:
	var childIndex: = random.randi_range(0, children.size() - 1)
	return children[childIndex]
