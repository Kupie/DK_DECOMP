extends PanelContainer

signal received_list
signal received_entry
signal entry_selected

var page: = 0
var pageSize: = 50
var maxPage: = 0
var directory: = ""
var pattern: = ""
var listingEntry: = ""
var listingData: Dictionary

var currentGetUrl

func start(title, directory, pattern: = ""):
	var dir = DirAccess.open("user://")
	dir.make_dir("cache")

	self.directory = directory
	self.pattern = pattern
	listingData = {}
	find_child("ListingLabel").text = title
	find_child("PaginationLabel").text = ""
	find_child("NextListing").disabled = true
	find_child("PreviousListing").disabled = true
	clearListing()
	$GetListing.do(directory, page, pageSize, pattern)
	$GetNumberOfListingEntries.do(directory, pattern)

func entrySelected(n, url):
	listingEntry = n
	currentGetUrl = url
	$GetFile.cancel_request()
	var f = FileAccess.open("user://cache/" + currentGetUrl.substr(currentGetUrl.rfind("/") + 1), FileAccess.ModeFlags.READ)
	if f != null:
		call_deferred("emit_signal", "received_entry", f.get_as_text())
	else:
		$GetFile.do(url)
	f.close()
	emit_signal("entry_selected")

func registerEntries(entries):
	listingData[listingEntry] = entries

func getData(n = listingEntry):
	return listingData.get(n, null)

func _on_NextListing_pressed():
	Audio.sound("gui_select")
	clearListing()
	page += 1
	$GetListing.do(directory, page, pageSize, pattern)

func _on_PreviousListing_pressed():
	Audio.sound("gui_select")
	clearListing()
	page -= 1
	$GetListing.do(directory, page, pageSize, pattern)

func clearListing():
	for c in find_child("ListingContent").get_children():
		find_child("ListingContent").remove_child(c)
		c.queue_free()

func updatePagination():
	find_child("PreviousListing").disabled = page == 0
	find_child("NextListing").disabled = page + 1 >= maxPage
	find_child("PaginationLabel").text = str(page + 1) + " of " + str(maxPage)

func _on_GetNumberOfListingEntries_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		Logger.error(str(response_code), "_on_GetNumberOfListingEntries_request_completed", body.get_string_from_utf8())
		return
	var count = int(body.get_string_from_utf8())
	print("NumberOfListingEntries = " + str(count))
	maxPage = ceil(float(count) / pageSize)
	updatePagination()

func _on_GetListing_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		Logger.error(str(response_code), "_on_GetListing_request_completed", body.get_string_from_utf8())
		return

	var test_json_conv = JSON.new()
	var err: = test_json_conv.parse(body.get_string_from_utf8())
	if err != OK:
		push_error("Failed to parse JSON")
		return

	var data = test_json_conv.data
	print("Received " + str(data.size()) + " ListingEntries.")
	var group = ButtonGroup.new()
	for d in data:
		var b: = Button.new()
		b.set("theme_override_fonts/font", preload("res://gui/fonts/FontSmall.tres"))
		b.focus_mode = Button.FOCUS_NONE

		var n = d["name"].substr(0, d["name"].find("-") + 4)
		n = n.substr(0, n.rfind("_"))
		b.text = n
		b.button_group = group
		b.toggle_mode = true
		b.connect("pressed", Callable(self, "entrySelected").bind(n, d.get("publicUrl")))
		find_child("ListingContent").add_child(b)
		Style.init(b)
	updatePagination()

func displayCachedSessions(sessionFiles: Array):
	var LC = find_child("ListingContent")
	for c in LC.get_children():
		LC.remove_child(c)

	var group = ButtonGroup.new()
	for d in sessionFiles:
		var b: = Button.new()
		b.set("theme_override_fonts/font", preload("res://gui/fonts/FontSmall.tres"))
		var n = d.substr(0, d.find("-"))
		b.text = n
		b.button_group = group
		b.toggle_mode = true
		b.connect("pressed", Callable(self, "showEntry").bind(d))
		LC.add_child(b)
		Style.init(b)

	if LC.get_child_count() > 0:
		LC.get_child(0).button_pressed = true
		LC.get_child(0).emit_signal("pressed")

	find_child("PaginationLabel").text = str(sessionFiles.size()) + " sessions"
	find_child("PreviousListing").visible = false
	find_child("NextListing").visible = false

func showEntry(file):
	var f = FileAccess.open("user://cache/" + file, FileAccess.ModeFlags.READ)
	if f != null:
		call_deferred("emit_signal", "received_entry", f.get_as_text())
	f.close()
	emit_signal("entry_selected")

func _process(delta: float) -> void :
	var LC = find_child("ListingContent")
	var index: = -1
	for c in LC.get_children():
		if c.button_pressed:
			index = c.get_index()
			break

	if index == -1:
		return

	if Input.is_action_just_pressed("ui_up") and index > 0:
		LC.get_child(index - 1).button_pressed = true
		LC.get_child(index - 1).emit_signal("pressed")
		InputSystem.grabFocus(LC.get_child(index - 1))
	if Input.is_action_just_pressed("ui_down") and index < LC.get_child_count() - 1:
		LC.get_child(index + 1).button_pressed = true
		LC.get_child(index + 1).emit_signal("pressed")
		InputSystem.grabFocus(LC.get_child(index + 1))

func _on_GetFile_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		Logger.error(str(response_code), "_on_GetFile_request_completed", body.get_string_from_utf8())
		return
	var f = FileAccess.open("user://cache/" + currentGetUrl.substr(currentGetUrl.rfind("/") + 1), FileAccess.ModeFlags.WRITE)
	if f != null:
		f.store_string(body.get_string_from_utf8())
	else:
		Logger.error("_on_GetFile_request_completed", "WriteFail" + str(FileAccess.get_open_error()))
	f.close()

	emit_signal("received_entry", body.get_string_from_utf8())

func gotListing(d1, d2):
	emit_signal("received_list", d1, d2)
