extends Node

func info(message: String, source: = "", data = null):
	if source:
		print(source + ": " + message + (" Data: " + JSON.stringify(data) if data else ""))
	else:
		print(message + (" Data: " + JSON.stringify(data) if data else ""))

func warn(message: String, source: = "", data = null):
	if source:
		var data_out = JSON.stringify(data) if data else ""
		var msg = source + ": " + message + (" Data: " + data_out)
		print(msg)
	else:
		var data_out = JSON.stringify(data) if data else ""
		var msg = message + (" Data: " + data_out)
		print(msg)

func error(message: String, source: = "", data = null):
	if source:
		var data_out = JSON.stringify(data) if data else ""
		var msg = source + ": " + message + (" Data: " + data_out)
		push_error(msg)
		printerr(msg)
	else:
		var data_out = JSON.stringify(data) if data else ""
		var msg = source + ": " + message + (" Data: " + data_out)
		push_error(msg)
		printerr(msg)
