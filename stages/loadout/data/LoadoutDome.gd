extends RefCounted

class_name LoadoutDome

var teamId: String
var domeId: String
var primaryGadgetId: String
var petId: String
var additionalGadgets: Array

func serialize() -> Dictionary:
	var data = {
		"teamId": teamId, 
		"domeId": domeId, 
		"primaryGadgetId": primaryGadgetId, 
		"petId": petId, 
		"additionalGadgets": additionalGadgets, 
	}
	return data

func deserialize(d: Dictionary):
	domeId = d.get("domeId", "dome1")
	teamId = d.get("teamId", "team1")
	primaryGadgetId = d.get("primaryGadgetId", "shield")
	petId = d.get("petId", "")
	additionalGadgets = d.get("additionalGadgets", [])

func duplicate():
	var loadout = get_script().new()

	loadout.domeId = domeId
	loadout.teamId = teamId
	loadout.primaryGadgetId = primaryGadgetId
	loadout.petId = petId
	loadout.additionalGadgets = additionalGadgets.duplicate()
	return loadout

func to_bytes() -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_u8(int(teamId.lstrip("team")))
	stream.encode_u8(int(domeId.lstrip("dome")))
	stream.encode_u8(int(petId.lstrip("pet")))
	stream.encode_var(primaryGadgetId)
	stream.encode_var(additionalGadgets)
	return stream.data

static func from_bytes(data: PackedByteArray) -> LoadoutDome:
	var ld = LoadoutDome.new()
	var stream: = PackedByteStream.from_bytes(data)

	ld.teamId = "team%d" % stream.decode_u8()
	ld.domeId = "dome%d" % stream.decode_u8()
	ld.petId = "pet%d" % stream.decode_u8()
	ld.primaryGadgetId = stream.decode_var()
	ld.additionalGadgets = stream.decode_var()

	return ld
