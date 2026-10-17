extends Node

var STEAM
var tween: Tween
var browsing_image: bool

func _ready() -> void :
	var facade = PlatformFacadeSteam.new()
	get_tree().root.add_child.call_deferred(facade)
	facade.init()

	STEAM = Engine.get_singleton("Steam")
	%FileDialog.file_selected.connect(onFileSelected)
	Style.init(self)

func onFileSelected(str):
	if browsing_image:
		%PreviewPath.text = str
	else:
		%ModPath.text = str

func upload():
	STEAM.item_created.connect(onFileCreated, Object.CONNECT_ONE_SHOT)
	STEAM.createItem(PlatformFacadeSteam.STEAM_APP_ID, 0)

func onFileCreated(result: int, file_id: int, accept_tos: bool):
	if result != 1:
		set_output("Workshop item could not be created. Result: " + str(result))
		return

	if accept_tos:
		openAggreement()
		set_output("You need to accept the Workshop TOS.")
		return

	set_output("Workshop item created successfully.\n Take note of the generated workshop ID: \n" + str(file_id))
	%ID.text = str(file_id)
	update(true)

func update(first_upload: bool):
	append_output("Uploading workshop item with ID %s..." % %ID.text)
	var update_handle = STEAM.startItemUpdate(PlatformFacadeSteam.STEAM_APP_ID, int( %ID.text))

	if first_upload:
		STEAM.setItemTitle(update_handle, %ModPath.text.get_basename().get_file())

	var preview_path = ProjectSettings.globalize_path( %PreviewPath.text)
	if FileAccess.file_exists(preview_path):
		Steam.setItemPreview(update_handle, preview_path)

	var abs_path = ProjectSettings.globalize_path( %ModPath.text)
	var content = STEAM.setItemContent(update_handle, abs_path)

	STEAM.item_updated.connect(onItemUpdated, Object.CONNECT_ONE_SHOT)
	STEAM.submitItemUpdate(update_handle, "")

	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_loops(1000)
	tween.tween_callback( func():
		var progress = STEAM.getItemUpdateProgress(update_handle)
		if progress["total"] != 0:
			append_output("Progress: %.02f" % (float(progress["processed"]) / progress["total"]))
		).set_delay(1.0)

func append_output(txt):
	set_output( %output.text + "\n" + str(txt))

func set_output(txt):
	%output.text = str(txt)

func openAggreement():
	STEAM.activateGameOverlayToWebPage("https://steamcommunity.com/sharedfiles/workshoplegalagreement")

func onItemUpdated(result: int, needs_to_accept_agreement: bool) -> void :
	if tween:
		tween.kill()
	if needs_to_accept_agreement:
		openAggreement()
		set_output("You need to accept the Workshop TOS.")
		return

	if result == 1:
		append_output("Mod successfully updated.")
	else:
		append_output("Mod update failed. (Result Code %s)" % result)


func _on_upload_pressed() -> void :
	if %ID.text.is_empty():
		set_output("Uploading..")
		upload()
	else:
		set_output("Updating..")
		update(false)

func _on_browse_pressed() -> void :
	browsing_image = false
	%FileDialog.filters = ["*.zip"]
	%FileDialog.show()


func _on_preview_pressed() -> void :
	browsing_image = true
	%FileDialog.clear_filters()
	%FileDialog.show()
