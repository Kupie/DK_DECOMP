class_name OrchardRoot
extends Area2D

const STUN_LVL = 10000

signal caughtMonster(monster: Monster)

var teamId: String
var UID: int

var catch
var done: = false

var monstersInArea: = []

var random: RandomNumberGenerator

func _ready():
	Style.init(self)
	$Sprite2D.play("grow")

	add_to_group(teamId + "-orchard-root")
	random = RandomNumberGenerator.new()
	random.seed = UID

func serialize() -> Dictionary:
	var data = {}
	data["meta.priority"] = 100
	data["meta.kind"] = "generic"
	data["teamId"] = teamId
	data["uid"] = UID
	return data

func deserialize(data: Dictionary):
	teamId = data.get("teamId", "team1")
	UID = data.get("uid", 0)
	random.seed = UID

func _physics_process(delta):
	if catch:
		var d = global_position - catch.global_position
		if d.length() > 1.0:
			catch.position += d * delta * 5.0
	else:
		for mon in monstersInArea:
			if mon.stunLevel() > 0.0:
				caughtMonster.emit(mon)

func catchMonster(monster: Monster) -> void :
	var duration = Data.of(teamId + ".orchard.battlerootcatchduration")
	$RootingEnemySound.startSound()
	catch = monster
	catch.sustainStun(STUN_LVL, duration)
	catch.connect("died", monsterDied.bind(monster))
	$Sprite2D.play("catch")
	dissolve(duration)

func _on_OrchardRoot_area_entered(area):
	if catch or done:
		return

	var mon = area.get_parent()
	if mon.is_in_group("monster") and mon.size == CONST.MONSTER_MEDIUM:
		monstersInArea.append(mon)

func dissolve(delay: = 0.0):
	if delay > 0.0:
		$Tween.interpolate_callback(self, delay, "dissolve")
		$Tween.start()
		return

	$Sprite2D.play("shrink")
	done = true
	monstersInArea.clear()

	$RootsBreakSound.startSound()

	if catch:
		catch.clearStun()
		catch = null

func hasCatch() -> bool:
	return catch != null

func explode(delay: int = 0, damageMod: = 0.0):
	if catch:
		if delay > 0.0:
			$Tween.interpolate_callback(self, random.randf_range(float(delay * 0.12), float(delay * 0.18)), "explode")
			$Tween.start()
			return
		var e = load("res://content/gadgets/orchard/OrchardRootExplosion.tscn").instantiate()
		e.damage = Data.of(teamId + ".orchard.battlerootexplosion")
		e.damage += e.damage * damageMod * 0.5
		e.position = position
		get_parent().add_child(e)
		catch.hit("orchardbattlerootingexplosion", catch.currentHealth, 0)
	queue_free()

func _on_Sprite_animation_finished():
	if $Sprite2D.animation == "shrink":
		queue_free()

func _on_OrchardRoot_area_exited(area):
	if catch or done:
		return
	monstersInArea.erase(area.get_parent())

func monsterDied(mon):
	if catch == mon:
		dissolve()
	else:
		monstersInArea.erase(mon)

func pauseChanged():
	if GameWorld.paused:
		$Tween.stop_all()
	else:
		$Tween.resume_all()

func hit(damage: float, stun: float, immediateStun: = false):
	if damage > 0.0:
		dissolve()
