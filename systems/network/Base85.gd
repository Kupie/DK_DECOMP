class_name Base85
extends RefCounted

const ASCII85_CHARS: String = "!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstu"
const POW85: Array[int] = [85 * 85 * 85 * 85, 85 * 85 * 85, 85 * 85, 85, 1]

static func encode(data: PackedByteArray) -> String:
	var result: String = ""
	var i: int = 0

	while i < data.size():
		var chunk_size: int = mini(4, data.size() - i)
		var value: int = 0

		for j: int in range(chunk_size):
			value = (value << 8) | data[i + j]

		if chunk_size < 4:
			for j: int in range(4 - chunk_size):
				value = value << 8

		var encoded: String = ""
		for j: int in range(5):
			var idx: int = value % 85
			encoded = ASCII85_CHARS[idx] + encoded
			value = value / 85

		if chunk_size < 4:
			encoded = encoded.substr(0, chunk_size + 1)

		result += encoded
		i += 4

	return result

static func decode(encoded: String) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	var i: int = 0

	while i < encoded.length():
		var chunk_size: int = mini(5, encoded.length() - i)
		var value: int = 0

		for j: int in range(chunk_size):
			var character: String = encoded[i + j]
			var idx: int = ASCII85_CHARS.find(character)
			if idx == -1:
				push_error("Invalid base85 character: " + character)
				return PackedByteArray()
			value += idx * POW85[j]

		for j: int in range(5 - chunk_size):
			value += POW85[4 - (j + 1)]

		var bytes_to_extract: int = chunk_size - 1 if chunk_size < 5 else 4
		var bytes: Array[int] = []

		for j: int in range(4):
			bytes.append((value >> (24 - j * 8)) & 255)

		for j: int in range(bytes_to_extract):
			result.append(bytes[j])

		i += chunk_size

	return result
