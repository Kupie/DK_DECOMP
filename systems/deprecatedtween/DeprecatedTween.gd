
class_name DeprecatedTween extends Node

signal tween_all_completed

var playback_speed: float = 1.0: set = set_playback_speed
var objectToTweenMap: Dictionary = {

}
var tweenCounter: int = -1
var idToTweenRef: Dictionary = {

}
var allTweens: Array[int]
var startedAt: int = 0
var predictedEndAt: int = 0
var propertyQueue: Array[PropertyToInterpolate] = []
var methodQueue: Array[MethodToInterpolate] = []
var callbackQueue: Array[CallbackToInterpolate] = []
var processingMode: Tween.TweenProcessMode = Tween.TweenProcessMode.TWEEN_PROCESS_IDLE: set = setProcessingMode


func setProcessingMode(inProcessingMode: Tween.TweenProcessMode) -> void :
	processingMode = inProcessingMode
	for tweenID in allTweens:
		var tweenRef: WeakRef = idToTweenRef[tweenID]
		if tweenRef.get_ref():
			tweenRef.get_ref().set_process_mode(processingMode)

func set_playback_speed(inplayback_speed: float) -> void :
	playback_speed = inplayback_speed
	for tweenID in allTweens:
		var tweenRef: WeakRef = idToTweenRef[tweenID]
		tweenRef.get_ref().set_speed_scale(playback_speed)

func interpolate_property(object: Object, property: NodePath, initial_val: Variant, 
		final_val: Variant, duration: float, trans_type: Tween.TransitionType = Tween.TransitionType.TRANS_LINEAR, 
		ease_type: Tween.EaseType = Tween.EaseType.EASE_IN_OUT, delay: float = 0):


	if typeof(initial_val) == TYPE_INT:
		initial_val = float(initial_val)
	if typeof(final_val) == TYPE_INT:
		final_val = float(final_val)

	var p: PropertyToInterpolate = PropertyToInterpolate.new(object, property, initial_val, final_val, 
		duration, trans_type, ease_type, delay)
	propertyQueue.append(p)

func interpolate_method(object: Object, method: String, initial_val, final_val, duration: float, 
		trans_type: Tween.TransitionType = Tween.TransitionType.TRANS_LINEAR, 
		ease_type: Tween.EaseType = Tween.EaseType.EASE_IN_OUT, delay: float = 0):


	if typeof(initial_val) == TYPE_INT:
		initial_val = float(initial_val)
	if typeof(final_val) == TYPE_INT:
		final_val = float(final_val)

	var m: MethodToInterpolate = MethodToInterpolate.new(object, method, initial_val, final_val, 
		duration, trans_type, ease_type, delay)
	methodQueue.append(m)

