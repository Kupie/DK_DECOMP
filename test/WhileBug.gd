extends Node2D


var gadgetChoicesPerArtifact: = 3

func _ready():
	var minBound = 1
	var maxBound = 21
	randomize()
	var mean = (minBound + maxBound) * 0.5
	var offset: = 0.0
	for i in 20:
		var a = Data.stabilizedRandomInt(minBound, maxBound, "aaa", 2)
		offset += a - mean
		print(a)
	prints("off", offset)
