extends "res://stages/loadout/LoadoutChoice.gd"

func setGadget(id: String, ip):
	if id == "":
		setChoice(tr("loadout.gadget.additional.desc"), "", null)
	else:
		var image = Data.loadIconOrFallback("res://content/icons/" + id + ".png")
		loadoutScale = 2.0
		setChoice(tr("upgrades." + id + ".title"), id, image, null)
		var icon = find_child("Icon")
		icon.remove_from_group("unstyled")
		Style.init(icon)

	if ip:
		ip.close()
