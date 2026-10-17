extends Node2D

@onready var probeMarker = load("res://content/gadgets/probe/ProbeMarker.tscn")

var teamId: String

var tempReveals: = []

func _ready():
	$GPUParticles2D.process_material = $GPUParticles2D.process_material.duplicate()

	$ProbeSound.startSound()

	$GPUParticles2D.emitting = true
	$GPUParticles2D.amount = Data.of(teamId + ".probe.range") * log(Data.of(teamId + ".probe.range")) * 10
	var pm = $GPUParticles2D.process_material as ParticleProcessMaterial
	var start = 5
	var end = (Data.of(teamId + ".probe.range") + 1) * GameWorld.TILE_SIZE
	var probe_time = end / float(Data.of(teamId + ".probe.impulseSpeed"))

	var fade_start = Color(1, 1, 1, 1)
	var fade_end = Color(1, 1, 1, 0)

	$Tween.interpolate_property(pm, "emission_ring_radius", start, end, probe_time, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	$Tween.interpolate_property(pm, "emission_ring_inner_radius", start * 0.5, end * 0.9, probe_time, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	$Tween.interpolate_property($GPUParticles2D, "modulate", fade_start, fade_end, probe_time, Tween.TRANS_QUART, Tween.EASE_IN)


	var center = Level.map.getTileCoord(position)
	var radius = Data.of(teamId + ".probe.range")
	var detectChambers = Data.of(teamId + ".probe.detectchambers")
	var impulseSpeed = Data.of(teamId + ".probe.impulseSpeed")
	var permanentrevealresources = Data.of(teamId + ".probe.permanentrevealresources")
	var permanentrevealrock = Data.of(teamId + ".probe.permanentrevealrock")
	for x in range( - radius, radius + 1):
		for y in range( - radius, radius + 1):
			var coord = Vector2(center) + Vector2(x, y)
			var marker_position = Level.map.getTilePos(coord)
			if position.distance_to(marker_position) > (radius + 0.6) * GameWorld.TILE_SIZE:
				continue

			var t = Level.map.getTileData().get_resource(coord.x, coord.y)
			var isResourceTile = Level.map.isResourceTile(t)
			if Level.map.isCaveTile(coord):
				continue

			if permanentrevealrock or (permanentrevealresources and isResourceTile):
				var distance = position.distance_to(marker_position)
				if distance > 0.0:

					var delay = distance / impulseSpeed

					$Tween.interpolate_callback(Level.map, delay, "revealTile", coord)
					$Tween.interpolate_callback(Level.map, delay, "revealTileVisually", coord)

			var chamberDetected = detectChambers and \
			(t == Data.TILE_GADGET or t == Data.TILE_SUPPLEMENT or t == Data.TILE_RELIC or t == Data.TILE_RELIC_SWITCH)
			if (isResourceTile or chamberDetected) and not Level.map.isRevealed(coord):
				var alreadyMarked: = false
				for m in get_tree().get_nodes_in_group(teamId + "-probe_markers"):
					if m.tileCoord == coord:
						alreadyMarked = true
						m.refresh()
						break
				if not alreadyMarked:
					var marker = probeMarker.instantiate()
					marker.teamId = teamId
					marker.tileCoord = coord
					marker.setupEchoSound(t)
					marker.center = position
					marker.position = marker_position
					Level.map.addTileOverlayEffect(marker)
	$Tween.start()

	Style.init(self)

func _on_Tween_tween_all_completed():
	queue_free()

func pauseChanged():
	if GameWorld.paused:
		$Tween.stop_all()
	else:
		$Tween.resume_all()
