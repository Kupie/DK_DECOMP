extends Stage

func build(data: Array):
	if data.size() > 0:
		$MarginContainer / Label.text = str(data)
	else:
		$MarginContainer / Label.text = "Something went wrong. Check the logs."
	Logger.error($MarginContainer / Label.text)
