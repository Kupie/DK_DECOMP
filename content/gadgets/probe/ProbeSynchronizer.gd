extends Synchronizer

@onready var probeMarker = load("res://content/gadgets/probe/ProbeMarker.tscn")

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	for teamId in Level.teams:
		var probes: Array = get_tree().get_nodes_in_group(teamId + "-probe_markers")
		stream.encode_u16(probes.size())
		for probe: ProbeMarker in probes:
			stream.encode_vector2(probe.global_position)
			stream.encode_vector2(probe.tileCoord)
			var remainingTime: float = probe.get_node("Timer").time_left
			stream.encode_float(remainingTime)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	var team_id: = 0
	while (stream.is_not_finished()):
		var probe_count: = stream.decode_u16()
		team_id += 1
		for _i in probe_count:
			var marker = probeMarker.instantiate()
			marker.teamId = Utils.decode_team_id(team_id)
			marker.global_position = stream.decode_vector2()
			marker.tileCoord = stream.decode_vector2()
			var t = Level.map.getTileData().get_resource(marker.tileCoord.x, marker.tileCoord.y)
			marker.setupEchoSound(t)
			Level.map.addTileOverlayEffect(marker)
			marker.startTimer(stream.decode_float())
