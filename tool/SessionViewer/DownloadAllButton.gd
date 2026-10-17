extends Button

var page: = 0
var pageSize: = 50
var maxPage: = 0
var sessionCount: = 1
var directory: = ""
var pattern: = ""
var listingEntry: = ""
var listingData: Dictionary

var currentGetUrl

func _on_GetNumberOfListingEntries_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		Logger.error(str(response_code), "_on_GetNumberOfListingEntries_request_completed", body.get_string_from_utf8())
		return
	var count = int(body.get_string_from_utf8())
	print("NumberOfListingEntries = " + str(count))
	maxPage = ceil(float(count) / pageSize)

func _on_GetListing_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		Logger.error(str(response_code), "_on_GetListing_request_completed", body.get_string_from_utf8())
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	print("Received " + str(data.size()) + " ListingEntries.")
	for d in data:
		currentGetUrl = d.get("publicUrl")
		var f = FileAccess.open("user://cache/" + currentGetUrl.substr(currentGetUrl.rfind("/") + 1), FileAccess.ModeFlags.READ)
		if f == null:
			$GetFile.do(currentGetUrl)
			await $GetFile.request_completed
		else:
			f.close()

	page += 1
	loadCurrentPage()

func _on_GetFile_request_completed(result, response_code, headers, body):
	print("Session " + str(sessionCount) + " retrieved.")
	sessionCount += 1
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		Logger.error(str(response_code), "_on_GetFile_request_completed", body.get_string_from_utf8())
		return
	var f = FileAccess.open("user://cache/" + currentGetUrl.substr(currentGetUrl.rfind("/") + 1), FileAccess.ModeFlags.WRITE)
	if f != null:
		f.store_string(body.get_string_from_utf8())
	else:
		Logger.error("_on_GetFile_request_completed", "WriteFail" + str(FileAccess.get_open_error()))
	f.close()

func loadCurrentPage():
	if page <= maxPage:
		$GetListing.do("compiled-sessions", page, pageSize, "*.txt")
	else:
		print("finished loading sessions, now grouping")
		groupSessionsByVersion()
		print("grouping done, download all is completed")

func _on_DownloadAllButton_pressed() -> void :
	disabled = true
	$GetNumberOfListingEntries.do("compiled-sessions", "*.txt")
	await $GetNumberOfListingEntries.request_completed
	loadCurrentPage()

func groupSessionsByVersion():
	var filesByVersion: = {}
	var dir = DirAccess.open("user://cache/")
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		if not file.begins_with("."):
			var f = FileAccess.open("user://cache/" + file, FileAccess.ModeFlags.READ)
			var test_json_conv = JSON.new()
			test_json_conv.parse(f.get_as_text())
			var data = test_json_conv.get_data()
			if data.error:
				print("error for " + file)
				print(data.error)
				print(data.error_string + " at line " + str(data.error_line))
				print(f.get_as_text())
				continue
			var runs = Backend.parseRunsFromSession(data.result)
			if runs.size() == 0:
				continue
			var version = runs.front()["meta"].get("version", "unknown")
			var files = filesByVersion.get(version, [])
			files.append(file)
			filesByVersion[version] = files
			f.close()

	var versionsFile = FileAccess.open("user://sessions-by-version.txt", FileAccess.ModeFlags.WRITE)
	versionsFile.store_string(JSON.stringify(filesByVersion))
	versionsFile.close()
