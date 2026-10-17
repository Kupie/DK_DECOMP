class_name WorldViewport extends SubViewport

const PARALLAX_BACKGROUND_NAME = "ParallaxBackground"

var _team_id: String

func get_viewport_container() -> ViewportContainer:
	var current_parent: Node = get_parent()
	while not current_parent is ViewportContainer:
		current_parent = current_parent.get_parent()
	return current_parent

func add_parallax_background(in_parallax_bg: ParallaxBG, in_team_id: String) -> void :
	_team_id = in_team_id
	var parallax_name: String = _get_parallax_bg_name(in_team_id)
	if has_node(parallax_name):
		var oldParallax = get_node(parallax_name)
		oldParallax.name = "_" + parallax_name
		oldParallax.queue_free()
	in_parallax_bg.name = parallax_name
	add_child(in_parallax_bg)

func _get_parallax_bg_name(in_team: String) -> String:
	return PARALLAX_BACKGROUND_NAME + in_team
