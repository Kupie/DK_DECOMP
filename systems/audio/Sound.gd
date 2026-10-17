class_name Sound extends AudioStreamPlayer
























signal sound_duration_elapsed

const FADE_OUT_TARGET: = -50.0
const TOO_FAR_FRAME_INTERVAL: = 5

@export var showNameOnPlay: = false
@export var randomVolume: = 3.0
@export var randomPitch: = 0.1


@export var maxAudibleDistance: = 600.94
@export var minAudibleDistance: = 0.0
@export var fadeInTime: = 0.0
@export var fadeOutTime: = 0.0
@export var streams: Array[AudioStream]
@export var removeAfterPlaying: = false
@export var loop: = false
@export var doppler: = 0.0


@export var processOnlyOnce: = false

var basePitch: float
var baseVolume: float
var fadeVolume: float = 0
var additionalVolume: float = 0
var additionalPitch: float = 0
var dopplerPitch: float = 0
var initialized: = false
var shouldPlay: = false
var attenuate: = false
var FadeTween: DeprecatedTween
var simulatedPosition: Vector2 = Vector2.INF: set = setSimulatedPosition
var _playbackPositionOnExitAudibleRange: float = 0.0
var _timeOutsideAudibleRange: float = 0.0
var _isTooFar: bool = false
var _startNewSound: bool = false
var _soundDurationEmittedAtFrame: int = 0
var _prohibitStart: bool = false
var _hasBeenProcessedInThisPlay: bool = false: set = _setHasBeenProcesssedInThisPlay
var _nearest2DParent: Node2D = null

func _ready():
	if not initialized:
		baseVolume = volume_db
		basePitch = pitch_scale
		initialized = true
		if is_zero_approx(maxAudibleDistance):

			set_process(false)
			attenuate = false
		else:
			attenuate = true

		if fadeInTime > 0.0 or fadeOutTime > 0.0:
			FadeTween = DeprecatedTween.new()
			add_child(FadeTween)

	if not finished.is_connected(_on_sound_finished):
		finished.connect(_on_sound_finished)
	if autoplay:
		super.stop()
		self.startSound()

	var isVersus: bool = Level.getDomes().size() > 1
	var needToUpdateBus: bool = isVersus and bus == Audio.BUS_WORLD
	if needToUpdateBus:


		_configureVersusModeBuses.call_deferred()

func _setHasBeenProcesssedInThisPlay(in_hasBeenProcessedInThisPlay: bool) -> void :
	_hasBeenProcessedInThisPlay = in_hasBeenProcessedInThisPlay
	var needToProcessDistance: bool = not is_zero_approx(maxAudibleDistance)
	if needToProcessDistance and (processOnlyOnce and _hasBeenProcessedInThisPlay):
		needToProcessDistance = false
	set_process(needToProcessDistance)



func _configureVersusModeBuses() -> void :
	var domes: Array = Level.getDomes()
	var splitPoint: Vector2 = Vector2()
	for dome in domes:
		splitPoint += dome.get_global_position()
	splitPoint = splitPoint / float(domes.size())
	var soundSourcePos: Vector2 = _calculateSoundSourcePos()
	var belongsToSecondTeamWorld: bool = soundSourcePos.x > splitPoint.x
	if belongsToSecondTeamWorld:
		bus = Audio.BUS_WORLD_TEAM2

func prohibitStart() -> void :
	_prohibitStart = true




func play(from_position: float = 0.0) -> void :
	push_warning("deprecated call Sound.play() ", get_path())
	startSound(from_position)

func startSound(from_position: float = 0.0) -> void :
	assert (finished.get_connections().size() <= 1, "'finished' signal should not be used externally, \t\t\tuse 'sound_duration_elapsed' instead"\
	)
	if showNameOnPlay and GameWorld.devMode:
		prints("Sound:", name)
	if _prohibitStart:
		return

	_hasBeenProcessedInThisPlay = false
	var goalVolume = baseVolume + additionalVolume

	updatePitch()


	if randomVolume > 0.0:
		goalVolume += - randomVolume + 2 * randomVolume * randf()


	if streams.size() > 0:
		stream = streams[randi() % streams.size()]

	if is_instance_valid(stream):
		var totalSoundLength: float = stream.get_length() - from_position
		assert (totalSoundLength >= 0.0, "Sound started with position greater then it's length")
		var tween: = create_tween()
		tween.tween_callback(_on_sound_duration_elapsed).set_delay(totalSoundLength)


	if fadeInTime > 0.0 and not shouldPlay:
		FadeTween.stop_all()
		FadeTween.remove_all()
		if attenuate:

			fadeVolume = -50
			FadeTween.interpolate_property(self, "fadeVolume", -50, 0, fadeInTime)
		else:
			volume_db = -50
			FadeTween.interpolate_property(self, "volume_db", -50, goalVolume, fadeInTime)
		FadeTween.start()
	else:
		volume_db = goalVolume
		if attenuate and fadeInTime <= 0.0:
			fadeVolume = 0

	if not attenuate:

		_start(from_position)

	shouldPlay = true
	_isTooFar = false
	_timeOutsideAudibleRange = 0.0
	_startNewSound = true
	for c in get_children():
		if c is AudioStreamPlayer:
			c.startSound()

