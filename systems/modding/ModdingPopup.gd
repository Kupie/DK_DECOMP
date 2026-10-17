extends CenterContainer

var initialModList: Dictionary
var shouldRestart: bool

func _ready():
	Style.init(self)
	InputSystem.grabFocus( %CancelButton)
	var profile = ModLoaderUserProfile.get_current()
	initialModList = profile.mod_list.duplicate(true)
	updateUi()

func updateUi() -> void :
	populateProfileSelect()
	populateModList()
	updateDeleteProfileButton()
	updateCancelButton()

func populateModList() -> void :
	var ModList = %ModList
	for c in ModList.get_children():
		c.queue_free()

	var profile = ModLoaderUserProfile.get_current()
	var modIds = profile.mod_list.keys()
	modIds.sort_custom(sortModIdByName)
	var allModData = ModLoaderMod.get_mod_data_all()

	for modId in modIds:
		if not allModData.has(modId):
			continue

		var mod: Dictionary = profile.mod_list[modId]
		var modData: ModData = allModData[modId]
		var inst = preload("res://systems/modding/ModEntry.tscn").instantiate()
		ModList.add_child(inst)
		inst.setup(modData, mod.is_active)
		inst.connect_toggle(modToggled.bind(modId))

func sortModIdByName(a: String, b: String):

	var ap = a.split("-")
	if ap.size() > 1:
		a = ap[1]
	var bp = b.split("-")
	if bp.size() > 1:
		b = bp[1]

	return a.casecmp_to(b) < 0

func modToggled(isActive: bool, modId: String):
	if isActive:
		ModLoaderUserProfile.force_enable_mod(modId)
	else:
		ModLoaderUserProfile.disable_mod(modId)
	updateCancelButton()

func populateProfileSelect() -> void :
	var index_current_profile: int

	%ProfilesButton.clear()

	var profiles = ModLoaderUserProfile.get_all_as_array()
	profiles.sort_custom(Callable(self, "sortProfilesByName"))
	for user_profile in profiles:
		var is_current_profile: = true if ModLoaderUserProfile.get_current().name == user_profile.name else false
		%ProfilesButton.add_item(user_profile.name + " " + tr("modding.currentprofile") if is_current_profile else user_profile.name)


		if is_current_profile:
			index_current_profile = %ProfilesButton.get_item_count() - 1


	%ProfilesButton.select(index_current_profile)

func sortProfilesByName(a, b):
	if a.name == "default":
		return true
	if b.name == "default":
		return false
	return int(a.name) < int(b.name)

func _on_NewProfileButton_pressed():
	var profiles = ModLoaderUserProfile.get_all_as_array()
	var n: = 0
	for i in range(1, 11):
		var existsAlready: = false
		for p in profiles:
			if p.name == str(i):
				existsAlready = true
				break
		if not existsAlready:
			n = i
			break

	if n != 0:
		ModLoaderUserProfile.create_profile(str(n))
		ModLoaderUserProfile.set_profile(ModLoaderUserProfile.get_profile(str(n)))


		var profile = ModLoaderUserProfile.get_current()
		var modIds = profile.mod_list.keys()
		var allModData = ModLoaderMod.get_mod_data_all()
		for modId in modIds:
			if not allModData.has(modId):
				continue
			var mod = allModData[modId]
			if mod.load_errors.size() > 0 or mod.load_warnings.size() > 0:
				ModLoaderUserProfile.disable_mod(modId)

		updateUi()

func _on_EraseProfileButton_pressed():
	var profile_to_delete: = ModLoaderStore.current_user_profile
	ModLoaderUserProfile.set_profile(getOtherProfileThanCurrent())
	ModLoaderUserProfile.delete_profile(profile_to_delete)

	updateUi()

func updateDeleteProfileButton():
	%EraseProfileButton.disabled = ModLoaderStore.current_user_profile.name == "default" or getOtherProfileThanCurrent() == null

func getOtherProfileThanCurrent() -> ModUserProfile:
	for p in ModLoaderUserProfile.get_all_as_array():
		if ModLoaderStore.current_user_profile.name != p.name:
			return p
	return null

func _on_ButtonApply_pressed():
	get_tree().quit()

func _on_ProfilesButton_item_selected(index):
	var user_profile: = ModLoaderUserProfile.get_profile( %ProfilesButton.get_item_text(index))
	ModLoaderUserProfile.set_profile(user_profile)
	updateUi()

func _on_OpenWorkshopButton_pressed():
	Platform.openWebPage("https://steamcommunity.com/app/1637320/workshop/")

func updateCancelButton():
	var profile = ModLoaderUserProfile.get_current()
	for m in profile.mod_list:
		if profile.mod_list[m].is_active != initialModList[m].is_active:
			%CancelButton.text = tr("modding.restart")
			shouldRestart = true
			return

	shouldRestart = false
	%CancelButton.text = tr("modding.close")

func _on_CancelButton_pressed():
	if shouldRestart:
		if OS.has_feature("editor"):
			printerr("Manual restart required from editor")
		else:
			OS.set_restart_on_exit(true, OS.get_cmdline_args())
		get_tree().quit()
