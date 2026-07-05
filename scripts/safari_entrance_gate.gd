extends Node2D

# Verrouille les sorties de safari_entrance tant que le joueur n'a pas terminé
# l'intro (parlé à worker_m après avoir choisi Compétiteur). Voir player.gd
# (point d'extension gate_check/on_gate_blocked) et npc_worker_f.gd.

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const OPPOSITE := {"south": "north", "north": "south", "east": "west", "west": "east"}

func gate_check(_warp: Dictionary) -> bool:
	return PlayerData.chosen_class.is_empty() or PlayerData.intro_complete

func on_gate_blocked(_warp: Dictionary, player: Node) -> void:
	player.is_busy = true
	player.facing = OPPOSITE.get(player.facing, player.facing)
	player._play("face")

	var worker_f := get_node_or_null("worker_f")
	var lines: Array[String] = worker_f.get_lines() if worker_f else ["Va d'abord voir mon collègue."]

	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	dialogue.say(lines)
	await dialogue.finished
	dialogue.queue_free()
	player.is_busy = false
