extends HTTPRequest

func do(url):
	request(url, 
		Backend.header(), 
		HTTPClient.METHOD_GET
	)
