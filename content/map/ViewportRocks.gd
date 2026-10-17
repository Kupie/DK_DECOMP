extends SubViewport

var _updateRequestedAtRenderFrame: int = -1

func _ready() -> void :
	set_process(false)









func ensureUpdatedAtLeastOnce() -> void :
	render_target_update_mode = SubViewport.UpdateMode.UPDATE_ALWAYS
	_updateRequestedAtRenderFrame = Engine.get_frames_drawn()
	set_process(true)

func _process(delta: float) -> void :
	var renderedAtLeastOnce = Engine.get_frames_drawn() != _updateRequestedAtRenderFrame
	if render_target_update_mode == SubViewport.UpdateMode.UPDATE_ALWAYS and renderedAtLeastOnce:
		render_target_update_mode = SubViewport.UpdateMode.UPDATE_ONCE
		set_process(false)
