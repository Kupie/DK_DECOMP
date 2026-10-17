class_name PackedDrop
extends Drop

enum DropMessage{REQUEST_PACK_DATA, SET_PACK_DATA}
enum CollisionShape{CIRCLE, RECTANGLE, POLYGON}

var dropData: = []
var dropsAdded: = false

func _ready() -> void :
	super._ready()
	if not multiplayer.is_server():
		sendRequestPackDataMessage()

func serialize() -> Dictionary:
	var data = super.serialize()




	var serializedDrops: = []
	for drop in dropData:
		var sDrop: = [drop[0], var_to_str(drop[1])]

		for i in range(2, drop.size()):
			sDrop.append(var_to_str(drop[i]))
		serializedDrops.append(sDrop)
	data["serializedDrops"] = serializedDrops
	return data

func deserialize(serializedData: Dictionary):
	super.deserialize(serializedData)
	dropData.clear()
	for drop in serializedData["serializedDrops"]:
		var data: = [drop[0], str_to_var(drop[1])]
		for i in range(2, drop.size()):
			var o = str_to_var(drop[i])
			add_child(o)
			data.append(o)
		dropData.append(data)

func addDrops(dropsAndPositions: Dictionary):
	if dropsAndPositions.is_empty():
		return
	dropsAdded = true
	additionalSlowdown = 0.1
	mass = sqrt(dropsAndPositions.size()) * 0.75

	var resourceCount: = 0
	for uid in dropsAndPositions.keys():
		if not Level.drops.has_drop(uid):
			continue
		var drop: Drop = Level.drops.get_drop(uid)
		var dropGlobalPosition: = dropsAndPositions[uid] as Vector2
		if drop.absorbed:
			continue

		var dropPos = dropGlobalPosition - global_position
		var data: = []
		data.append(drop.type)
		data.append(dropPos)
		var s = drop.find_child("Sprite2D")
		var sCopy = s.duplicate()
		sCopy.position = dropPos
		sCopy.name = "%s-%d" % [CONST.RESOURCE_PACKER_SPRITE_NAME, resourceCount]
		add_child(sCopy)
		sCopy.set_meta("dropType", drop.type)
		data.append(sCopy)

		for c in drop.get_children():
			if c is CollisionShape2D:
				var cCopy: = CollisionShape2D.new()
				cCopy.shape = c.shape.duplicate()
				cCopy.position = dropPos
				add_child(cCopy)
				data.append(cCopy)
			elif c is CollisionPolygon2D:
				var cCopy: = CollisionPolygon2D.new()
				cCopy.polygon = c.polygon.duplicate()
				cCopy.position = dropPos
				add_child(cCopy)
				data.append(cCopy)

		dropData.append(data)

		for k in drop.carriedBy:
			k.dropCarry(drop)

		drop.dissolveCarryInfluence()
		drop.remove()
		resourceCount += 1


	var center: = Vector2()
	for data in dropData:
		center += data[1]
	center /= dropData.size()
	for data in dropData:
		for i in range(2, data.size()):
			data[i].position -= center
	position += center


func clientAddDrops(dropPositionAndTextureData: Array) -> void :
	if dropsAdded:
		return
	dropsAdded = true
	additionalSlowdown = 0.1

	var resourceCount: = 0
	for array in dropPositionAndTextureData:
		var data: = []
		var dropType: String = array[0]
		data.append(dropType)
		var dropPos: Vector2 = array[1]
		data.append(dropPos)
		var newSprite = Sprite2D.new()
		Style.init(newSprite)
		var texture = load(array[2])
		newSprite.texture = texture

		newSprite.position = dropPos
		newSprite.scale = array[3]
		newSprite.name = "%s-%d" % [CONST.RESOURCE_PACKER_SPRITE_NAME, resourceCount]
		add_child(newSprite)
		newSprite.set_meta("dropType", dropType)
		data.append(newSprite)

		var collision_array: Array = array[4]
		for shapeData in collision_array:
			var type: int = shapeData[0]
			match type:
				CollisionShape.CIRCLE:
					var collisionShape: = CollisionShape2D.new()
					var shape: = CircleShape2D.new()
					shape.radius = shapeData[1]
					collisionShape.shape = shape
					collisionShape.position = dropPos
					add_child(collisionShape)
					data.append(collisionShape)
				CollisionShape.RECTANGLE:
					var collisionShape: = CollisionShape2D.new()
					var shape: = RectangleShape2D.new()
					shape.size = shapeData[1]
					collisionShape.shape = shape
					collisionShape.position = dropPos
					add_child(collisionShape)
					data.append(collisionShape)
				CollisionShape.POLYGON:
					var collisionPolygon: = CollisionPolygon2D.new()
					var polygon: = []
					for i in range(1, shapeData.size()):
						var v = shapeData[i]
						polygon.append(v)
					collisionPolygon.polygon = PackedVector2Array(polygon)
					collisionPolygon.position = dropPos
					add_child(collisionPolygon)
					data.append(collisionPolygon)

		dropData.append(data)
		resourceCount += 1

