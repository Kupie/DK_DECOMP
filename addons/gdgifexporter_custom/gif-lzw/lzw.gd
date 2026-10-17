extends RefCounted

var lsbbitpacker: = preload("./lsbbitpacker.gd")
var lsbbitunpacker: = preload("./lsbbitunpacker.gd")

var run_c_converter: = false

class CodeTable:
	var counter: int = 0
	var lookup: Dictionary = {}

	func add(entry) -> int:
		self.lookup[entry] = self.counter
		counter += 1
		return counter

	func find(entry) -> int:
		return self.lookup.get(entry, -1)

	func has(entry) -> bool:
		return self.find(entry) != -1

func log2(value: float) -> float:
	return log(value) / log(2.0)

func get_bits_number_for(value: int) -> int:
	if value == 0:
		return 1
	return int(ceili(log2(value + 1)))


func initialize_color_code_table(colors: PackedByteArray) -> CodeTable:
	var result_code_table: CodeTable = CodeTable.new()
	for color_id in colors:

		result_code_table.add(([color_id]))

	var last_color_index: int = colors.size() - 1
	var clear_code_index: int = pow(2, get_bits_number_for(last_color_index))
	result_code_table.counter = clear_code_index + 2
	return result_code_table





func print_state(index_stream, data_index, k, index_buffer, code_table: CodeTable, current_code_size, binary_code_stream: ):
	print("GD State")
	prints("Index:", data_index)
	prints("K: ", k)
	print("Buffer:", index_buffer)
	prints("Stream slice:", index_stream.slice(data_index, data_index + 10))
	prints("Size:", current_code_size)
	prints("Table:", code_table.counter, code_table.lookup.size())
	prints("Out:", binary_code_stream.chunks.size(), binary_code_stream.bit_index, binary_code_stream.stream)
	prints("Out Slice:", binary_code_stream.chunks.slice(binary_code_stream.chunks.size() - 10))


func compress_lzw(image: PackedByteArray, colors: PackedByteArray) -> Dictionary:
	if run_c_converter and (OS.has_feature("windows")):
		var inst = ClassDB.instantiate("FastLZWCompressor")
		var res = Callable(inst, "compress").call(image, colors)
		inst.free()
		return res


	var code_table: CodeTable = initialize_color_code_table(colors)






	var last_color_index: int = colors.size() - 1
	var clear_code_index: int = pow(2, get_bits_number_for(last_color_index))
	var index_stream: PackedByteArray = image
	var current_code_size: int = get_bits_number_for(clear_code_index)
	var binary_code_stream: = lsbbitpacker.LSBLZWBitPacker.new()


	binary_code_stream.write_bits(clear_code_index, current_code_size)


	var index_buffer: = ([index_stream[0]])
	var data_index: int = 1

	while data_index < index_stream.size():

		var k: = ([index_stream[data_index]])
		data_index += 1

		var new_index_buffer: = index_buffer + (k)
		if code_table.has(new_index_buffer):

			index_buffer = new_index_buffer
		else:

			binary_code_stream.write_bits(code_table.find(index_buffer), current_code_size)



			var last_entry_index: int = code_table.counter - 1
			if last_entry_index != 4095:


				code_table.add(new_index_buffer)
			else:


				binary_code_stream.write_bits(clear_code_index, current_code_size)
				code_table = initialize_color_code_table(colors)


				current_code_size = get_bits_number_for(clear_code_index)




			var new_code_size_candidate: int = get_bits_number_for(code_table.counter - 1)
			if new_code_size_candidate > current_code_size:
				current_code_size = new_code_size_candidate


			index_buffer = k

	binary_code_stream.write_bits(code_table.find(index_buffer), current_code_size)


	binary_code_stream.write_bits(clear_code_index + 1, current_code_size)

	var min_code_size: int = get_bits_number_for(clear_code_index) - 1

	return {"min_code_size": min_code_size, "stream": binary_code_stream.pack()}
