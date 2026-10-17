class_name UtilsOS






static func has_startup_argument(inArg: String) -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	for arg in args:
		if arg == inArg:
			return true
	return false



static func ensure_dir_exists(in_absoulte_filepath: String) -> void :
	if not DirAccess.dir_exists_absolute(in_absoulte_filepath):
		var result: Error = DirAccess.make_dir_absolute(in_absoulte_filepath)
		assert (result == Error.OK, "Only absolute paths are supported")
