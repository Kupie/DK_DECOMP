extends Node2D
class_name KeeperLight

@export var big_light: Node2D

var keeper: Keeper
var tween: Tween

func _ready() -> void :
	visible = false
	keeper = owner as Keeper

func _physics_process(delta: float) -> void :
	if keeper.killed or (keeper.techId == "keeper1" and keeper.isMovementDummy):
		visible = false
		big_light.light_active = visible
		return

	visible = keeper.position.y > 0
	big_light.light_active = visible
	if not is_instance_valid(tween) or not tween.is_running():
		tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		var s: float = randf_range(1.0, 1.05)
		tween.tween_property(self, "scale", Vector2(s, s), 0.08)

func kill() -> void :
	big_light.light_active = false
