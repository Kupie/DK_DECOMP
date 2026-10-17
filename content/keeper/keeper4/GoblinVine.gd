extends Node2D

signal retracted

const ROPE_TEXTURES: Array[Texture2D] = [
	preload("res://content/keeper/keeper4/rope1.png"), 
	preload("res://content/keeper/keeper4/rope2.png"), 
	preload("res://content/keeper/keeper4/rope3.png"), 
	preload("res://content/keeper/keeper4/rope4.png"), 
	preload("res://content/keeper/keeper4/rope5.png"), 
]
const ROPE_WIDTH: float = 7.0

var target_height: float = 0.0
var current_height: float = 0.0
const GROWTH_SPEED: float = 120.0

var _sprite: Sprite2D = null
var _retracting: = false
var _gravity_dir: int = 1

@onready var collision: CollisionShape2D = $Area2D / CollisionShape2D
@onready var shape: RectangleShape2D = collision.shape

func _ready():
	if get_meta("inverse_gravity", false):
		_gravity_dir = -1

func grow_to(height: float):
	target_height = height
	_rebuild_sprite()
	$VineGrowSound.startSound()

func extend_to(new_height: float):
	if new_height > target_height:
		target_height = new_height
		_rebuild_sprite()
		$VineGrowSound.startSound()

func retract():
	_retracting = true
	target_height = 0.0

func _process(delta: float):
	if _retracting:
		if current_height > 0:
			current_height = maxf(current_height - GROWTH_SPEED * delta, 0.0)
			shape.size.y = current_height
			collision.position.y = current_height * 0.5 * _gravity_dir
			_update_region()
			if current_height <= 0:
				retracted.emit()
		return
	if current_height < target_height:
		current_height = minf(current_height + GROWTH_SPEED * delta, target_height)
		shape.size.y = current_height
		collision.position.y = current_height * 0.5 * _gravity_dir
		_update_region()

func _rebuild_sprite() -> void :
	if _sprite:
		_sprite.queue_free()
	var tile_count: int = int(target_height / GameWorld.TILE_SIZE)
	var tex_index: int = clampi(tile_count - 1, 0, ROPE_TEXTURES.size() - 1)
	_sprite = Sprite2D.new()
	_sprite.texture = ROPE_TEXTURES[tex_index]
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, ROPE_WIDTH, 0)
	_sprite.centered = false
	_sprite.offset = Vector2(-3.0, 2.0)
	if _gravity_dir == -1:
		_sprite.scale.y = -1
		_sprite.offset = Vector2(-3.0, -2.0)
	add_child(_sprite)
	_update_region()

func _update_region() -> void :
	if _sprite:
		_sprite.region_rect = Rect2(0, 0, ROPE_WIDTH, current_height)
