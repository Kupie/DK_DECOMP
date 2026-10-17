class_name ScannerCaveSynchronizer
extends Synchronizer

func _ready() -> void :
	super._ready()

	owner.hit.connect(on_scanner_hit)

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_bool(owner.hasScanner)
	stream.encode_bool(owner.activated)
	stream.encode_u8(owner.grabs)
	stream.encode_bool(true if not is_instance_valid(owner.leftRes) else owner.leftRes.spent)
	stream.encode_bool(true if not is_instance_valid(owner.rightRes) else owner.rightRes.spent)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	owner.hasScanner = stream.decode_bool()
	owner.activated = stream.decode_bool()
	owner.grabs = stream.decode_u8()
	var usedLeft: = stream.decode_bool()
	var usedRight: = stream.decode_bool()

	if owner.hasScanner:
		owner.leftRes.spent = usedLeft
		owner.rightRes.spent = usedRight
		owner.get_node("Background/Left/Resource").visible = usedLeft
		owner.get_node("Background/Right/Resource").visible = usedRight
		if usedLeft:
			owner.get_node("Background/Left").play("idle")
		if usedRight:
			owner.get_node("Background/Right").play("idle")

		if owner.grabs == 2 or (usedLeft and usedRight):
			owner.get_node("Background/Scanner/Spitze").play("spitze_idle")
			owner.activated = true
		elif owner.grabs == 1:
			owner.get_node("Background/Scanner").play("base_idle")
		if owner.grabs >= 1:
			owner.get_node("%ActiveAmbSound").startSound()
	else:
		owner.get_node("Background").frame = 1
		owner.get_node("Background/Left").queue_free()
		owner.get_node("Background/Right").queue_free()
		owner.get_node("Background/Scanner").queue_free()

func on_scanner_hit(keeper: Keeper) -> void :
	network_rpc(remote_scanner_hit.bind(keeper.playerId), true)

@rpc("reliable", "any_peer")
func remote_scanner_hit(playerId: String) -> void :
	owner.registerHit(playerId)