func pack():
	var tween: = create_tween()
	tween.set_parallel(true)
	tween.finished.connect(updateDropPosition)
	var packscale = Data.of(teamId + ".resourcepacker.packscale")
	for data in dropData:
		for i in range(2, data.size()):
			tween.tween_property(data[i], "position", data[i].position * packscale, 0.3).set_trans(Tween.TRANS_BOUNCE)
			if i == 2:
				tween.tween_property(data[i], "scale", data[2].scale * packscale, 0.3).set_trans(Tween.TRANS_BOUNCE)
			else:
				var c = data[i]
				if c is CollisionShape2D:
					if data[i].shape is CircleShape2D:
						tween.tween_property(data[i].shape, "radius", data[i].shape.radius * packscale, 0.3)
					elif data[i].shape is RectangleShape2D:
						tween.tween_property(data[i].shape, "size", data[i].shape.size * packscale, 0.3)
				elif c is CollisionPolygon2D:
					var points: = []
					for v in c.polygon:
						points.append(v * packscale)
					c.polygon = PackedVector2Array(points)

func updateDropPosition() -> void :
	for data in dropData:
		data[1] = data[2].position

func shred(teamId: String):
	if absorbed:
		return

	var outDuration: = 0.6
	var t = create_tween()
	for c in get_children():
		if c is Sprite2D and c.material:
			t.set_parallel().tween_property(c, "modulate:a", 0, outDuration)


	$Tween.interpolate_callback(self, outDuration + 0.1, "queue_free")

	if not multiplayer.is_server():
		$Tween.start()
		return

	if dropTargetRef:
		dropTargetPosition = dropTargetRef.dropTarget()
		dropTargetRef = null

	absorbed = true
	linear_damp = 13

	for data in dropData:
		if teamId != "":
			$Tween.interpolate_callback(Data, outDuration * 0.6, "changeByInt", teamId + ".inventory." + data[0], 1)
		Data.changeByInt("inventory.floating" + data[0], -1)

	$Tween.start()

	if is_in_group("saveable"):
		remove_from_group("saveable")

func shrink(teamId: String):
	if absorbed:
		return

	if dropTargetRef:
		dropTargetPosition = dropTargetRef.dropTarget()
		dropTargetRef = null

	var outDuration: = 0.6
	$Tween.interpolate_property(self, "scale", Vector2.ONE, Vector2.ZERO, outDuration, Tween.TRANS_CUBIC, Tween.EASE_IN)
	$Tween.interpolate_property(self, "position", position, dropTargetPosition, outDuration - 0.1, Tween.TRANS_CUBIC, Tween.EASE_OUT)

	$Tween.interpolate_callback(self, outDuration, "queue_free")

	setIndependent(true)
	absorbed = true
	linear_damp = 13

	if multiplayer.is_server():
		for data in dropData:
			$Tween.interpolate_callback(Data, outDuration * 0.6, "changeByInt", teamId + ".inventory." + data[0], 1)
			Data.changeByInt("inventory.floating" + data[0], -1)

	$Tween.start()

	if is_in_group("saveable"):
		remove_from_group("saveable")

func sendRequestPackDataMessage() -> void :
	var stream: = PackedByteStream.new()
	stream.encode_u8(DropMessage.REQUEST_PACK_DATA)
	drop_message.emit(1, stream.data)

func sendSetPackDataMessage(peer_id: int) -> void :
	var stream: = PackedByteStream.new()
	stream.encode_u8(DropMessage.SET_PACK_DATA)
	stream.encode_u8(dropData.size())
	for data in dropData:
		stream.encode_var(data[0])
		stream.encode_vector2(data[1])
		var sprite2D: = data[2] as Sprite2D
		stream.encode_var(sprite2D.texture.resource_path)
		stream.encode_vector2(sprite2D.scale)
		stream.encode_u8(data.size() - 3)
		for i in range(3, data.size()):
			var c = data[i]
			if c is CollisionShape2D:
				if c.shape is CircleShape2D:
					stream.encode_u8(CollisionShape.CIRCLE)
					stream.encode_float(c.shape.radius)
				elif c.shape is RectangleShape2D:
					stream.encode_u8(CollisionShape.RECTANGLE)
					stream.encode_vector2(c.shape.size)
			elif c is CollisionPolygon2D:
				stream.encode_u8(CollisionShape.POLYGON)
				stream.encode_u8(c.polygon.size())
				for v in c.polygon:
					stream.encode_vector2(v)
	drop_message.emit(peer_id, stream.data)

func on_drop_message(senderPeerId: int, buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	var message_type: DropMessage = stream.decode_u8() as DropMessage
	match message_type:
		DropMessage.REQUEST_PACK_DATA:
			if not multiplayer.is_server():
				return
			sendSetPackDataMessage(senderPeerId)
		DropMessage.SET_PACK_DATA:
			var dropData: = []
			var dropDataCount: = stream.decode_u8()
			for _i in range(dropDataCount):
				var dropType: String = stream.decode_var()
				var dropPosition: = stream.decode_vector2()
				var dropTextureResourcePath: String = stream.decode_var()
				var dropScale: = stream.decode_vector2()

				var collisionShapeCount: = stream.decode_u8()
				var collisionArray: = []
				for _j in range(collisionShapeCount):
					var type: = stream.decode_u8()
					var collisionData: = []
					collisionData.append(type)
					match type:
						CollisionShape.CIRCLE:
							collisionData.append(stream.decode_float())
						CollisionShape.RECTANGLE:
							collisionData.append(stream.decode_vector2())
						CollisionShape.POLYGON:
							var count: = stream.decode_u8()
							for _k in range(count):
								collisionData.append(stream.decode_vector2())
					collisionArray.append(collisionData)

				dropData.append([dropType, dropPosition, dropTextureResourcePath, dropScale, collisionArray])
			clientAddDrops(dropData)
