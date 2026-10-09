class_name CombatExpBatchOptimizer
extends RefCounted

## Optimizador periódico de cristales de experiencia en combate.
## Compacta gemas de EXP lejanas en Mega-Cristales para evitar sobrecargar
## el árbol de nodos de Godot con cientos de drops individuales.

var _batch_timer: float = 0.0
const BATCH_INTERVAL: float = 2.5

func tick(delta: float, tree: SceneTree, player: Player) -> void:
	_batch_timer -= delta
	if _batch_timer <= 0.0:
		_batch_timer = BATCH_INTERVAL
		if is_instance_valid(player) and tree:
			ExpBlob.batch_distant_blobs_if_needed(tree, player.global_position)
