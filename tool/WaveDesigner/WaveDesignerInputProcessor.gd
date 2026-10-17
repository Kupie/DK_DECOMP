extends InputProcessor

func right_click(event: InputEventMouseButton) -> bool:
	get_parent().right_click()
	return true

func left_click(event: InputEventMouseButton) -> bool:
	get_parent().left_click()
	return true

func left_click_released(event: InputEventMouseButton) -> bool:
	return get_parent().left_click_released(event)
