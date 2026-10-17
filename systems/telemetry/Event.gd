extends RefCounted

class_name Event

var id: int
var timestamp: int
var runTime: float
var type: String
var data

func json() -> String:
	return JSON.stringify(asDict())

func asDict() -> Dictionary:
	var d = {"id": id, "time": timestamp, "runTime": runTime, "type": type}
	if data and ( not data is String or "" != data):
		d["data"] = data
	return d