func _on_sound_duration_elapsed() -> void :
	_emit_sound_duration_elapsed()

func _emit_sound_duration_elapsed() -> void :
	if _soundDurationEmittedAtFrame == Engine.get_process_frames():
		return
	_soundDurationEmittedAtFrame = Engine.get_process_frames()
	sound_duration_elapsed.emit()

func updatePitch():
	var p
	if randomPitch > 0.0:
		p = max(0.1, basePitch + dopplerPitch + additionalPitch + - randomPitch + 2 * randomPitch * randf())
	else:
		p = max(0.1, basePitch + dopplerPitch + additionalPitch)
	if p <= 0.0:
		Logger.error("sound pitch was below 0", "Sound.updatePitch", {"name": name, "path": str(get_path())})
	else:
		pitch_scale = p



func updateVolume() -> float:
	if not (shouldPlay or playing):
		return -1.0

	if attenuate:
		var attenuation = getAttenuation()
		if attenuation >= 1.0:
			volume_db = -80.0
		else:
			volume_db = baseVolume - 30 * (attenuation) + fadeVolume + additionalVolume
		return attenuation
	else:
		volume_db = baseVolume + fadeVolume + additionalVolume
		if randomVolume > 0.0:
			volume_db += - randomVolume + 2 * randomVolume * randf()
		return 0.0


func _process(delta):
	assert (maxAudibleDistance > 0.0)
	if not stream:

		return

	const process_safety_margin_s: float = 1.0
	var has_passed: bool = (_timeOutsideAudibleRange > stream.get_length() + fadeOutTime + process_safety_margin_s) and not _is_looping()
	if has_passed:
		shouldPlay = false
		set_process(false)

	if processOnlyOnce and _hasBeenProcessedInThisPlay:
		set_process(false)
		return

	if not _hasBeenProcessedInThisPlay:
		_hasBeenProcessedInThisPlay = true

	_isTooFar = _isTooFarFromListener()
	if _isTooFar:
		_tooFarUpdate(delta)
		return

	if not shouldPlay:
		_ensureFadeFinalization()
		return

	var attenuation: float = updateVolume()
	var canBeHeard: bool = attenuation >= 0.0
	if not canBeHeard and playing:
		super.stop()
		super.seek(-1)
		_startNewSound = false
		return
	elif canBeHeard and not playing:
		_ensureIsPlaying()

	if _startNewSound:
		_startNewSound = false
		_start()

	if doppler > 0.0:
		_dopplerUpdate(attenuation)

func _tooFarUpdate(in_delta: float) -> void :
	var playbackPosition: float = _playbackPositionOnExitAudibleRange + _timeOutsideAudibleRange
	var hasEnded: bool = playbackPosition > stream.get_length() and not _is_looping()
	if shouldPlay and removeAfterPlaying and hasEnded:
		shouldPlay = false
		_emit_sound_duration_elapsed()
		queue_free()
		return


	super.stop()
	super.seek(-1)
	if not _isTooFar:
		_timeOutsideAudibleRange = 0.0
		_isTooFar = true
		_playbackPositionOnExitAudibleRange = get_playback_position()
	_timeOutsideAudibleRange += in_delta
	_startNewSound = false

func _ensureFadeFinalization() -> void :
	assert ( not shouldPlay, "needed only when hearable and updateVolume() is not called in any other way")
	if not playing:
		return

	var isFading: = fadeOutTime > 0.0
	if isFading:
		updateVolume()
		var fadeEnded: bool = (fadeVolume <= FADE_OUT_TARGET or volume_db <= FADE_OUT_TARGET)
		if fadeEnded:
			playing = false

func _ensureIsPlaying() -> void :
	var playbackPosition: float = _playbackPositionOnExitAudibleRange + _timeOutsideAudibleRange
	var hasEnded: bool = playbackPosition > stream.get_length() and not _is_looping()
	if hasEnded:
		shouldPlay = false
		if removeAfterPlaying:
			_emit_sound_duration_elapsed()
			queue_free()
		return

	playbackPosition = fmod(playbackPosition, stream.get_length())
	if playbackPosition == 0.0:

		_startNewSound = false
	_timeOutsideAudibleRange = 0.0
	_start(playbackPosition)

func _dopplerUpdate(inAttenuation: float) -> void :
	var parent = get_parent()
	var keeperDelta: Vector2 = Vector2(99999, 9999)
	for keeper in Keepers.local.getAll():
		var d = keeper.global_position - parent.global_position
		if d.length() < keeperDelta.length():
			keeperDelta = d
	var dot = parent.linear_velocity.normalized().dot(keeperDelta.normalized())
	dopplerPitch = doppler * dot * (1.0 - inAttenuation)
	updatePitch()

