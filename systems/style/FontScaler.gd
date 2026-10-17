extends Node

const GROUP: = "splitscreen_scalable_font"

signal scale_changed(scale: float)

var current_scale: float = 1.0


var _cachedLabelSettings: Dictionary = {}

func _ready() -> void :
	get_tree().node_added.connect(_on_node_added)
	Options.font_scale_changed.connect(_on_font_scale_changed)
	Keepers.split_screen_changed.connect(_on_split_screen_changed)
	StageManager.stage_started.connect(_on_stage_started)
	_recompute()

func _on_font_scale_changed(_scale: float) -> void :
	_recompute()

func _on_split_screen_changed(_is_split: bool) -> void :
	_recompute()

func _on_stage_started() -> void :
	_recompute()

func _recompute() -> void :
	var target: float = Options.splitscreen_font_scale if (StageManager.isInLevel() and Keepers.isSplitScreen) else 1.0
	set_scale(target)

func set_scale(scale: float) -> void :
	if scale == current_scale:
		return
	current_scale = scale




	for original in _cachedLabelSettings:
		_cachedLabelSettings[original].font_size = int(round(original.font_size * scale))



	for node in get_tree().get_nodes_in_group(GROUP):
		if not _usesLabelSettings(node):
			_applyThemeOverride(node, scale)

	scale_changed.emit(current_scale)

func _on_node_added(node: Node) -> void :
	if not node.is_in_group(GROUP):
		return
	if _usesLabelSettings(node):
		_registerLabelSettings(node)
	else:
		_applyThemeOverride(node, current_scale)

func _usesLabelSettings(node: Node) -> bool:
	return "label_settings" in node and node.label_settings != null

func _registerLabelSettings(node: Node) -> void :
	var settings: LabelSettings = node.label_settings

	if _cachedLabelSettings.has(settings):

		node.label_settings = _cachedLabelSettings[settings]
		return

	if _cachedLabelSettings.values().has(settings):


		return

	var duplicate: LabelSettings = settings.duplicate()
	duplicate.font_size = int(round(settings.font_size * current_scale))
	_cachedLabelSettings[settings] = duplicate
	node.label_settings = duplicate

func _applyThemeOverride(node: Node, scale: float) -> void :
	if not node is Control:
		return
	var font_size_name: = "normal_font_size" if node is RichTextLabel else "font_size"
	if not node.has_meta("fontScalerBaseSize"):
		node.set_meta("fontScalerBaseSize", node.get_theme_font_size(font_size_name))
	var base: int = node.get_meta("fontScalerBaseSize")
	node.add_theme_font_size_override(font_size_name, int(round(base * scale)))
