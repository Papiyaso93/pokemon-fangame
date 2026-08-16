class_name YohanZone3Battle
extends RefCounted

# Couche de "guidage" spécifique au combat de Yohan (zone 3) : injecte les
# conseils avant les 3 moments charnières et réagit selon que le joueur les
# ait suivis ou non. Ne connaît que `trainer_battle.gd` (via son
# `pre_turn_hook`), pas l'inverse — `battle_engine.gd` reste généraliste et
# ignore complètement l'existence de Yohan, voir la conversation de
# conception (plan lexical-giggling-cocoa.md).

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")

var battle: Node   # trainer_battle.gd, typé Node faute de class_name sur ce script
var _stage := 0     # 0 = avant le 1er conseil, 1/2/3 = conseils déjà donnés

func _init(p_battle: Node) -> void:
	battle = p_battle

# Bindé sur trainer_battle.pre_turn_hook — appelé avant chaque menu d'action.
func on_pre_turn(_turn_number: int) -> void:
	var enemy_species: String = battle.enemy_side.active().species_key

	if _stage == 0 and enemy_species == "primeape":
		_stage = 1
		await _say([
			"Là c'est du sérieux : Primeape n'a pas de faiblesse de type contre Têtarte, ça va se jouer sur les stats.",
			"Mais Têtarte connaît Danse Pluie : un coup dans le vide, mais qui boostera toutes ses attaques Eau pour la suite. Sacrifie ce premier tour, ça va payer.",
		])
		return

	if _stage == 1 and enemy_species == "parasect":
		_stage = 2
		var followed := _rain_dance_was_used()
		if followed:
			await _say(["La pluie a fait son effet, bien joué. Nouveau combat, nouvelle donne."])
		else:
			await _say(["Pas grave, ça se retente une prochaine fois."])
		await _say([
			"Parasect est Insecte et Plante, très faible au Feu — l'occasion est trop belle pour ne pas en profiter.",
			"Reptincel est meilleur en Attaque Spéciale qu'en Attaque tout court, donc Flammèche cumule le bonus de type, une bonne stat, et l'efficacité contre ce double type. Griffe reste une attaque physique banale, sans rien de tout ça.",
		])
		return

	if _stage == 2 and enemy_species == "wartortle":
		_stage = 3
		if _ember_was_used():
			await _say(["Flammèche, exactement ce qu'il fallait. Continue comme ça."])
		else:
			await _say(["Griffe a fait le travail aussi, mais Flammèche aurait tapé plus fort ici."])
		await _say([
			"Là, deux choix : continuer avec Reptincel, ou changer. Contre Carabaffe, l'Eau bat le Feu, donc Reptincel va morfler.",
			"Mais plutôt que de juste éviter le pire, autant chercher carrément l'inverse : Ivysaur est Plante, et la Plante écrase l'Eau. C'est ça, un bon switch : pas seulement 'pas faible', carrément 'fort contre'.",
		])
		return

func _rain_dance_was_used() -> bool:
	for pkm in battle.player_side.party:
		if pkm.species_key == "poliwhirl":
			for mv in pkm.moves:
				if String(mv["key"]) == "RAIN_DANCE":
					return int(mv["pp_current"]) < int(mv["pp_max"])
	return false

func _ember_was_used() -> bool:
	for pkm in battle.player_side.party:
		if pkm.species_key == "charmeleon":
			for mv in pkm.moves:
				if String(mv["key"]) == "EMBER":
					return int(mv["pp_current"]) < int(mv["pp_max"])
	return false

func _say(lines: Array[String]) -> void:
	var dialogue := DialogueBoxScene.instantiate()
	dialogue.style = "battle"
	battle.get_tree().root.add_child(dialogue)
	dialogue.say(lines)
	await dialogue.finished
	dialogue.queue_free()
