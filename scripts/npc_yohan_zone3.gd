extends "res://scripts/npc.gd"

# Yohan : maison de repos de la Zone 3 (safari_rest_house_north). Premier
# vrai combat dresseur du jeu (voir acte1-parc-safari.md, action 1 :
# "combat stratégique météo", et la conversation de conception associée,
# plan lexical-giggling-cocoa.md) : équipe prêtée au joueur (éphémère, pas
# persistée — le joueur n'a encore aucun Pokémon à lui à ce stade de
# l'histoire), combat guidé par les conseils de Yohan
# (scripts/yohan_zone3_battle.gd), donne quand même 5 Répulsifs pour de vrai
# à l'issue, gagné ou perdu (voir PlayerData.repel_count).

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const BattleTransitionScene := preload("res://scenes/ui/battle_transition.tscn")
const TrainerBattleScene := preload("res://scenes/ui/trainer_battle.tscn")

const AFTER: Array[String] = [
	"Entraîne-toi bien. La suite du parc t'attend.",
]

# Gardé pour compatibilité avec la base npc.gd — plus utilisé comme chemin
# principal, voir custom_talk() ci-dessous (point d'extension de player.gd).
func get_lines() -> Array[String]:
	return AFTER

func custom_talk(player: Node, _player_tile: Vector2i) -> void:
	if PlayerData.yohan_zone3_done:
		await _say(player, AFTER)
		return

	await _say(player, [
		"Ah, te voilà. Camille et Julien m'ont dit que tu venais.",
		"Moi c'est Yohan, je m'occupe plutôt du côté Compétiteur : combats, stratégie, tout ça.",
	])

	await _say(player, [
		"Je vais te prêter une équipe pour un vrai combat contre moi — histoire de te montrer un aperçu de ce que ça donne à haut niveau.",
		"Une règle avant de commencer : en combat officiel, pas d'objet. On ne compte que sur les Pokémon et la stratégie.",
	])

	await _say(player, ["Prêt ? On y va."])

	var transition := BattleTransitionScene.instantiate()
	player.get_tree().current_scene.add_child(transition)
	await transition.play_close()

	var battle := TrainerBattleScene.instantiate()
	battle.player_entries = TrainerData.PLAYER_LOAN_TEAM
	battle.enemy_entries = TrainerData.TRAINERS["YOHAN_ZONE3"]["party"]
	battle.enemy_trainer_name = String(TrainerData.TRAINERS["YOHAN_ZONE3"]["name"])
	var coach := YohanZone3Battle.new(battle)
	battle.pre_turn_hook = Callable(coach, "on_pre_turn")
	player.get_tree().current_scene.add_child(battle)
	await transition.play_open()
	transition.queue_free()

	var result: String = await battle.finished

	if result == "win":
		await _say(player, [
			"Bien joué, vraiment. Tu as le réflexe, il ne te reste qu'à l'affiner.",
		])
	else:
		await _say(player, [
			"Pas de souci, ce combat n'était pas facile. L'important c'est de comprendre pourquoi, pas de gagner du premier coup.",
		])

	PlayerData.repel_count += 5
	PlayerData.yohan_zone3_done = true

	# Même pattern que le don du vélo/Pokédex (pause réservée au son d'objet
	# obtenu, voir npc_julien_zone2.gd/npc_camille_zone1.gd).
	await _say_with_pause(player, [
		"Tiens, prends ça : 5 Répulsifs. Ça évite les rencontres sauvages le temps que tu veuilles, utile pour traverser une zone sans être dérangé.",
	], 0, 0.6)

	await _say(player, ["Continue d'explorer le parc, la suite t'attend."])

func _say(player: Node, lines: Array[String]) -> void:
	var dialogue := DialogueBoxScene.instantiate()
	player.get_tree().current_scene.add_child(dialogue)
	dialogue.say(lines)
	await dialogue.finished
	dialogue.queue_free()

func _say_with_pause(player: Node, lines: Array[String], pause_after: int, pause_for: float) -> void:
	var dialogue := DialogueBoxScene.instantiate()
	player.get_tree().current_scene.add_child(dialogue)
	dialogue.say(lines, pause_after, pause_for)
	await dialogue.finished
	dialogue.queue_free()