func _is_looping() -> bool:
	return loop or Utils.is_audio_stream_looping(stream)

func _on_sound_finished() -> void :
	if removeAfterPlaying:
		_emit_sound_duration_elapsed()
		queue_free()
		shouldPlay = false
	elif not loop:
		shouldPlay = false
	else:
		updatePitch()

	if loop:
		_hasBeenProcessedInThisPlay = false

func _start(inPosition: float = 0.0) -> void :
	super.play(inPosition)

func _isTooFarFromListener() -> bool:
	if Keepers.local.getCount() == 0:
		return false

	var skipProcessDueToPerformanceOptimization: bool = (Engine.get_process_frames() % TOO_FAR_FRAME_INTERVAL != 0)\
	and _hasBeenProcessedInThisPlay
	if skipProcessDueToPerformanceOptimization:
		return _isTooFar

	var soundSourcePos: Vector2 = _calculateSoundSourcePos()
	if soundSourcePos == Vector2.INF:
		return false

	var localKeepers = Keepers.local.getAll()
	var closestKeeper: Keeper = localKeepers.front()

	if localKeepers.size() > 1:
		var smallest_distance: float = closestKeeper.global_position.distance_to(soundSourcePos)
		for keeper in localKeepers:
			var distance: float = keeper.global_position.distance_to(soundSourcePos)
			if distance < smallest_distance:
				smallest_distance = distance
				closestKeeper = keeper

	var keeper_listener_position: Vector2 = closestKeeper.get_sound_listener_global_position()
	var distance_from_sound_to_closest_keeper: float = keeper_listener_position.distance_to(soundSourcePos)
	return distance_from_sound_to_closest_keeper > maxAudibleDistance

func _calculateSoundSourcePos() -> Vector2:
	if simulatedPosition != Vector2.INF:
		return simulatedPosition
	if not is_instance_valid(_nearest2DParent):
		var nearest2DParent: Node2D = Utils.get_nearest_parent_of_buildin_type(self, "Node2D") as Node2D
		if nearest2DParent == null:
			return Vector2.INF
		else:
			_nearest2DParent = nearest2DParent
	return _nearest2DParent.get_global_position()

func getAttenuation() -> float:
	var pos: Vector2
	if simulatedPosition == Vector2.INF:
		assert (get_parent() is Node2D or get_parent() is AudioStreamPlayer, "please set the maxAudibleDistance for "\
		+ str(get_path()) + " to 0.0, or ensure position can be obtained (from parent or by setSimulatedPosition)")
		var parentNode2D = Utils.get_nearest_parent_of_buildin_type(self, "Node2D")
		pos = parentNode2D.global_position
	else:
		pos = simulatedPosition

	var minDist: float = 99999.0
	for keeper in Keepers.local.getAll():
		var sound_listener_position: Vector2 = keeper.get_sound_listener_global_position()
		minDist = min(minDist, sound_listener_position.distance_to(pos))
	var attenuation = clamp((minDist - minAudibleDistance) / maxAudibleDistance, 0.001, 1.0)
	return attenuation

func stop(noFade: = false):
	if fadeOutTime == 0.0 or noFade:
		super.stop()
		super.seek(-1)

		if removeAfterPlaying:
			_emit_sound_duration_elapsed()
			queue_free()
	else:
		FadeTween.stop_all()
		FadeTween.remove_all()
		if attenuate:
			FadeTween.interpolate_property(self, "fadeVolume", fadeVolume, FADE_OUT_TARGET, fadeOutTime)
		else:
			FadeTween.interpolate_property(self, "volume_db", volume_db, FADE_OUT_TARGET, fadeOutTime)
		FadeTween.interpolate_callback(self, fadeOutTime, "stop", true)
		FadeTween.start()
	shouldPlay = false

	for c in get_children():
		if c is AudioStreamPlayer:
			c.stop()

func playDelayed(delay: float):
	if delay > 0.0:
		var timer = Timer.new()
		timer.wait_time = delay
		add_child(timer)
		timer.start()
		timer.connect("timeout", Callable(self, "startSound"))
		timer.connect("timeout", Callable(timer, "queue_free"))
	else:
		startSound()

func setSimulatedPosition(pos: Vector2):
	simulatedPosition = pos
	for c in get_children():
		if c is AudioStreamPlayer:
			c.setSimulatedPosition(pos)

func setAdditionalPitch(p: float):
	if p == additionalPitch:
		return

	additionalPitch = p
	updatePitch()

func setAdditionalVolume(v: float):
	if v == additionalVolume:
		return

	additionalVolume = v
	updateVolume()
	for c in get_children():
		if c is AudioStreamPlayer:
			c.setAdditionalVolume(v)

func startIfNotPlaying():
	if not shouldPlay:
		self.startSound()

func stopIfPlaying():
	if shouldPlay:
		self.stop()
