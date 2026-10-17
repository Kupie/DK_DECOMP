class_name BulletSmokeManager extends Node

var _bullet_smoke_scn: PackedScene = load("res://content/weapons/artillery/BulletSmoke.tscn")
var _bullet_smoke_material: ShaderMaterial = load("res://content/weapons/artillery/MortarSmokeMat.tres")
var _bullet_smokes_pool: Array[BulletSmoke] = []
var _highest_bullet_smoke_id: int = -1
var _free_bullet_smokes: PackedInt32Array = PackedInt32Array()


func get_pooled_smoke() -> BulletSmoke:
	if not _free_bullet_smokes.is_empty():
		var free_id: int = _free_bullet_smokes[_free_bullet_smokes.size() - 1]
		_free_bullet_smokes.resize(_free_bullet_smokes.size() - 1)
		var bullet_smoke: Node = _bullet_smokes_pool[free_id]
		bullet_smoke.material = _bullet_smoke_material
		bullet_smoke.points = [Vector2.ZERO, Vector2.ZERO]
		return _bullet_smokes_pool[free_id]

	var bullet_smoke: BulletSmoke = _bullet_smoke_scn.instantiate()
	_bullet_smokes_pool.append(bullet_smoke)
	_highest_bullet_smoke_id = _bullet_smokes_pool.size() - 1
	bullet_smoke.init(_highest_bullet_smoke_id)
	bullet_smoke.material = _bullet_smoke_material
	bullet_smoke.points = [Vector2.ZERO, Vector2.ZERO]
	return bullet_smoke

func return_smoke_to_pool(in_bullet_smoke: BulletSmoke) -> void :
	var id: int = in_bullet_smoke.getID()
	_free_bullet_smokes.append(id)
	var parent: Node = in_bullet_smoke.get_parent()
	parent.remove_child(in_bullet_smoke)