func interpolate_callback(object: Object, duration: float, callback: String, arg1: Variant = null, arg2: Variant = null, 
		arg3: Variant = null, arg4: Variant = null, arg5: Variant = null, arg6: Variant = null, arg7: Variant = null, 
		arg8: Variant = null):
	var c: CallbackToInterpolate = CallbackToInterpolate.new(object, duration, callback, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
	callbackQueue.append(c)

func start() -> void :
	startedAt = Time.get_ticks_msec()
	_startProperties()
	_startMethods()
	_startCallbacks()

func _startProperties() -> void :
	for interpolatedProperty: PropertyToInterpolate in propertyQueue:
		if not objectToTweenMap.has(interpolatedProperty.object):
			objectToTweenMap[interpolatedProperty.object] = []

		tweenCounter += 1
		var tween: Tween = create_tween()
		tween.set_process_mode(processingMode)
		idToTweenRef[tweenCounter] = weakref(tween)
		objectToTweenMap[interpolatedProperty.object].append(tweenCounter)
		tween.set_speed_scale(playback_speed)
		tween.finished.connect(_on_tween_finished.bind(interpolatedProperty.object, tweenCounter))
		tween.tween_property(interpolatedProperty.object, interpolatedProperty.property, 
			interpolatedProperty.finalVal, interpolatedProperty.duration).from(interpolatedProperty.initialVal)\
			.set_delay(interpolatedProperty.delay).set_trans(interpolatedProperty.transType)\
			.set_ease(interpolatedProperty.easeType)
		predictedEndAt = max(predictedEndAt, Time.get_ticks_msec() + int((interpolatedProperty.duration + interpolatedProperty.delay) * 1000.0))
		allTweens.append(tweenCounter)
	propertyQueue.clear()

func _startMethods() -> void :
	for interpolatedMethod: MethodToInterpolate in methodQueue:
		if not objectToTweenMap.has(interpolatedMethod.object):
			objectToTweenMap[interpolatedMethod.object] = []
		tweenCounter += 1
		var tween: Tween = create_tween()
		tween.set_process_mode(processingMode)
		idToTweenRef[tweenCounter] = weakref(tween)
		objectToTweenMap[interpolatedMethod.object].append(tweenCounter)
		tween.finished.connect(_on_tween_finished.bind(interpolatedMethod.object, tweenCounter))
		tween.set_speed_scale(playback_speed)
		var callable: Callable = Callable(interpolatedMethod.object, interpolatedMethod.method)
		tween.tween_method(callable, interpolatedMethod.initialVal, interpolatedMethod.finalVal, 
			interpolatedMethod.duration)\
			.set_delay(interpolatedMethod.delay)\
			.set_trans(interpolatedMethod.transType)\
			.set_ease(interpolatedMethod.easeType)
		predictedEndAt = max(predictedEndAt, Time.get_ticks_msec() + int((interpolatedMethod.duration + interpolatedMethod.delay) * 1000.0))
		allTweens.append(tweenCounter)
	methodQueue.clear()

func _startCallbacks() -> void :
	for interpolatedCallback: CallbackToInterpolate in callbackQueue:
		if not objectToTweenMap.has(interpolatedCallback.object):
			objectToTweenMap[interpolatedCallback.object] = []
		tweenCounter += 1
		var tween: Tween = create_tween()
		tween.set_process_mode(processingMode)
		idToTweenRef[tweenCounter] = weakref(tween)
		objectToTweenMap[interpolatedCallback.object].append(tweenCounter)
		tween.finished.connect(_on_tween_finished.bind(interpolatedCallback.object, tweenCounter))
		tween.set_speed_scale(playback_speed)
		var callable: Callable = Callable(interpolatedCallback.object, interpolatedCallback.callback)
		if interpolatedCallback.arg8 != null:
			callable = callable.bind(interpolatedCallback.arg1, interpolatedCallback.arg2, interpolatedCallback.arg3, 
				interpolatedCallback.arg4, interpolatedCallback.arg5, interpolatedCallback.arg6, 
				interpolatedCallback.arg7, interpolatedCallback.arg8)
		elif interpolatedCallback.arg7 != null:
			callable = callable.bind(interpolatedCallback.arg1, interpolatedCallback.arg2, interpolatedCallback.arg3, 
				interpolatedCallback.arg4, interpolatedCallback.arg5, interpolatedCallback.arg6, 
				interpolatedCallback.arg7)
		elif interpolatedCallback.arg6 != null:
			callable = callable.bind(interpolatedCallback.arg1, interpolatedCallback.arg2, interpolatedCallback.arg3, 
				interpolatedCallback.arg4, interpolatedCallback.arg5, interpolatedCallback.arg6)
		elif interpolatedCallback.arg5 != null:
			callable = callable.bind(interpolatedCallback.arg1, interpolatedCallback.arg2, interpolatedCallback.arg3, 
				interpolatedCallback.arg4, interpolatedCallback.arg5)
		elif interpolatedCallback.arg4 != null:
			callable = callable.bind(interpolatedCallback.arg1, interpolatedCallback.arg2, interpolatedCallback.arg3, 
				interpolatedCallback.arg4)
		elif interpolatedCallback.arg3 != null:
			callable = callable.bind(interpolatedCallback.arg1, interpolatedCallback.arg2, interpolatedCallback.arg3)
		elif interpolatedCallback.arg2 != null:
			callable = callable.bind(interpolatedCallback.arg1, interpolatedCallback.arg2)
		elif interpolatedCallback.arg1 != null:
			callable = callable.bind(interpolatedCallback.arg1)
		tween.tween_callback(callable).set_delay(interpolatedCallback.duration)
		predictedEndAt = max(predictedEndAt, Time.get_ticks_msec() + int(interpolatedCallback.duration * 1000.0))
		allTweens.append(tweenCounter)
	callbackQueue.clear()

func _on_tween_finished(object, tweenID: int) -> void :
	assert (idToTweenRef.has(tweenID))
	var tweenRef: WeakRef = idToTweenRef[tweenID]
	assert (tweenRef.get_ref())
	tweenRef.get_ref().finished.disconnect(_on_tween_finished)
	if objectToTweenMap.has(object):
		objectToTweenMap[object].erase(tweenID)

	allTweens.erase(tweenID)
	tweenRef.get_ref().kill()
	if allTweens.is_empty():
		tween_all_completed.emit()
	idToTweenRef.erase(tweenID)

func stop(object: Object, key: String = "") -> void :
	assert (key.is_empty(), "key argument not supported for now, let's see if there is need to support it")
	if not objectToTweenMap.has(object):
		return

	var tweensIDs: Array = objectToTweenMap[object]
	for tweenID in tweensIDs:
		var tweenRef: WeakRef = idToTweenRef[tweenID]
		tweenRef.get_ref().pause()

func stop_all() -> void :
	for tweenID in allTweens:
		var tweenRef: WeakRef = idToTweenRef[tweenID]
		tweenRef.get_ref().pause()

func resume_all():
	for tweenID in allTweens:
		var tweenRef: WeakRef = idToTweenRef[tweenID]
		tweenRef.get_ref().play()

func remove_all() -> void :
	for tweenID in allTweens:
		var tweenRef: WeakRef = idToTweenRef[tweenID]
		tweenRef.get_ref().finished.disconnect(_on_tween_finished)
		tweenRef.get_ref().kill()
	allTweens.clear()
	idToTweenRef.clear()
	objectToTweenMap.clear()

func tell() -> float:
	var durationMsec: int = Time.get_ticks_msec() - startedAt
	var durationSec: float = float(durationMsec) / 1000.0
	return durationSec * Engine.time_scale


func get_runtime() -> float:
	var timeLeft: int = predictedEndAt - Time.get_ticks_msec()
	return max(float(timeLeft) / 1000.0, 0.0)

func is_active() -> bool:
	return not allTweens.is_empty()

class PropertyToInterpolate extends RefCounted:
	var object: Object
	var property: NodePath
	var initialVal: Variant
	var finalVal: Variant
	var duration: float
	var transType: Tween.TransitionType
	var easeType: Tween.EaseType
	var delay: float = 0

	func _init(inObject: Object, inProperty: NodePath, inInitialVal: Variant, 
			inFinalVal: Variant, inDuration: float, inTransType: Tween.TransitionType, 
			inEaseType: Tween.EaseType, inDelay: float):
		object = inObject
		property = inProperty
		initialVal = inInitialVal
		finalVal = inFinalVal
		duration = inDuration
		transType = inTransType
		easeType = inEaseType
		delay = inDelay

class MethodToInterpolate extends RefCounted:
	var object: Object
	var method: String
	var initialVal: Variant
	var finalVal: Variant
	var duration: float
	var transType: Tween.TransitionType
	var easeType: Tween.EaseType
	var delay: float = 0
	func _init(inObject: Object, inMethod: String, inInitialVal, inFinalVal, inDuration: float, 
			inTransType: Tween.TransitionType, inEaseType: Tween.EaseType, inDelay: float = 0):
		object = inObject
		method = inMethod
		initialVal = inInitialVal
		finalVal = inFinalVal
		duration = inDuration
		transType = inTransType
		easeType = inEaseType
		delay = inDelay

class CallbackToInterpolate extends RefCounted:
	var object: Object
	var duration: float
	var callback: String
	var arg1: Variant
	var arg2: Variant
	var arg3: Variant
	var arg4: Variant
	var arg5: Variant
	var arg6: Variant
	var arg7: Variant
	var arg8: Variant
	func _init(inObject: Object, inDuration: float, inCallback: String, inArg1: Variant = null, inArg2: Variant = null, 
			inArg3: Variant = null, inArg4: Variant = null, inArg5: Variant = null, inArg6: Variant = null, inArg7: Variant = null, 
			inArg8: Variant = null):
		object = inObject
		duration = inDuration
		callback = inCallback
		arg1 = inArg1
		arg2 = inArg2
		arg3 = inArg3
		arg4 = inArg4
		arg5 = inArg5
		arg6 = inArg6
		arg7 = inArg7
		arg8 = inArg8
