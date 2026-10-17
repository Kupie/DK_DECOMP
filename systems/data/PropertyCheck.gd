extends RefCounted

class_name PropertyCheck

var property_key: String
var expected_value
var comparison: Callable

func _init(line: String = ""):
	if line != "":
		for comparison_key in CONST.COMPARISONS:
			if line.find(comparison_key) != -1:
				var splits = line.split(comparison_key)
				property_key = splits[0]
				property_key = property_key.to_lower().strip_edges()
				expected_value = str_to_var(splits[1])
				if expected_value == null:
					expected_value = splits[1].strip_edges()
				comparison = CONST.COMPARISONS[comparison_key]
	else:
		Logger.error("line is not a valid property change", "PropertyChange.init", {"line": line})

func fulfilled(data: Dictionary, prefix: = "") -> bool:
	if prefix != "":
		prefix += "."
	return data.has(prefix + property_key) and comparison.call(data.get(prefix + property_key), expected_value)
