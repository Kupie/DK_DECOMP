extends Node

var schnabelTextures: = [
	preload("res://content/weapons/tesla/dome04_cap_level0.png"), 
	preload("res://content/weapons/tesla/dome04_cap_level1.png"), 
	preload("res://content/weapons/tesla/dome04_cap_level2.png"), 
	preload("res://content/weapons/tesla/dome04_cap_level3.png"), 
	preload("res://content/weapons/tesla/dome04_cap_level4.png"), 
]
var schnabelGlow: = [
	preload("res://content/weapons/tesla/dome04_cap_level1_glow.png"), 
	preload("res://content/weapons/tesla/dome04_cap_level1_glow.png"), 
	preload("res://content/weapons/tesla/dome04_cap_level2_glow.png"), 
	preload("res://content/weapons/tesla/dome04_cap_level3_glow.png"), 
	preload("res://content/weapons/tesla/dome04_cap_level4_glow.png"), 
]
@onready var arcPositions: = [
	[], 
	[], 
	[$Path2DL / PathFollow2DL / MountL / CapLeftOpen / Positions / Marker2D, 
	$Path2DL / PathFollow2DL / MountL / CapLeftOpen / Positions / Position2D2, 
	$Path2DR / PathFollow2DR / MountR / CapRightOpen / Positions / Marker2D, 
	$Path2DR / PathFollow2DR / MountR / CapRightOpen / Positions / Position2D2], 
	[$Path2DL / PathFollow2DL / MountL / CapLeftOpen / Positions / Marker2D, 
	$Path2DL / PathFollow2DL / MountL / CapLeftOpen / Positions / Position2D2, 
	$Path2DR / PathFollow2DR / MountR / CapRightOpen / Positions / Marker2D, 
	$Path2DR / PathFollow2DR / MountR / CapRightOpen / Positions / Position2D2, 
	$Path2DL / PathFollow2DL / MountL / CapLeftOpen / Positions / Position2D3, 
	$Path2DR / PathFollow2DR / MountR / CapRightOpen / Positions / Position2D3], 
	[$Path2DL / PathFollow2DL / MountL / CapLeftOpen / Positions / Marker2D, 
	$Path2DL / PathFollow2DL / MountL / CapLeftOpen / Positions / Position2D2, 
	$Path2DR / PathFollow2DR / MountR / CapRightOpen / Positions / Marker2D, 
	$Path2DR / PathFollow2DR / MountR / CapRightOpen / Positions / Position2D2, 
	$Path2DL / PathFollow2DL / MountL / CapLeftOpen / Positions / Position2D3, 
	$Path2DR / PathFollow2DR / MountR / CapRightOpen / Positions / Position2D3, 
	$Path2DL / PathFollow2DL / MountL / CapLeftOpen / Positions / Position2D4, 
	$Path2DR / PathFollow2DR / MountR / CapRightOpen / Positions / Position2D4], 
]

@onready var capL = $"%CapLeft"
@onready var capR = $"%CapRight"
@onready var tween = $"%CapTween"
@onready var pfL = $"%PathFollow2DL"
@onready var pfR = $"%PathFollow2DR"
@onready var capLo = $"%CapLeftOpen"
@onready var capRo = $"%CapRightOpen"
@onready var mountL = $"%MountL"
@onready var mountR = $"%MountR"

var teamId: String

var schnabelSprite: = 0

func init(teamId: String) -> void :
	self.teamId = teamId
	Data.listen(self, teamId + ".tesla.schnabelsprite", true)


func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".tesla.schnabelsprite":
		schnabelSprite = int(newValue)
		$"%CapLeft".texture = schnabelTextures[schnabelSprite]
		$"%CapLeftOpen".texture = schnabelTextures[schnabelSprite]
		$"%CapRight".texture = schnabelTextures[schnabelSprite]
		$"%CapRightOpen".texture = schnabelTextures[schnabelSprite]
		$"%CapLeftGlow".texture = schnabelGlow[schnabelSprite]
		$"%CapRightGlow".texture = schnabelGlow[schnabelSprite]


func start():
	if Dome.weaponsStarted(teamId, 2):
		return

	var moveTime = remap(capL.rotation_degrees, 0, -69, 0.75, 0) * 0.5
	tween.remove_all()
	tween.interpolate_property(capL, "rotation_degrees", capL.rotation_degrees, -65, moveTime, Tween.TRANS_EXPO, Tween.EASE_OUT, moveTime * 2)
	tween.interpolate_property(capR, "rotation_degrees", capR.rotation_degrees, 65, moveTime, Tween.TRANS_EXPO, Tween.EASE_OUT, moveTime * 2)
	tween.interpolate_callback(self, moveTime * 2.25, "toOpenedSprite")
	tween.interpolate_property(pfL, "progress_ratio", pfL.progress_ratio, 1, moveTime, Tween.TRANS_EXPO, Tween.EASE_OUT, moveTime * 2.2)
	tween.interpolate_property(pfR, "progress_ratio", pfR.progress_ratio, 1, moveTime, Tween.TRANS_EXPO, Tween.EASE_OUT, moveTime * 2.2)
	tween.start()


func stop():
	if Dome.weaponsStarted(teamId, 1):
		return

	var moveTime = remap(capL.rotation_degrees, -69, 0, 0.75, 0) * 0.5
	tween.remove_all()
	tween.interpolate_property(capL, "rotation_degrees", capL.rotation_degrees, 0, moveTime, Tween.TRANS_EXPO, Tween.EASE_OUT, moveTime)
	tween.interpolate_property(capR, "rotation_degrees", capR.rotation_degrees, 0, moveTime, Tween.TRANS_EXPO, Tween.EASE_OUT, moveTime)
	tween.interpolate_callback(self, moveTime, "toClosedSprite")
	tween.interpolate_property(pfL, "progress_ratio", pfL.progress_ratio, 0, moveTime, Tween.TRANS_EXPO, Tween.EASE_OUT, moveTime * 0.5)
	tween.interpolate_property(pfR, "progress_ratio", pfR.progress_ratio, 0, moveTime, Tween.TRANS_EXPO, Tween.EASE_OUT, moveTime * 0.5)
	tween.start()

func toOpenedSprite():
	capRo.show()
	capLo.show()
	capL.hide()
	capR.hide()
	mountL.self_modulate.a = 0
	mountR.self_modulate.a = 0


func toClosedSprite():
	capRo.hide()
	capLo.hide()
	capL.show()
	capR.show()
	mountL.self_modulate.a = 1
	mountR.self_modulate.a = 1
