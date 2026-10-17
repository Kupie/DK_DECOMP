extends HTTPRequest

func do(listing, pattern):
	var p = "&pattern=" + pattern if pattern != "" else ""

	request(
		Backend.APP_BASEURL
		+ "/api/files/" + listing + "?action=count" + p, 
		Backend.header(), 
		HTTPClient.METHOD_GET
	)
