extends Control

class_name HudElement

signal request_rebuild

@export var element_size: = Vector2()
@export var layoutWeights: = Vector2()
@export var layoutPriority: = 0

var playerId: String
var teamId: String

func _ready():
	Style.init(self)

func init():
	pass
