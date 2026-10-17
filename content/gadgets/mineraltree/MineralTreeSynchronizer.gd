class_name MineralTreeSynchronizer
extends Synchronizer

func init() -> void :
	for i in range(3):
		var fruitPositions: Array = owner.fruits[i + 1]
		for j in range(fruitPositions.size()):
			fruitPositions[j].hit.connect(on_fruit_hit.bind(i + 1, j))

func on_fruit_hit(keeper: Keeper, level: int, idx: int) -> void :
	network_rpc(remote_fruit_hit.bind(level, idx, keeper.playerId), true)

@rpc("reliable", "any_peer")
func remote_fruit_hit(level: int, idx: int, playerId: String) -> void :
	var fruitGrowth: FruitGrowth = owner.fruits[level][idx]
	fruitGrowth.registerHit(playerId)
