extends Node2D

class_name SecondaryWeapon

var teamId: String

var playerControlled: = false
var playerControlledDeviceId: = -1
var move: Vector2
var currentSpeed: = 0.0
var acceleration: = 0.0
var firing: = false

func start():
	pass

func stop():
	pass

func inputs(moveValue: Vector2, fireValue: float, specialValue: float, mouseGlobal: Vector2 = Vector2()):
	firing = fireValue > 0.0
	move = moveValue

func setPlayerControlled(deviceId: int):
	playerControlledDeviceId = deviceId
	playerControlled = true
