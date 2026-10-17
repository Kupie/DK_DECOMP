extends Node


func setup(mod: ModData, is_active: bool):
	Style.init(self)
	var disabled = mod.load_errors.size() > 0
	%title.text = mod.manifest.name + " - " + mod.manifest.version_number
	%version.text = ", ".join(mod.manifest.compatible_game_version)
	%authors.text = ", ".join(mod.manifest.authors)
	%errors.visible = mod.load_errors.size() > 0
	%errors.text = "Disabled. " + " ".join(mod.load_errors)
	%warnings.visible = not disabled and mod.load_warnings.size() > 0
	%warnings.text = " ".join(mod.load_warnings)
	%description.text = mod.manifest.description
	%is_active.button_pressed = is_active

	var whitelisted = CONST.PRESTIGE_WHITELIST_MOD_IDS.has(mod.manifest.get_mod_id())
	%prestige_icon.visible = whitelisted

	if mod.is_locked or disabled:
		%is_active.hide()
		%is_active.disabled = true
	if not mod.is_loadable:
		%is_active.add_theme_color_override("font_color", Color.FIREBRICK)

func connect_toggle(callable):
	%is_active.toggled.connect(callable)
