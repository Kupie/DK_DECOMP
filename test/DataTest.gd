extends Node

func _ready():
	var apply: = time_it(test_apply)
	print("Test Apply: %.2fs" % apply)
	await get_tree().process_frame
	apply = time_it(test_apply)
	print("Test Apply: %.2fs" % apply)
	get_tree().quit()

func test_apply():
	Data.listen(self, "team1.dome.health")

	for i in range(1000000):
		Data.apply("team1.dome.health", i)

	Data.unlisten(self, "team1.dome.health")

func propertyChanged(property: String, oldValue, newValue):
	pass

func time_it(f: Callable) -> float:
	var start: = Time.get_ticks_usec()
	f.call()
	return (Time.get_ticks_usec() - start) / 1000000.0
