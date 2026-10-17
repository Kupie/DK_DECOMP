extends CameraBase

var tween: DeprecatedTween

var zoomStagePx: float
var playerId: String

func init():
	zoomStagePx = 4
	position = cameraRestPositionInDome
	shake_noise = FastNoiseLite.new()
	shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	zoom = Vector2.ONE * zoomStagePx
	tween = DeprecatedTween.new()
	add_child(tween)

func _process(delta: float) -> void :
	process_shake(delta)

func zoomTo(pixelStage: float):
	if pixelStage == zoomStagePx:
		return
