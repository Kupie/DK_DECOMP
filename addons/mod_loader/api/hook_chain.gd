class_name ModLoaderHookChain
extends RefCounted






var reference_object: Object

var _callbacks: Array[Callable] = []
var _callback_index: = -1


const LOG_NAME: = "ModLoaderHookChain"




func _init(reference_object: Object, callbacks: Array) -> void :
	self.reference_object = reference_object
	_callbacks.assign(callbacks)
	_callback_index = callbacks.size()











func execute_next(args: = []) -> Variant:
	var callback: = _get_next_callback()
	if not callback:
		return


	if _is_callback_vanilla():
		return callback.callv(args)

	return callback.callv([self] + args)












func execute_next_async(args: = []) -> Variant:
	var callback: = _get_next_callback()
	if not callback:
		return


	if _is_callback_vanilla():
		return await callback.callv(args)

	return await callback.callv([self] + args)


func _get_next_callback() -> Variant:
	_callback_index -= 1
	if not _callback_index >= 0:
		ModLoaderLog.fatal(
			"The hook chain index should never be negative. " + 
			"A mod hook has called execute_next twice or ModLoaderHookChain was modified in an unsupported way.", 
			LOG_NAME
		)
		return

	return _callbacks[_callback_index]


func _is_callback_vanilla() -> bool:
	return _callback_index == 0
