class_name BackwardCompatibilityUtils


static func str_to_var(in_string: String) -> Variant:
	var result = str_to_var(in_string)
	if result == null:
		return in_string
	else:
		return result
