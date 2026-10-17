extends Node

func _ready():
	var completionRates: = {}
	var compFile = FileAccess.open("res://systems/localization/translations/completion_rates.json", FileAccess.ModeFlags.READ)
	if compFile != null:
		var i = compFile.get_as_text()
		var test_json_conv = JSON.new()
		test_json_conv.parse(i)
		var parsed = test_json_conv.get_data()
		if parsed:
			completionRates = parsed
		compFile.close()

	var dir = DirAccess.open("res://systems/localization/translations")
	dir.list_dir_begin()
	var regex = RegEx.new()
	regex.compile("\".*?\"")
	while true:
		var fileName = dir.get_next()
		if fileName == "":
			break
		if not fileName.begins_with(".") and not fileName.ends_with(".import"):
			if fileName.ends_with(".translation"):
				dir.remove("res://systems/localization/translations/" + fileName)
			else:
				var start = fileName.find("_") + 1
				var code = fileName.substr(start, fileName.rfind(".") - start)
				var lines: = []
				var file = FileAccess.open("res://systems/localization/translations/" + fileName, FileAccess.ModeFlags.READ)
				if file != null:
					var line = file.get_line()
					if line.count(",") == 1:
						print("not processing " + fileName + ", seems already processed")
						file.close()
						continue
					print("processing " + fileName)
					while not file.eof_reached():
						line = file.get_line()
						while line.count("\"") < 6 and not file.eof_reached():
							line += "\n" + file.get_line()
						var firstComma = line.find(",")
						var p1 = line.substr(0, firstComma)
						var p2 = line.substr(firstComma + 1)
						p2 = p2.substr(0, p2.find("\",\"") + 1)
						line = p1.replace("\"", "") + "," + p2
						lines.append(line)
				file.close()
				file = FileAccess.open("res://systems/localization/translations/" + fileName, FileAccess.ModeFlags.WRITE_READ)
				if file != null:
					file.store_string("keys," + code + "\n")
					for line in lines:
						file.store_string(line + "\n")
				file.close()

	var lines: = []
	var file = FileAccess.open("res://systems/localization/localization.csv", FileAccess.ModeFlags.READ)
	if file != null:
		while not file.eof_reached():
			var line = file.get_line()
			while line.count("\"") % 2 != 0 and not file.eof_reached():
				line += "\n" + file.get_line()
			var firstComma = line.find(",")
			var p1 = line.substr(0, firstComma)
			var p2 = line.substr(firstComma)
			p2 = p2.substr(0, p2.rfind(","))
			line = p1 + p2
			lines.append(line)
	file.close()
	file = FileAccess.open("res://systems/localization/translations/localization_en_US.csv", FileAccess.ModeFlags.WRITE_READ)
	lines.pop_front()
	if file != null:
		file.store_string("keys,en_US\n")
		for line in lines:
			file.store_string(line + "\n")
	file.close()

	dir.open("res://systems/localization/translations")
	dir.list_dir_begin()
	while true:
		var fileName = dir.get_next()
		if fileName == "":
			break
		if fileName.ends_with(".csv"):
			var start = fileName.find("_") + 1
			var code = fileName.substr(start, fileName.rfind(".") - start)
			file = FileAccess.open("res://systems/localization/translations/" + fileName, FileAccess.ModeFlags.READ)
			if file != null:
				var line = file.get_line()
				var translated: = 0
				var untranslated: = 0
				var lineI: = 0
				while not file.eof_reached() and lineI < lines.size():
					line = file.get_line().replace("\"", "")
					var oldLine = lines[lineI].replace("\"", "")
					if oldLine == "" or oldLine == ",":
						lineI += 1
						continue
					while not file.eof_reached():
						var newKey = line.substr(0, line.find(","))
						var oldKey = oldLine.substr(0, line.find(","))
						if newKey == oldKey or lineI >= lines.size() - 1:
							break
						else:
							line = file.get_line()
					if oldLine.replace("\"", "") == line.replace("\"", ""):
						untranslated += 1
					else:
						translated += 1
					lineI += 1

				completionRates[code] = floor(clamp(100 * (translated / float(untranslated + translated)), 0, 100))

	compFile = FileAccess.open("res://systems/localization/translations/completion_rates.json", FileAccess.ModeFlags.WRITE)
	if compFile != null:
		compFile.store_string(JSON.stringify(completionRates))
		compFile.close()

	get_tree().quit()
