class_name RewardChoice
extends "res://stages/loadout/LoadoutChoice.gd"

enum RewardStatus{LOCKED, UNLOCKED, ENABLED}

var status: RewardStatus = RewardStatus.LOCKED
var disable_toggle: bool = false

func _ready() -> void :
	super._ready()
	%CostLabel.text = str(Data.rewards.get(id, {}).get("cost", 0))

func update(availableBagdes: int):
	%CostContainer.visible = status == 0
	selected = status == 2

	if status == 0:
		set_enabled(int(Data.rewards.get(id, {}).get("cost", 0)) <= availableBagdes)
		%CostContainer.set("theme_override_styles/panel", preload("res://gui/buttons/button_disabled.tres"))
	else:
		set_enabled(true)
		%CostContainer.set("theme_override_styles/panel", null)
		if not disable_toggle:
			%CheckIcon.show()
			if selected:
				%CheckIcon.texture = preload("res://gui/buttons/checkbox_checked.png")
			else:
				%CheckIcon.texture = preload("res://gui/buttons/checkbox_normal.png")

func playUnlockAnimation():
	await RenderingServer.frame_post_draw
	$Path2D.curve.set_point_position(1, Vector2(size.x, 0.0))
	$Path2D.curve.set_point_position(2, Vector2(size.x, size.y))
	$Path2D.curve.set_point_position(3, Vector2(0.0, size.y))
	$Glow.points = $Path2D.curve.get_baked_points()
	$Path2D / PathFollow2D / Sparks.emitting = true
	$Glow.show()
	$Panel.show()
	var t: = create_tween()

	t.tween_property($Glow, "modulate:a", 1.0, 0.1)
	t.set_parallel().tween_property($Panel, "modulate:a", 0.3, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)

	t.set_parallel(false).tween_property($Path2D / PathFollow2D, "progress_ratio", 1.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_callback($Path2D / PathFollow2D / Sparks.set_emitting.bind(false))
	t.tween_property($Glow, "modulate:a", 0.0, 2.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t.set_parallel(true).tween_property($Panel, "modulate:a", 0.0, 0.4)
