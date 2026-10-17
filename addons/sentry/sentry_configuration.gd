extends SentryConfiguration

func _configure(options: SentryOptions) -> void :
	var allowed: = allowCrashReports()
	options.logger_event_mask = SentryOptions.MASK_ERROR
	options.logger_breadcrumb_mask = SentryOptions.MASK_SCRIPT | SentryOptions.MASK_WARNING | SentryOptions.MASK_ERROR
	options.logger_enabled = false
	options.enabled = allowed
	options.release = "dome-keeper-v%s" % Version.VERSION
	options.dist = Version.SHA

func allowCrashReports() -> bool:
	if BuildCustomization.has_feature("disable_allow_online_option"):
		return false


	var save = FileAccess.open(Options.optionsPath, FileAccess.ModeFlags.READ)
	if save == null:

		return false

	var i = save.get_as_text()
	var json_conv = JSON.new()
	json_conv.parse(i)
	var parsed = json_conv.get_data()

	return parsed.get("allowCrashReports", parsed.get("allowOnlineMultiplayer", false))
