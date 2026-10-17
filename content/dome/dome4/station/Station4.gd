class_name Station4 extends DomeStation

signal station_hit_top

@onready var tween = $MoveTween
var entered: = false

func _ready():
	super._ready()
	$Sprite2D.play("idle")
	$WaveAlarm.visible = false
	addStationToGroup.call_deferred()

func addStationToGroup() -> void :
	add_to_group.call_deferred(teamId + "-battle-start-stop-listener")

func keeperEnteredStation():
	$Sprite2D.play("on")
	$Usable.updateFocus()
	$WaveAlarm.visible = false
	entered = true

func keeperExitedStation():
	$Sprite2D.play("off")
	$Usable.updateFocus()
	if Data.of(teamId + ".monsters.wavepresent"):
		$WaveAlarm.visible = true
	entered = false

func waveAlertOn():
	$WaveAlarm.visible = true
	$WaveAlarm.frame = 0
	$WaveAlarm.play()

func waveAlertOff():
	$WaveAlarm.visible = false

func _on_sprite_2d_animation_looped() -> void :
	_SpriteAnimationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_SpriteAnimationFinishedCheck()

func _SpriteAnimationFinishedCheck() -> void :
	if $Sprite2D.animation == "off":
		$Sprite2D.play("idle")

func start():
	if not entered:
		return
	var moveTime = (1.0 - $"%PathFollow2D".progress_ratio) * 0.75
	tween.remove_all()
	tween.interpolate_property($"%PathFollow2D", "progress_ratio", $"%PathFollow2D".progress_ratio, 0.999, moveTime, Tween.TRANS_EXPO, Tween.EASE_IN)
	tween.interpolate_callback($Sprite2D / GPUParticles2D, moveTime * 0.2, "set_emitting", true)
	tween.interpolate_callback($Sprite2D / GPUParticles2D, moveTime, "set_emitting", false)
	tween.interpolate_callback(self, moveTime, "stationHitTop")
	tween.start()


func stationHitTop():
	emit_signal("station_hit_top")


func stop():
	var moveTime = $"%PathFollow2D".progress_ratio * 0.75
	$Sprite2D / GPUParticles2D.emitting = true
	tween.remove_all()
	tween.interpolate_property($"%PathFollow2D", "progress_ratio", $"%PathFollow2D".progress_ratio, 0.001, moveTime, Tween.TRANS_EXPO, Tween.EASE_IN)
	tween.interpolate_callback($Sprite2D / GPUParticles2D, moveTime * 0.2, "set_emitting", true)
	tween.interpolate_callback($Sprite2D / GPUParticles2D, moveTime, "set_emitting", false)
	tween.start()

func getVisualGlobalPosition() -> Vector2:
	return $Sprite2D.global_position
