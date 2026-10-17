extends RefCounted

class_name PropertyChange

var source: String
var key: String
var keyClass: String
var keyName: String
var cumulative: bool = false
var multiplicative: bool = false
var doesRepair: bool = false
var hidden: bool = false
var value

func _init(line: String = ""):
	source = line
	if line != "":
		var splits = line.split("=")
		key = splits[0]
		var isPlusCumulative = key.ends_with("+")
		var isMinusCumulative = key.ends_with("-")
		var isMultiplicative = key.ends_with("*")
		if isPlusCumulative or isMinusCumulative:
			cumulative = true
			key = key.substr(0, key.length() - 1)
		elif isMultiplicative:
			multiplicative = true
			key = key.substr(0, key.length() - 1)

		key = key.to_lower().strip_edges()
		var firstDot: int = key.find(".")
		keyClass = key.substr(0, firstDot)
		keyName = key.substr(firstDot + 1)


		var value_str = splits[1].strip_edges()
		if value_str.begins_with("res://"):
			value = value_str
			hidden = true

		elif value_str.find("/") != -1:
			var valueSplit = value_str.split("/")
			value = BackwardCompatibilityUtils.str_to_var(valueSplit[0])
			if valueSplit[1] == "h":
				hidden = true

		elif value_str.find("[") != -1:
			var cleanedValue = value_str.replace("[", "").replace("]", "").strip_edges()
			value = []
			for v in cleanedValue.split(","):
				value.append(BackwardCompatibilityUtils.str_to_var(v.strip_edges()))
		else:
			value = BackwardCompatibilityUtils.str_to_var(value_str)
		if isMinusCumulative:
			value = - value
		if key.find("dome.baserepair") != -1 or key.find("dome.healthfractionrepair") != -1:
			doesRepair = true

func getChangedValue(oldValue):
	var newVal
	if cumulative:
		newVal = oldValue + value
	elif multiplicative:
		newVal = oldValue * value
	else:
		newVal = value
	return newVal

func apply(prefix: = ""):
	if prefix != "":
		prefix += "."


	if Data.has(key):
		prefix = ""

	if cumulative:
		Data.apply(prefix + key, Data.of(prefix + key) + value)
	elif multiplicative:
		Data.apply(prefix + key, Data.of(prefix + key) * value)
	else:
		Data.apply(prefix + key, value)

func duplicate(generalPrefix: String = "", instancePrefix: String = "") -> PropertyChange:
	var p = get_script().new()
	if keyClass == generalPrefix:
		p.key = instancePrefix + "." + key
	else:
		p.key = key
	p.source = source
	p.keyClass = keyClass
	p.keyName = keyName
	p.cumulative = cumulative
	p.multiplicative = multiplicative
	p.doesRepair = doesRepair
	p.hidden = hidden
	p.value = value
	return p

func instanced(instanceId: String) -> PropertyChange:
	var p = duplicate()
	p.key = instanceId + "." + p.key
	return p
