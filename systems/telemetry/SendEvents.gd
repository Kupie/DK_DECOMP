extends HTTPRequest

signal completedSend
signal loginNeeded

var fileCounter: = 1

func do(events):
	var d = []
	for e in events:
		d.append(e.asDict())
	var out = JSON.stringify(d)
	var body = Marshalls.utf8_to_base64(out)
	var headers = ["Content-Type: text/plain"]

	var folder = "/sessions"

	request(
		Backend.BASEURL
			+ "/files/binary" + folder + "/" + Backend.sessionId.uri_encode() + "/events-" + str(fileCounter) + ".txt", 
		headers, 
		HTTPClient.METHOD_PUT, 
		body
	)
	fileCounter += 1

func _on_SendEvents_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var bodyTxt = body.get_string_from_utf8()
		Logger.error(str(response_code), "_on_SendEvents_request_completed", bodyTxt)



		return
	emit_signal("completedSend")
