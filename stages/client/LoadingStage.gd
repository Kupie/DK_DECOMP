class_name LoadingStage
extends Stage

@export var timeoutTimer: Timer

func beforeStart():
	Style.init(self)

func start() -> void :
	if not Network.is_offline_mode():
		timeoutTimer.wait_time = Network.TIMEOUT if not GameWorld.devMode else Network.TIMEOUT_DEV
		timeoutTimer.timeout.connect(_on_timeout)
		timeoutTimer.start()

func _on_timeout() -> void :
	Network.display_error("TIMED OUT", "multiplayer.error.timeout")
