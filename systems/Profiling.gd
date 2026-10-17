extends Node

var map: = {}

class Entry:
	var timestamp: int
	var elapsed: int
	var counter: int
	pass

func start(id):
	var e = getOrCreate(id)
	e.timestamp = Time.get_ticks_usec()
	e.counter += 1

func stop(id):
	var e = getOrCreate(id)
	e.elapsed += Time.get_ticks_usec() - e.timestamp

func log_info(id):
	var e = getOrCreate(id)
	Logger.info("%s: %s sec - %s calls" % [str(id), str(float(e.elapsed) / 1000000), str(e.counter)])

func stop_and_log(id):
	stop(id)
	log_info(id)

func log_info_all():
	Logger.info("--- ALL PROFILERS ---")
	for x in map:
		log_info(x)
	Logger.info("---------------------")

func getOrCreate(id):
	if map.has(id):
		return map[id]

	var e = Entry.new()
	map[id] = e
	return e
