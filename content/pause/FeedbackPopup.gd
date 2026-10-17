extends CenterContainer

signal quit

func init():
	find_child("SuccessPopup").visible = false
	find_child("LoadingSpinner").visible = false
	find_child("ErrorLabel").visible = false
	find_child("PanelContainer").visible = true
	InputSystem.grabFocus(find_child("Content"))

func _on_SubmitButton_pressed():
	find_child("SubmitButton").visible = false
	find_child("LoadingSpinner").visible = true
	find_child("ErrorLabel").visible = false


















func _on_SubmitFeedback_request_completed(result, response_code, headers, body):
	find_child("SubmitButton").visible = true
	find_child("LoadingSpinner").visible = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		find_child("ErrorLabel").text = "An error occurred (" + str(response_code) + "), the feedback could not be sent."
		find_child("ErrorLabel").visible = true
		return

	find_child("PanelContainer").visible = false
	find_child("SuccessPopup").visible = true
	find_child("Content").text = ""

func _on_ButtonQuit_pressed():
	emit_signal("quit")

func _on_ButtonOkay_pressed() -> void :
	emit_signal("quit")

func _on_CancelButton_pressed() -> void :
	emit_signal("quit")
