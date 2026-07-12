extends "res://scripts/npc.gd"

# Anselme : détaille les 2 classes et envoie au Parc Safari (Louise, à
# l'accueil, fait volontairement court et renvoie ici). Cette première
# discussion débloque la porte nord du bâtiment (voir safari_entrance_gate.gd,
# gate_check()) et donne les 30 Safari Balls. PlayerData.starter_species n'est
# PAS encore rempli à ce moment-là — il ne le sera qu'au retour, via
# safari_entrance_gate.gd::_handle_return_from_safari().

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const YesNoChoiceScene := preload("res://scenes/ui/yes_no_choice.tscn")

const PRESENTATION: Array[String] = [
	"Ah, on m'a prévenu de ton arrivée. Compétiteur ou Chercheur, telle est la question.",
	"Avant tout, une chose à savoir : ici, rien n'est gratuit. Tu vas devoir gagner ta vie, peu importe la voie choisie.",
	"Les arènes, c'est le tronc commun à tout le monde : badge après badge, jusqu'à la Ligue. Une sorte de formation pratique, pour passer de débutant à confirmé.",
	"Le Compétiteur vit des tournois et des grands combats. Le Chercheur, lui, vit de ce qu'il découvre sur le terrain, pour le laboratoire du Professeur Chen.",
	"Pas la peine de choisir tout de suite : tu vas pouvoir tester les deux avant de te décider. Direction la première maison, en zone 1 : Camille, l'assistant du Professeur Chen, t'y attend.",
	"Les Pokémon ne se montreront pas tant que tu n'as pas de Safari Balls avec toi.",
	"Avant que j'oublie : appuie sur Échap à tout moment pour ouvrir le menu pause et sauvegarder, si jamais tu as besoin de souffler.",
]

# BEAT 3B (voir acte1-parc-safari.md) : Anselme doit réapparaître en personne
# dans le Parc Safari juste après les 2 tutos (Camille puis Yohan) pour
# remettre les 30 Safari Balls à ce moment-là seulement, et confirmer qu'à
# partir de là les Pokémon sauvages se montrent enfin. PAS ENCORE IMPLÉMENTÉ :
# ça suppose que les tutos Camille/Yohan existent et posent un flag de
# complétion, ce qui n'est pas le cas aujourd'hui (sprites posés, aucune
# interaction codée). En attendant, le comportement actuel reste inchangé :
# SafariState.enter() donne les 30 balls dès l'entrée dans une carte
# safari_zone_*, sans passer par une réplique dédiée. Dialogues prêts,
# prévus pour être branchés ici une fois les tutos codés :
const PARK_HANDOFF: Array[String] = [
	"Tu as vu les deux facettes, maintenant. Voilà 30 Safari Balls : à partir de maintenant, les Pokémon sauvages vont enfin se montrer dans les hautes herbes.",
	"Tu peux croiser n'importe quel Pokémon de base de Kanto au parc Safari. Les Pokémon de base sont ceux qui n'ont encore jamais évolué. Certains sont très communs, d'autres beaucoup plus rares, et encore plus durs à attraper.",
	"Dès que tu n'as plus de Safari Balls, tu seras ramené à l'entrée, alors ne les gaspille pas.",
	"Tu peux attraper autant de Pokémon que tu veux, pas de panique. Tu pourras ensuite choisir lequel tu voudras garder pour être ton tout premier partenaire.",
	"Bon, je te laisse. À tout à l'heure !",
]

const ASK_FINISHED: Array[String] = [
	"Alors, tu as fini d'explorer le parc ?",
]

const REPLY_YES: Array[String] = [
	"Parfait ! Alors, montre-moi ce que tu as attrapé. Choisis bien : ce sera ton tout premier partenaire.",
]

const REPLY_NO: Array[String] = [
	"Pas de souci, prends ton temps. Je t'attends ici.",
]

func get_lines() -> Array[String]:
	if not PlayerData.orientation_given:
		return ["Va d'abord voir Louise."]
	if not PlayerData.intro_complete:
		PlayerData.intro_complete = true
		return PRESENTATION.duplicate()
	if PlayerData.starter_species.is_empty():
		return ["Le Parc Safari t'attend, juste à côté."]
	return ["Prends bien soin de ton %s, %s !" % [PlayerData.starter_species, PlayerData.player_name]]

# Appelée par safari_entrance_gate.gd quand le joueur revient au bâtiment
# alors qu'il lui reste des Safari Balls (retour volontaire, pas forcé).
# Retourne true si le joueur a terminé sa session (choix du partenaire à
# suivre), false s'il veut continuer (le joueur repart alors automatiquement
# dans le parc, voir safari_entrance_gate.gd::_turn_and_return_to_park()).
func ask_session_finished() -> bool:
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	dialogue.say(ASK_FINISHED)
	await dialogue.page_typed
	dialogue.active = false

	var choice := YesNoChoiceScene.instantiate()
	get_tree().current_scene.add_child(choice)
	var result: bool = await choice.chosen
	choice.queue_free()
	dialogue.queue_free()

	if result:
		await _say(REPLY_YES)
	else:
		await _say(REPLY_NO)
	return result

func _say(lines: Array[String]) -> void:
	var dialogue := DialogueBoxScene.instantiate()
	get_tree().current_scene.add_child(dialogue)
	dialogue.say(lines)
	await dialogue.finished
	dialogue.queue_free()
