class_name KeeperInputSettings extends RefCounted

var keeper_id: StringName

var use_mouse: bool
var use_twinstick: bool
var show_aim_indicator: bool
var movement_snap: int
var aim1_snap: int
var aim2_snap: int
var drop_ressources_before_gadets: bool


var rope_snap: int
var rope_camera_follow: float
var auto_pickup: bool
var auto_kunai_carrier_pickup: bool

func to_dict() -> Dictionary:
	var result: = {}
	result["use_mouse"] = use_mouse
	result["use_twinstick"] = use_twinstick
	result["show_aim_indicator"] = show_aim_indicator
	result["movement_snap"] = movement_snap
	result["aim1_snap"] = aim1_snap
	result["aim2_snap"] = aim2_snap
	result["drop_ressources_before_gadets"] = drop_ressources_before_gadets


	result["keeper3_rope_snap"] = rope_snap
	result["keeper3_rope_camera_follow"] = rope_camera_follow
	result["auto_pickup"] = auto_pickup
	result["auto_kunai_carrier_pickup"] = auto_kunai_carrier_pickup

	return result

func from_dict(data, for_mouse: bool, keeper_id: StringName):
	self.keeper_id = keeper_id
	use_mouse = data.get("use_mouse", for_mouse)
	use_twinstick = data.get("use_twinstick", !for_mouse)
	show_aim_indicator = data.get("show_aim_indicator", !for_mouse)
	drop_ressources_before_gadets = data.get("drop_ressources_before_gadets", false)
	var default_snap = 8 if for_mouse else 24
	if keeper_id == "keeper3":
		movement_snap = data.get("movement_snap", 0)
		rope_snap = data.get("keeper3_rope_snap", 0)
		aim1_snap = data.get("aim1_snap", 0)
		aim2_snap = data.get("aim2_snap", default_snap)
		rope_camera_follow = data.get("keeper3_rope_camera_follow", 0.7)
		auto_pickup = data.get("auto_pickup", true)
		auto_kunai_carrier_pickup = data.get("auto_kunai_carrier_pickup", true)
		drop_ressources_before_gadets = data.get("drop_ressources_before_gadets", false)
	else:
		movement_snap = data.get("movement_snap", default_snap)
		aim1_snap = data.get("aim1_snap", default_snap)
		aim2_snap = data.get("aim2_snap", default_snap)
