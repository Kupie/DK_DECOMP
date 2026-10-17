extends HTTPRequest

func do(listing, page, pageSize, pattern):
	var p = "&pattern=" + pattern if pattern != "" else ""

	request(
		Backend.APP_BASEURL
		+ "/api/files/" + listing + "?pageSize=" + str(pageSize) + "&offset=" + str(page * pageSize) + p, 
		Backend.header(), 
		HTTPClient.METHOD_GET
	)
